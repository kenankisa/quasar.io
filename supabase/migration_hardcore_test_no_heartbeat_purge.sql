-- =============================================================================
-- Quasar.io — Arena Test: stop heartbeat purge from emptying seats mid-fill
-- Symptom: seat occupancy never reaches ~20; joins/promote call
--   _hardcore_purge_inactive_members and drop sims before heartbeats stabilize.
-- Arena Test membership is owned by admin reconcile / hardcore_release_member.
-- Safe to re-run.
-- =============================================================================

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

  -- Arena Test: do not heartbeat-purge. Harness reconcile / release owns seats
  -- so fill-to-cap + queue tests are not fighting the 45s idle reaper.
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
  end if;

  perform public._sync_room_occupancy(p_room_id);

  return coalesce(v_purged, 0);
end;
$$;

revoke all on function public._hardcore_purge_inactive_members(uuid)
  from public, anon, authenticated;

comment on function public._hardcore_purge_inactive_members(uuid) is
  'Live Hardcore: drop members without recent heartbeat. Arena Test: no-op (harness owns seats).';
