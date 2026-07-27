-- =============================================================================
-- Quasar.io — Sim / game-trial: allow device_id takeover on player sessions
-- Web BroadcastChannel can briefly claim a sim row under the admin device id.
-- Safe to re-run.
-- =============================================================================

create or replace function public.claim_player_session(
  p_device_id text,
  p_room_type text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_device_id text := nullif(trim(p_device_id), '');
  v_room_type text := nullif(lower(trim(p_room_type)), '');
  v_session public.player_active_sessions%rowtype;
  v_is_sim boolean := false;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_device_id is null then
    raise exception 'invalid device_id';
  end if;

  perform public._purge_stale_player_sessions();

  begin
    v_is_sim := coalesce(public._is_sim_auth_user(v_user_id), false)
      or coalesce(public._is_game_trial_auth_user(v_user_id), false);
  exception when undefined_function then
    begin
      v_is_sim := coalesce(public._is_sim_auth_user(v_user_id), false);
    exception when undefined_function then
      v_is_sim := false;
    end;
  end;

  select *
  into v_session
  from public.player_active_sessions
  where user_id = v_user_id
  for update;

  if found then
    if v_session.device_id <> v_device_id then
      if v_is_sim then
        update public.player_active_sessions
        set
          device_id = v_device_id,
          room_type = coalesce(v_room_type, room_type),
          last_heartbeat_at = timezone('utc', now())
        where user_id = v_user_id;
        return;
      end if;
      raise exception 'player_already_active';
    end if;

    update public.player_active_sessions
    set
      room_type = coalesce(v_room_type, room_type),
      last_heartbeat_at = timezone('utc', now())
    where user_id = v_user_id;
    return;
  end if;

  insert into public.player_active_sessions (
    user_id,
    device_id,
    room_type,
    started_at,
    last_heartbeat_at
  )
  values (
    v_user_id,
    v_device_id,
    v_room_type,
    timezone('utc', now()),
    timezone('utc', now())
  );

  begin
    if not public._is_admin_user(v_user_id) then
      insert into public.analytics_login_events (user_id)
      values (v_user_id);
    end if;
  exception when undefined_function then
    null;
  when undefined_table then
    null;
  end;
end;
$$;

revoke all on function public.claim_player_session(text, text) from public, anon;
grant execute on function public.claim_player_session(text, text) to authenticated;

-- Explicit force reclaim for sims (client fallback when claim still races).
create or replace function public.sim_reclaim_player_session(
  p_device_id text,
  p_room_type text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_device_id text := nullif(trim(p_device_id), '');
  v_room_type text := nullif(lower(trim(p_room_type)), '');
  v_ok boolean := false;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;
  if v_device_id is null then
    raise exception 'invalid device_id';
  end if;

  begin
    v_ok := coalesce(public._is_sim_auth_user(v_user_id), false)
      or coalesce(public._is_game_trial_auth_user(v_user_id), false);
  exception when undefined_function then
    v_ok := false;
  end;

  if not v_ok then
    raise exception 'forbidden';
  end if;

  delete from public.player_active_sessions where user_id = v_user_id;

  insert into public.player_active_sessions (
    user_id,
    device_id,
    room_type,
    started_at,
    last_heartbeat_at
  )
  values (
    v_user_id,
    v_device_id,
    v_room_type,
    timezone('utc', now()),
    timezone('utc', now())
  );
end;
$$;

revoke all on function public.sim_reclaim_player_session(text, text)
  from public, anon;
grant execute on function public.sim_reclaim_player_session(text, text)
  to authenticated;

comment on function public.sim_reclaim_player_session(text, text) is
  'Sim/game-trial only: wipe and recreate player_active_sessions for this user.';
