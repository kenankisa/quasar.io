-- Game Trial: her sim kendi JWT / profilinde ilerler; süre kapıları yok.
-- (Admin elmasına yazılma istemci tarafında accessToken izolasyonu ile çözülür.)
-- Supabase SQL Editor'da bir kez çalıştırın.

-- ---------------------------------------------------------------------------
-- 1) Hardcore cooldown temizleme (trial client çağırır)
-- ---------------------------------------------------------------------------
create or replace function public.game_trial_clear_hardcore_cooldown()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if not coalesce(public._is_game_trial_auth_user(v_uid), false) then
    raise exception 'not_game_trial';
  end if;
  update public.profiles
  set
    hardcore_cooldown_until = null,
    updated_at = timezone('utc', now())
  where id = v_uid;
end;
$$;

revoke all on function public.game_trial_clear_hardcore_cooldown() from public, anon;
grant execute on function public.game_trial_clear_hardcore_cooldown() to authenticated;

-- ---------------------------------------------------------------------------
-- 2) analytics_begin_play_session — game_trial: cooldown / daily limit yok
-- ---------------------------------------------------------------------------
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

  -- Game trial: her oyuncu kendi oturumunu hemen açar (süre istemez).
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

-- ---------------------------------------------------------------------------
-- 3) apply_match_result — game_trial: min süre / reward cooldown / günlük cap yok
-- ---------------------------------------------------------------------------
do $$
declare
  v_def text;
  v_new text;
begin
  begin
    v_def := pg_get_functiondef(
      'public.apply_match_result(text,int,boolean,uuid)'::regprocedure
    );
  exception when undefined_function then
    raise notice 'apply_match_result missing — skip patch';
    return;
  end;

  v_new := v_def;

  -- Training min wall-clock: game trial → 0
  if position('game_trial_min_seconds_bypass' in v_new) = 0 then
    v_new := replace(
      v_new,
      $q$if v_room = 'simple' then
      v_min_seconds := 90;
    end if;$q$,
      $q$if v_room = 'simple' then
      v_min_seconds := 90;
    end if;
    -- game_trial_min_seconds_bypass
    begin
      if public._is_game_trial_auth_user(v_uid) then
        v_min_seconds := 0;
      end if;
    exception when undefined_function then
      null;
    end;$q$
    );
  end if;

  -- Reward cooldown skip for game trial
  if position('game_trial_reward_cooldown_bypass' in v_new) = 0 then
    v_new := replace(
      v_new,
      $q$if v_last_reward_at is not null
         and v_last_reward_at > timezone('utc', now()) - interval '60 seconds' then
        raise exception 'reward_cooldown';
      end if;$q$,
      $q$-- game_trial_reward_cooldown_bypass
      if v_last_reward_at is not null
         and v_last_reward_at > timezone('utc', now()) - interval '60 seconds'
         and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
        raise exception 'reward_cooldown';
      end if;$q$
    );
  end if;

  -- Training daily limit skip
  if position('game_trial_training_daily_bypass' in v_new) = 0 then
    v_new := replace(
      v_new,
      $q$if coalesce(v_simple_reward_count, 0) >= 8 then
          raise exception 'training_daily_limit';
        end if;$q$,
      $q$-- game_trial_training_daily_bypass
        if coalesce(v_simple_reward_count, 0) >= 8
           and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
          raise exception 'training_daily_limit';
        end if;$q$
    );
  end if;

  -- Diamond daily cap skip (legacy fixed 120 + economy v_day_cap)
  if position('game_trial_diamond_cap_bypass' in v_new) = 0 then
    if position(
      $q$if coalesce(v_day_diamonds, 0) + v_delta > v_day_cap then
        raise exception 'diamond_daily_cap';
      end if;$q$
      in v_new
    ) > 0 then
      v_new := replace(
        v_new,
        $q$if coalesce(v_day_diamonds, 0) + v_delta > v_day_cap then
        raise exception 'diamond_daily_cap';
      end if;$q$,
        $q$-- game_trial_diamond_cap_bypass
      if coalesce(v_day_diamonds, 0) + v_delta > v_day_cap
         and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
        raise exception 'diamond_daily_cap';
      end if;$q$
      );
    elsif position(
      $q$if coalesce(v_day_diamonds, 0) + v_delta > 120 then
        raise exception 'diamond_daily_cap';
      end if;$q$
      in v_new
    ) > 0 then
      v_new := replace(
        v_new,
        $q$if coalesce(v_day_diamonds, 0) + v_delta > 120 then
        raise exception 'diamond_daily_cap';
      end if;$q$,
        $q$-- game_trial_diamond_cap_bypass
      if coalesce(v_day_diamonds, 0) + v_delta > 120
         and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
        raise exception 'diamond_daily_cap';
      end if;$q$
      );
    end if;
  end if;

  -- Reward claims / day (economy v_reward_limit)
  if position('game_trial_reward_limit_bypass' in v_new) = 0 then
    if position(
      $q$if coalesce(v_reward_count, 0) >= v_reward_limit then
        raise exception 'reward_daily_limit';
      end if;$q$
      in v_new
    ) > 0 then
      v_new := replace(
        v_new,
        $q$if coalesce(v_reward_count, 0) >= v_reward_limit then
        raise exception 'reward_daily_limit';
      end if;$q$,
        $q$-- game_trial_reward_limit_bypass
      if coalesce(v_reward_count, 0) >= v_reward_limit
         and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
        raise exception 'reward_daily_limit';
      end if;$q$
      );
    end if;
  end if;

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'apply_match_result patched for game_trial progress';
  else
    raise notice 'apply_match_result unchanged (patterns not found or already patched)';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4) join_hardcore_universe — game_trial: cooldown yok (kupa kilidi kalır)
-- ---------------------------------------------------------------------------
do $$
declare
  v_def text;
  v_new text;
begin
  begin
    v_def := pg_get_functiondef(
      'public.join_hardcore_universe()'::regprocedure
    );
  exception when undefined_function then
    raise notice 'join_hardcore_universe missing — skip patch';
    return;
  end;

  v_new := v_def;
  if position('game_trial_hardcore_cd_bypass' in v_new) = 0 then
    v_new := replace(
      v_new,
      $q$if v_cd is not null and v_cd > timezone('utc', now()) then
      raise exception 'hardcore_cooldown'
        using detail = to_char(v_cd at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
    end if;$q$,
      $q$-- game_trial_hardcore_cd_bypass
    if v_cd is not null and v_cd > timezone('utc', now())
       and not coalesce(public._is_game_trial_auth_user(v_user_id), false) then
      raise exception 'hardcore_cooldown'
        using detail = to_char(v_cd at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
    end if;
    if coalesce(public._is_game_trial_auth_user(v_user_id), false) then
      update public.profiles
      set hardcore_cooldown_until = null
      where id = v_user_id
        and hardcore_cooldown_until is not null;
    end if;$q$
    );
  end if;

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'join_hardcore_universe patched for game_trial';
  else
    raise notice 'join_hardcore_universe unchanged';
  end if;
end;
$$;

comment on function public.game_trial_clear_hardcore_cooldown() is
  'Game trial only: clear HC cooldown so each sim can re-enter alone.';
