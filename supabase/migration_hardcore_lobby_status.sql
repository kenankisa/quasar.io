-- Public Hardcore lobby snapshot: seat fill + queue length (no usernames).
-- For authenticated clients on the lobby Hardcore card.

create or replace function public.get_hardcore_lobby_status()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room public.game_room_instances%rowtype;
  v_max int := 20;
  v_seats int := 0;
  v_queue_count int := 0;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  begin
    perform public._ensure_hardcore_singleton();
  exception
    when others then
      null;
  end;

  select *
  into v_room
  from public.game_room_instances
  where room_type = 'hardcore'
    and coalesce(is_load_test, false) = false
  order by instance_number asc
  limit 1;

  begin
    v_max := greatest(1, public._hardcore_max_players());
  exception
    when others then
      v_max := 20;
  end;

  if v_room.id is not null then
    begin
      v_seats := public._room_hardcore_seat_occupancy(v_room.id);
    exception
      when others then
        v_seats := coalesce(v_room.real_player_count, 0);
    end;
  end if;

  select count(*)::int
  into v_queue_count
  from public.hardcore_queue
  where admitted_room_id is null;

  return json_build_object(
    'seat_occupancy', greatest(0, coalesce(v_seats, 0)),
    'max_players', v_max,
    'queue_count', greatest(0, coalesce(v_queue_count, 0)),
    'fetched_at', timezone('utc', now())
  );
end;
$$;

revoke all on function public.get_hardcore_lobby_status() from public, anon;
grant execute on function public.get_hardcore_lobby_status() to authenticated;

comment on function public.get_hardcore_lobby_status() is
  'Lobby Hardcore card: seat occupancy, cap, and waiting queue count (no PII).';

notify pgrst, 'reload schema';
