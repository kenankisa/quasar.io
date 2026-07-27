-- =============================================================================
-- Quasar.io — Fix Arena Test "Durdur ve sıfırla"
-- Symptom: PostgresException DELETE requires a WHERE clause (code 21000)
-- Cause: admin_hardcore_arena_test_reset used bare DELETE on hardcore_test_queue
-- Run once in Supabase SQL Editor. Safe to re-run.
-- =============================================================================

create or replace function public.admin_hardcore_arena_test_reset()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_removed int := 0;
begin
  perform public._require_admin();
  v_room := public._ensure_hardcore_load_test_singleton();

  update public.game_room_members
  set left_at = timezone('utc', now())
  where room_instance_id = v_room.id
    and left_at is null;
  get diagnostics v_removed = row_count;

  -- WHERE required (safe-updates / PostgREST-style guards → 21000)
  delete from public.hardcore_test_queue where true;
  delete from public.hardcore_arena_test_commands
  where room_instance_id = v_room.id;

  update public.game_room_instances
  set
    leader_radius = 25,
    real_player_count = 0,
    status = 'open',
    match_generation = coalesce(match_generation, 1) + 1
  where id = v_room.id;

  return json_build_object(
    'ok', true,
    'room_id', v_room.id,
    'members_cleared', v_removed
  );
end;
$$;

revoke all on function public.admin_hardcore_arena_test_reset() from public, anon;
grant execute on function public.admin_hardcore_arena_test_reset() to authenticated;
