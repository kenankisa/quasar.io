-- =============================================================================
-- Quasar.io — Win-point ranks (weighted 1st place) + admin config
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- Eğitim (simple) varsayılan 0 puan; Normal 1 / Elite 2 / Unique 3.
-- Eşikler: Stellar 8 · Nova 25 · Quasar 75 · Singularity 200
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) profiles.rank_points
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists rank_points int not null default 0;

alter table public.profiles
  add column if not exists tutorial_completed boolean not null default false;

-- Geçmiş galibiyetleri Normal ağırlığıyla yaklaşık taşı (oda tipi bilinmiyor).
update public.profiles
set rank_points = greatest(coalesce(games_won, 0), 0)
where coalesce(rank_points, 0) = 0
  and coalesce(games_won, 0) > 0;

-- -----------------------------------------------------------------------------
-- 2) app_rank_config (tek satır JSON — idle config kalıbı)
-- -----------------------------------------------------------------------------

create table if not exists public.app_rank_config (
  id int primary key default 1 check (id = 1),
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.app_rank_config (id, config) values
  (1, jsonb_build_object(
    'v', 1,
    'winPointsSimple', 0,
    'winPointsNormal', 1,
    'winPointsElite', 2,
    'winPointsUnique', 3,
    'minPointsStellar', 8,
    'minPointsNova', 25,
    'minPointsQuasar', 75,
    'minPointsSingularity', 200
  ))
on conflict (id) do nothing;

alter table public.app_rank_config enable row level security;

drop policy if exists "app_rank_config_select_authenticated" on public.app_rank_config;
create policy "app_rank_config_select_authenticated"
  on public.app_rank_config
  for select
  to authenticated
  using (true);

drop policy if exists "app_rank_config_upsert_admin" on public.app_rank_config;
create policy "app_rank_config_upsert_admin"
  on public.app_rank_config
  for all
  to authenticated
  using (public._is_admin_user(auth.uid()))
  with check (public._is_admin_user(auth.uid()));

-- -----------------------------------------------------------------------------
-- 3) Oda tipine göre 1.’lik puanı (admin JSON → sunucu)
-- -----------------------------------------------------------------------------

create or replace function public._rank_win_points_for_room(p_room text)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
  v_cfg jsonb;
  v_key text;
  v_default int;
  v_val int;
begin
  v_key := case v_room
    when 'simple' then 'winPointsSimple'
    when 'elite' then 'winPointsElite'
    when 'unique' then 'winPointsUnique'
    else 'winPointsNormal'
  end;

  v_default := case v_room
    when 'simple' then 0
    when 'elite' then 2
    when 'unique' then 3
    else 1
  end;

  select config into v_cfg
  from public.app_rank_config
  where id = 1;

  if v_cfg is null or not (v_cfg ? v_key) then
    return v_default;
  end if;

  begin
    v_val := (v_cfg ->> v_key)::int;
  exception
    when others then
      return v_default;
  end;

  if v_val is null or v_val < 0 then
    return v_default;
  end if;

  return least(v_val, 50);
end;
$$;

revoke all on function public._rank_win_points_for_room(text)
  from public, anon, authenticated;
-- İstemci EXECUTE yok; yalnızca sunucu içi (apply_match_result vb.) çağırır.

-- -----------------------------------------------------------------------------
-- 4) Ekonomi koruması — rank_points istemci yazamaz
-- -----------------------------------------------------------------------------

create or replace function public._guard_profile_economy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_setting('quasar.trusted_profile_write', true) = '1' then
    return NEW;
  end if;

  if NEW.diamonds is distinct from OLD.diamonds
     or NEW.games_won is distinct from OLD.games_won
     or NEW.rank_points is distinct from OLD.rank_points
     or NEW.active_skin is distinct from OLD.active_skin then
    raise exception 'forbidden_profile_field';
  end if;

  return NEW;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5) apply_match_result — 1.’likte rank_points ekle
-- -----------------------------------------------------------------------------

create or replace function public.apply_match_result(
  p_room_type text default 'normal',
  p_placement int default null,
  p_eliminated boolean default false,
  p_room_instance_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_delta int := 0;
  v_won int := 0;
  v_rank_delta int := 0;
  v_new_diamonds int;
  v_kind text;
  v_member record;
  v_room_row public.game_room_instances%rowtype;
  v_session public.analytics_play_sessions%rowtype;
  v_reward_count int;
  v_simple_reward_count int;
  v_last_reward_at timestamptz;
  v_day_diamonds int;
  v_min_seconds int := 60;
  v_peak int;
  v_match_gen int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('simple', 'normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  if coalesce(p_eliminated, false) then
    v_kind := 'penalty';
    v_delta := case v_room
      when 'simple' then 0
      when 'elite' then -2
      when 'unique' then -3
      else -1
    end;
  else
    v_kind := 'reward';
    if p_placement is null or p_placement < 1 or p_placement > 3 then
      select diamonds into v_new_diamonds
      from public.profiles
      where id = v_uid;
      return coalesce(v_new_diamonds, 0);
    end if;

    case v_room
      when 'simple' then
        if p_placement = 1 then
          v_delta := 3;
          -- Eğitim 1.’liği galibiyet sayısına eklenmez (sadece elmas + tutorial_completed).
          v_won := 0;
        elsif p_placement = 2 then
          v_delta := 2;
        elsif p_placement = 3 then
          v_delta := 1;
        end if;
      when 'elite' then
        if p_placement = 1 then
          v_delta := 10;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 6;
        elsif p_placement = 3 then
          v_delta := 4;
        end if;
      when 'unique' then
        if p_placement = 1 then
          v_delta := 15;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 10;
        elsif p_placement = 3 then
          v_delta := 5;
        end if;
      else
        if p_placement = 1 then
          v_delta := 5;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 3;
        elsif p_placement = 3 then
          v_delta := 2;
        end if;
    end case;

    if v_won = 1 then
      v_rank_delta := public._rank_win_points_for_room(v_room);
    end if;
  end if;

  if v_delta = 0 and v_won = 0 and v_rank_delta = 0 then
    select diamonds into v_new_diamonds
    from public.profiles
    where id = v_uid;
    return coalesce(v_new_diamonds, 0);
  end if;

  if not public._is_admin_user(v_uid) then
    if v_room = 'simple' then
      v_min_seconds := 90;
    end if;

    select *
    into v_session
    from public.analytics_play_sessions s
    where s.user_id = v_uid
      and s.room_type = v_room
      and (
        s.ended_at is null
        or s.ended_at >= timezone('utc', now()) - interval '15 minutes'
      )
      and not exists (
        select 1
        from public.match_reward_claims c
        where c.play_session_id = s.id
      )
    order by s.started_at desc
    limit 1
    for update;

    if not found then
      select *
      into v_session
      from public.analytics_play_sessions
      where user_id = v_uid
        and room_type = v_room
        and (
          ended_at is null
          or ended_at >= timezone('utc', now()) - interval '15 minutes'
        )
      order by started_at desc
      limit 1
      for update;
    end if;

    if not found then
      raise exception 'no_play_session';
    end if;

    if v_session.started_at > timezone('utc', now()) - make_interval(secs => v_min_seconds) then
      raise exception 'match_too_short';
    end if;

    if v_room = 'simple' then
      if p_room_instance_id is not null then
        raise exception 'training_no_room_instance';
      end if;
      v_match_gen := null;
    else
      if p_room_instance_id is null then
        raise exception 'room_instance_required';
      end if;

      select * into v_room_row
      from public.game_room_instances
      where id = p_room_instance_id
      for update;

      if not found then
        raise exception 'room_not_found';
      end if;

      if lower(v_room_row.room_type) <> v_room then
        raise exception 'room_type_mismatch';
      end if;

      v_match_gen := coalesce(v_room_row.match_generation, 1);

      select *
      into v_member
      from public.game_room_members
      where room_instance_id = p_room_instance_id
        and user_id = v_uid
        and (
          left_at is null
          or left_at >= timezone('utc', now()) - interval '2 hours'
        )
      order by joined_at desc
      limit 1
      for update;

      if not found then
        raise exception 'not_room_member';
      end if;

      if v_member.joined_at > timezone('utc', now()) - make_interval(secs => v_min_seconds) then
        raise exception 'match_too_short';
      end if;

      v_peak := greatest(
        coalesce(v_room_row.peak_leader_radius, 25),
        coalesce(v_room_row.leader_radius, 25)
      );

      if v_kind = 'reward' and p_placement = 1 then
        if v_peak < 350 then
          raise exception 'victory_not_verified';
        end if;
      end if;

      if v_kind = 'reward' and p_placement in (2, 3) then
        if v_peak < 180 then
          raise exception 'placement_not_verified';
        end if;
      end if;
    end if;

    if v_kind = 'reward' then
      select count(*)::int, max(created_at)
      into v_reward_count, v_last_reward_at
      from public.match_reward_claims
      where user_id = v_uid
        and claim_kind = 'reward'
        and created_at >= timezone('utc', now()) - interval '24 hours';

      if coalesce(v_reward_count, 0) >= 25 then
        raise exception 'reward_daily_limit';
      end if;

      if v_room = 'simple' then
        select count(*)::int
        into v_simple_reward_count
        from public.match_reward_claims
        where user_id = v_uid
          and claim_kind = 'reward'
          and room_type = 'simple'
          and created_at >= timezone('utc', now()) - interval '24 hours';

        if coalesce(v_simple_reward_count, 0) >= 8 then
          raise exception 'training_daily_limit';
        end if;
      end if;

      if v_last_reward_at is not null
         and v_last_reward_at > timezone('utc', now()) - interval '60 seconds' then
        raise exception 'reward_cooldown';
      end if;

      select coalesce(sum(greatest(diamond_delta, 0)), 0)::int
      into v_day_diamonds
      from public.match_reward_claims
      where user_id = v_uid
        and claim_kind = 'reward'
        and created_at >= timezone('utc', now()) - interval '24 hours';

      if coalesce(v_day_diamonds, 0) + v_delta > 120 then
        raise exception 'diamond_daily_cap';
      end if;
    end if;

    begin
      insert into public.match_reward_claims (
        user_id,
        room_type,
        room_instance_id,
        play_session_id,
        claim_kind,
        placement,
        diamond_delta,
        match_generation
      )
      values (
        v_uid,
        v_room,
        case when v_room = 'simple' then null else p_room_instance_id end,
        v_session.id,
        v_kind,
        case when v_kind = 'penalty' then null else p_placement end,
        v_delta,
        v_match_gen
      );
    exception
      when unique_violation then
        raise exception 'already_claimed';
    end;
  end if;

  perform public._allow_trusted_profile_write();
  perform set_config('quasar.analytics_room_type', v_room, true);
  perform set_config(
    'quasar.analytics_placement',
    case
      when v_kind = 'penalty' then ''
      else coalesce(p_placement::text, '')
    end,
    true
  );
  perform set_config(
    'quasar.analytics_eliminated',
    case when v_kind = 'penalty' then 'true' else 'false' end,
    true
  );

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_delta),
    games_won = games_won + v_won,
    rank_points = greatest(0, coalesce(rank_points, 0) + v_rank_delta),
    tutorial_completed = coalesce(tutorial_completed, false)
      or (v_room = 'simple' and v_kind = 'reward' and coalesce(p_placement, 0) = 1),
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;
$$;

revoke all on function public.apply_match_result(text, int, boolean, uuid) from public;
grant execute on function public.apply_match_result(text, int, boolean, uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 6) Global leaderboard — rank_points alanını da döndür (sıra hâlâ elmas)
-- -----------------------------------------------------------------------------

create or replace function public.get_global_leaderboard(p_limit int default 100)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 100);
  v_top json;
  v_local json;
  v_local_rank int;
  v_in_top boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select coalesce(json_agg(row_to_json(t) order by t.rank_pos), '[]'::json)
  into v_top
  from (
    select
      row_number() over (
        order by p.diamonds desc, p.games_won desc, p.updated_at desc nulls last
      ) as rank_pos,
      p.id as user_id,
      coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
      p.diamonds,
      coalesce(p.games_won, 0) as games_won,
      coalesce(p.rank_points, 0) as rank_points
    from public.profiles p
    where not public._is_admin_user(p.id)
    order by p.diamonds desc, p.games_won desc, p.updated_at desc nulls last
    limit v_limit
  ) t;

  select exists (
    select 1
    from json_array_elements(v_top) e
    where (e->>'user_id')::uuid = v_uid
  ) into v_in_top;

  if not v_in_top then
    select position into v_local_rank
    from (
      select
        id,
        row_number() over (
          order by diamonds desc, games_won desc, updated_at desc nulls last
        ) as position
      from public.profiles
      where not public._is_admin_user(id)
    ) ranked
    where id = v_uid;

    select json_build_object(
      'rank_pos', coalesce(v_local_rank, 0),
      'user_id', p.id,
      'username', coalesce(nullif(trim(p.username), ''), 'Traveler'),
      'diamonds', p.diamonds,
      'games_won', coalesce(p.games_won, 0),
      'rank_points', coalesce(p.rank_points, 0)
    )
    into v_local
    from public.profiles p
    where p.id = v_uid;
  end if;

  return json_build_object(
    'top', v_top,
    'local', v_local,
    'local_in_top', v_in_top
  );
end;
$$;

revoke all on function public.get_global_leaderboard(int) from public, anon;
grant execute on function public.get_global_leaderboard(int) to authenticated;

notify pgrst, 'reload schema';
