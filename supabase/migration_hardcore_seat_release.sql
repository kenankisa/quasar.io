-- =============================================================================
-- Quasar.io — Hardcore: force seat release on elim/win (live + Arena Test)
-- Fixes: ghost members keep seats → new players cannot join under the 20 cap;
--         absorbed / victorious players still listed "inside" the arena.
-- Run once after migration_hardcore_arena_test_parity.sql
-- =============================================================================

-- 1) Release one member's seat (self, peer in same room, or admin)
create or replace function public.hardcore_release_member(
  p_room_instance_id uuid,
  p_user_id uuid
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_released int := 0;
  v_occ int := 0;
begin
  if v_caller is null then
    raise exception 'not authenticated';
  end if;
  if p_room_instance_id is null or p_user_id is null then
    raise exception 'invalid_args';
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found then
    raise exception 'room_not_found';
  end if;
  if lower(coalesce(v_room.room_type, '')) <> 'hardcore' then
    raise exception 'not_hardcore_room';
  end if;

  -- Authorize: self, admin, or active member of this room (predator kick).
  if v_caller <> p_user_id
     and not coalesce(public._is_admin_user(v_caller), false)
     and not exists (
       select 1
       from public.game_room_members grm
       where grm.room_instance_id = p_room_instance_id
         and grm.user_id = v_caller
         and grm.left_at is null
     )
  then
    raise exception 'hardcore_release_forbidden';
  end if;

  update public.game_room_members
  set left_at = timezone('utc', now())
  where room_instance_id = p_room_instance_id
    and user_id = p_user_id
    and left_at is null;

  get diagnostics v_released = row_count;

  -- Drop from both queues if waiting / stale admit rows
  delete from public.hardcore_queue where user_id = p_user_id;
  begin
    delete from public.hardcore_test_queue where user_id = p_user_id;
  exception when undefined_table then
    null;
  end;

  v_occ := public._sync_room_occupancy(p_room_instance_id);

  if coalesce(v_occ, 0) <= 0 then
    update public.game_room_instances
    set
      status = 'closed',
      real_player_count = 0,
      leader_radius = 25,
      peak_leader_radius = 25,
      leader_radius_synced_at = null,
      updated_at = timezone('utc', now())
    where id = p_room_instance_id
      and status = 'open';
  else
    begin
      perform public._promote_hardcore_queue(p_room_instance_id);
    exception when others then
      null;
    end;
    begin
      perform public._promote_hardcore_test_queue(p_room_instance_id);
    exception when others then
      null;
    end;
  end if;

  return json_build_object(
    'released', v_released > 0,
    'released_count', v_released,
    'seat_occupancy', coalesce(v_occ, 0)
  );
end;
$$;

revoke all on function public.hardcore_release_member(uuid, uuid)
  from public, anon;
grant execute on function public.hardcore_release_member(uuid, uuid)
  to authenticated;

comment on function public.hardcore_release_member(uuid, uuid) is
  'Hardcore: mark member left_at (self/peer/admin). Frees seat + promotes queue.';

-- 2) Arena Test: kick ghost sim seats not in the harness keep-list
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
  'Admin Arena Test: leave any non-admin member not in keep list (ghost seat cleanup).';
