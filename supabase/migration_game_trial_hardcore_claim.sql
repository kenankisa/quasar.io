-- =============================================================================
-- Quasar.io — Oyun Deneme / live Hardcore: zafer claim tıkanması
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
--
-- Neden 10 oyuncu oturuyor, kimse kazanmıyor?
-- 1) analytics_begin_play_session hardcore kabul etmiyor → no_play_session
-- 2) Singleton Hardcore'da match_generation artmıyor + first_place unique
--    → ilk 1. sıra sonrası herkes already_claimed / claim döngüsü
-- =============================================================================

-- 1) Play session: hardcore allow (+ game_trial bypass — isolated_progress ile aynı gövde)
create or replace function public.analytics_begin_play_session(p_room_type text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room text := lower(trim(coalesce(p_room_type, '')));
  v_id uuid;
  v_recent int;
  v_day_count int;
  v_recent_resolved boolean := false;
  v_is_game_trial boolean := false;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('simple', 'normal', 'elite', 'unique', 'hardcore') then
    raise exception 'invalid room_type';
  end if;

  if public._is_admin_user(v_user_id) then
    return null;
  end if;

  begin
    v_is_game_trial := public._is_game_trial_auth_user(v_user_id);
  exception when undefined_function then
    v_is_game_trial := false;
  end;

  if v_is_game_trial then
    perform public._close_open_play_sessions(v_user_id, null);
    insert into public.analytics_play_sessions (user_id, room_type)
    values (v_user_id, v_room)
    returning id into v_id;
    return v_id;
  end if;

  select count(*)::int
  into v_recent
  from public.analytics_play_sessions
  where user_id = v_user_id
    and started_at > timezone('utc', now()) - interval '45 seconds';

  if coalesce(v_recent, 0) > 0 then
    select exists (
      select 1
      from public.analytics_play_sessions s
      where s.user_id = v_user_id
        and s.started_at > timezone('utc', now()) - interval '45 seconds'
        and (
          s.ended_at is not null
          or exists (
            select 1
            from public.match_reward_claims c
            where c.play_session_id = s.id
          )
        )
    )
    into v_recent_resolved;

    if not coalesce(v_recent_resolved, false) then
      select s.id
      into v_id
      from public.analytics_play_sessions s
      where s.user_id = v_user_id
        and s.ended_at is null
        and s.room_type = v_room
        and not exists (
          select 1
          from public.match_reward_claims c
          where c.play_session_id = s.id
        )
      order by s.started_at desc
      limit 1;

      if v_id is not null then
        return v_id;
      end if;

      raise exception 'play_session_cooldown';
    end if;
  end if;

  select count(*)::int
  into v_day_count
  from public.analytics_play_sessions
  where user_id = v_user_id
    and started_at >= timezone('utc', now()) - interval '24 hours';

  if coalesce(v_day_count, 0) >= 40 then
    raise exception 'play_session_daily_limit';
  end if;

  perform public._close_open_play_sessions(v_user_id, null);

  insert into public.analytics_play_sessions (user_id, room_type)
  values (v_user_id, v_room)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.analytics_begin_play_session(text) from public, anon;
grant execute on function public.analytics_begin_play_session(text) to authenticated;

-- 2) Hardcore: aynı generation'da birden fazla zafer (arena sürekli açık)
drop index if exists public.match_reward_claims_first_place_gen_uidx;

create unique index match_reward_claims_first_place_gen_uidx
  on public.match_reward_claims (room_instance_id, match_generation)
  where claim_kind = 'reward'
    and placement = 1
    and room_instance_id is not null
    and match_generation is not null
    and lower(coalesce(room_type, '')) <> 'hardcore';

comment on index public.match_reward_claims_first_place_gen_uidx is
  'One 1st-place per room generation except Hardcore (continuous arena).';

-- 3) Hardcore zaferinden sonra match_generation++ (aynı oyuncu tekrar kazanabilsin)
do $$
declare
  v_def text;
  v_new text;
  v_marker text := 'hardcore_match_gen_bump';
  v_old_footer text;
  v_new_footer text;
begin
  begin
    v_def := pg_get_functiondef(
      'public.apply_match_result(text,int,boolean,uuid)'::regprocedure
    );
  exception when undefined_function then
    raise notice 'apply_match_result missing — skip gen bump';
    return;
  end;

  if position(v_marker in v_def) > 0 then
    raise notice 'hardcore match_generation bump already present';
    return;
  end if;

  v_old_footer := $q$perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;$q$;

  v_new_footer := $q$-- hardcore_match_gen_bump
  if v_room = 'hardcore'
     and v_kind = 'reward'
     and coalesce(p_placement, 0) = 1
     and p_room_instance_id is not null then
    update public.game_room_instances
    set
      match_generation = coalesce(match_generation, 1) + 1,
      updated_at = timezone('utc', now())
    where id = p_room_instance_id;
  end if;

  perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;$q$;

  if position(v_old_footer in v_def) = 0 then
    raise notice 'apply_match_result return footer not matched — check manually';
    return;
  end if;

  v_new := replace(v_def, v_old_footer, v_new_footer);

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'apply_match_result patched: hardcore match_generation bump';
  else
    raise notice 'apply_match_result unchanged for gen bump';
  end if;
end;
$$;

notify pgrst, 'reload schema';

-- =============================================================================
-- 4) Oyun Deneme Hardcore zaferi — apply_match_result'a bağımlı DEĞİL
--    Peak / play_session / first_place / daily_cap yok → hardcore_points kesin +1
-- =============================================================================
create or replace function public.game_trial_claim_hardcore_victory(
  p_room_instance_id uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_points int;
  v_diamonds int;
  v_delta int := 0;
  v_alive int := 0;
  v_min_alive int := 6;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not coalesce(public._is_game_trial_auth_user(v_uid), false) then
    raise exception 'not_game_trial';
  end if;

  if p_room_instance_id is null then
    raise exception 'room_instance_required';
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found then
    raise exception 'room_not_found';
  end if;

  if lower(v_room.room_type) <> 'hardcore' then
    raise exception 'not_hardcore_room';
  end if;

  if coalesce(v_room.is_load_test, false) = true then
    raise exception 'load_test_room_forbidden';
  end if;

  if not exists (
    select 1
    from public.game_room_members grm
    where grm.room_instance_id = p_room_instance_id
      and grm.user_id = v_uid
      and grm.left_at is null
  ) then
    raise exception 'not_room_member';
  end if;

  -- Canlı Softcap/arena kuralı: en az 6 aktif üye olmadan fetih yok.
  begin
    v_min_alive := greatest(
      2,
      public._economy_cfg_int('hardcoreArenaMinAlive', 6)
    );
  exception when others then
    v_min_alive := 6;
  end;

  select count(*)::int
  into v_alive
  from public.game_room_members grm
  where grm.room_instance_id = p_room_instance_id
    and grm.left_at is null;

  if coalesce(v_alive, 0) < v_min_alive then
    raise exception 'hardcore_arena_inactive'
      using hint = format(
        'need %s alive, have %s',
        v_min_alive,
        coalesce(v_alive, 0)
      );
  end if;

  begin
    v_delta := greatest(0, public._economy_placement_delta('hardcore', 1));
  exception when others then
    v_delta := 50;
  end;

  begin
    perform public._allow_trusted_profile_write();
  exception when undefined_function then
    null;
  end;

  update public.profiles
  set
    hardcore_points = coalesce(hardcore_points, 0) + 1,
    games_won = coalesce(games_won, 0) + 1,
    diamonds = greatest(0, coalesce(diamonds, 0) + v_delta),
    hardcore_cooldown_until = null,
    updated_at = timezone('utc', now())
  where id = v_uid
  returning hardcore_points, diamonds into v_points, v_diamonds;

  -- Peak doğrulama için (canlı duyuru / HUD) — tavan yok sayılır
  update public.game_room_instances
  set
    leader_radius = greatest(coalesce(leader_radius, 0), 600),
    peak_leader_radius = greatest(coalesce(peak_leader_radius, 0), 600),
    match_generation = coalesce(match_generation, 1) + 1,
    leader_radius_synced_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_room_instance_id;

  return json_build_object(
    'ok', true,
    'hardcore_points', coalesce(v_points, 0),
    'diamonds', coalesce(v_diamonds, 0),
    'diamond_delta', v_delta
  );
end;
$$;

revoke all on function public.game_trial_claim_hardcore_victory(uuid)
  from public, anon;
grant execute on function public.game_trial_claim_hardcore_victory(uuid)
  to authenticated;

-- Eski isim → aynı yol (istemci / eski loglar)
create or replace function public.sim_claim_hardcore_victory(
  p_room_instance_id uuid default null
)
returns json
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_room_instance_id is null then
    raise exception 'room_instance_required';
  end if;
  return public.game_trial_claim_hardcore_victory(p_room_instance_id);
end;
$$;

revoke all on function public.sim_claim_hardcore_victory(uuid)
  from public, anon;
grant execute on function public.sim_claim_hardcore_victory(uuid)
  to authenticated;

comment on function public.game_trial_claim_hardcore_victory(uuid) is
  'Game trial only: award +1 hardcore_points without apply_match_result gates.';

-- =============================================================================
-- 5) Lider boyutu: deneme Hardcore'da tavan 600 (900 şişmesini düzelt + aşağı çek)
-- =============================================================================
create or replace function public.update_room_leader_radius(
  p_room_instance_id uuid,
  p_leader_radius int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_new int;
  v_elapsed_sec double precision;
  v_time_cap int;
  v_match_start timestamptz;
  v_hard_cap int := 550;
  v_is_game_trial boolean := false;
  v_step int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  begin
    v_is_game_trial := coalesce(public._is_game_trial_auth_user(v_uid), false);
  exception when undefined_function then
    v_is_game_trial := false;
  end;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found or v_room.status <> 'open' then
    return;
  end if;

  if lower(v_room.room_type) = 'hardcore' then
    v_hard_cap := case when v_is_game_trial then 600 else 900 end;
  end if;

  if p_leader_radius < 0 or p_leader_radius > v_hard_cap then
    raise exception 'invalid leader_radius';
  end if;

  if not exists (
    select 1
    from public.game_room_members grm
    where grm.room_instance_id = p_room_instance_id
      and grm.user_id = v_uid
      and grm.left_at is null
  ) then
    raise exception 'not an active room member';
  end if;

  if v_is_game_trial then
    v_new := least(
      v_hard_cap,
      greatest(
        p_leader_radius,
        least(coalesce(v_room.leader_radius, 0), v_hard_cap)
      )
    );
    if v_new = coalesce(v_room.leader_radius, 0) then
      update public.game_room_instances
      set leader_radius_synced_at = timezone('utc', now())
      where id = p_room_instance_id;
      return;
    end if;

    update public.game_room_instances
    set
      leader_radius = v_new,
      peak_leader_radius = greatest(coalesce(peak_leader_radius, 0), v_new),
      leader_radius_synced_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
    where id = p_room_instance_id
      and status = 'open';
    return;
  end if;

  if v_room.leader_radius_synced_at is not null
     and v_room.leader_radius_synced_at > timezone('utc', now()) - interval '4 seconds' then
    return;
  end if;

  v_match_start := coalesce(v_room.match_started_at, v_room.created_at);
  v_elapsed_sec := greatest(
    0,
    extract(epoch from (timezone('utc', now()) - v_match_start))
  );

  if lower(v_room.room_type) = 'hardcore' then
    v_time_cap := v_hard_cap;
    v_step := 200;
  else
    v_time_cap := least(
      v_hard_cap,
      25 + floor(v_elapsed_sec * 1.8)::int
    );
    v_step := 50;
  end if;

  v_new := least(
    v_time_cap,
    v_hard_cap,
    greatest(
      v_room.leader_radius,
      least(p_leader_radius, v_room.leader_radius + v_step)
    )
  );

  if v_new <= v_room.leader_radius then
    update public.game_room_instances
    set leader_radius_synced_at = timezone('utc', now())
    where id = p_room_instance_id;
    return;
  end if;

  update public.game_room_instances
  set
    leader_radius = v_new,
    peak_leader_radius = greatest(coalesce(peak_leader_radius, 0), v_new),
    leader_radius_synced_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
    and status = 'open';
end;
$$;

revoke all on function public.update_room_leader_radius(uuid, int)
  from public, anon;
grant execute on function public.update_room_leader_radius(uuid, int)
  to authenticated;

notify pgrst, 'reload schema';
