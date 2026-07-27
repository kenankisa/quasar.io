-- =============================================================================
-- Quasar.io — Admin enters Hardcore Arena Test only when they choose
-- - Panel + sims: admin must NOT stay seated / queued (no auto lobby seat).
-- - "Test arenasına gir": keep admin via client keep-list; do not purge mid-match.
-- - Live Hardcore: admin still needs heartbeat (ghost seats free after ~45s).
-- Safe to re-run.
-- =============================================================================

-- 1) Purge: Live includes admin (heartbeat required).
--    Arena Test (is_load_test): never heartbeat-purge admin — client reconcile
--    / hardcore_release_member owns admin seat lifecycle.
create or replace function public._hardcore_purge_inactive_members(p_room_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stale timestamptz := timezone('utc', now()) - interval '45 seconds';
  v_purged int := 0;
  v_room public.game_room_instances%rowtype;
begin
  if p_room_id is null then
    return 0;
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_id
  for update;

  if not found then
    return 0;
  end if;
  if lower(coalesce(v_room.room_type, '')) <> 'hardcore' then
    return 0;
  end if;

  -- Arena Test: harness owns seats — skip heartbeat purge entirely.
  if coalesce(v_room.is_load_test, false) then
    perform public._sync_room_occupancy(p_room_id);
    return 0;
  end if;

  update public.game_room_members grm
  set left_at = timezone('utc', now())
  where grm.room_instance_id = p_room_id
    and grm.left_at is null
    and not exists (
      select 1
      from public.player_active_sessions pas
      where pas.user_id = grm.user_id
        and pas.last_heartbeat_at >= v_stale
    );

  get diagnostics v_purged = row_count;

  if v_purged > 0 then
    begin
      delete from public.hardcore_queue hq
      where hq.user_id in (
        select grm.user_id
        from public.game_room_members grm
        where grm.room_instance_id = p_room_id
          and grm.left_at is not null
          and grm.left_at >= timezone('utc', now()) - interval '2 minutes'
      );
    exception when others then
      null;
    end;
    begin
      delete from public.hardcore_test_queue hq
      where hq.user_id in (
        select grm.user_id
        from public.game_room_members grm
        where grm.room_instance_id = p_room_id
          and grm.left_at is not null
          and grm.left_at >= timezone('utc', now()) - interval '2 minutes'
      );
    exception when undefined_table then
      null;
    end;
  end if;

  -- Sync only — never promote from purge (avoids infinite recursion).
  perform public._sync_room_occupancy(p_room_id);

  return coalesce(v_purged, 0);
end;
$$;

revoke all on function public._hardcore_purge_inactive_members(uuid)
  from public, anon, authenticated;

-- 2) Arena Test reconcile: admin must be in keep-list (client sets while in GameScreen)
create or replace function public.admin_hardcore_test_reconcile_members(
  p_keep_user_ids uuid[] default '{}'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_keep uuid[] := coalesce(p_keep_user_ids, '{}');
  v_purged int := 0;
  v_occ int := 0;
begin
  perform public._require_admin();
  v_room := public._ensure_hardcore_load_test_singleton();

  update public.game_room_members grm
  set left_at = timezone('utc', now())
  where grm.room_instance_id = v_room.id
    and grm.left_at is null
    and not (grm.user_id = any (v_keep));

  get diagnostics v_purged = row_count;

  -- Also drop admin from the outside queue unless they are being kept in-arena.
  begin
    delete from public.hardcore_test_queue hq
    where hq.admitted_room_id is null
      and coalesce(public._is_admin_user(hq.user_id), false)
      and not (hq.user_id = any (v_keep));
  exception when undefined_table then
    null;
  end;

  v_occ := public._sync_room_occupancy(v_room.id);

  if coalesce(v_occ, 0) <= 0 then
    update public.game_room_instances
    set
      status = 'closed',
      real_player_count = 0,
      leader_radius = 25,
      peak_leader_radius = 25,
      leader_radius_synced_at = null,
      updated_at = timezone('utc', now())
    where id = v_room.id
      and status = 'open';
  else
    begin
      perform public._promote_hardcore_test_queue(v_room.id);
    exception when others then
      null;
    end;
  end if;

  return json_build_object(
    'purged', coalesce(v_purged, 0),
    'seat_occupancy', coalesce(v_occ, 0),
    'kept', coalesce(array_length(v_keep, 1), 0)
  );
end;
$$;

revoke all on function public.admin_hardcore_test_reconcile_members(uuid[])
  from public, anon;
grant execute on function public.admin_hardcore_test_reconcile_members(uuid[])
  to authenticated;

comment on function public.admin_hardcore_test_reconcile_members(uuid[]) is
  'Arena Test: leave any member not in keep list (incl. admin unless explicitly kept); drop admin from outside queue.';
comment on function public._hardcore_purge_inactive_members(uuid) is
  'Hardcore: drop members without recent heartbeat. Arena Test skips admin (client owns seat). Live includes admin. Does not promote.';
