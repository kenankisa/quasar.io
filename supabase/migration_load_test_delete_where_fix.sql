-- =============================================================================
-- Düzeltme: "DELETE requires a WHERE clause"
-- SQL Editor'da çalıştırın, sonra yük testini yeniden başlatın.
-- =============================================================================

create or replace function public.admin_stop_load_test()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_room_ids uuid[];
  v_count int;
  v_rid uuid;
  v_auth_ids uuid[];
begin
  perform public._require_admin();

  select coalesce(array_agg(distinct room_instance_id), '{}'::uuid[])
  into v_room_ids
  from public.load_test_ghosts;

  select count(*)::int into v_count from public.load_test_ghosts;

  delete from public.load_test_ghosts where true;

  foreach v_rid in array v_room_ids
  loop
    perform public._sync_room_occupancy(v_rid);
  end loop;

  begin
    if to_regclass('public.load_test_players') is not null then
      select coalesce(array_agg(user_id), '{}'::uuid[])
      into v_auth_ids
      from public.load_test_players;

      if coalesce(cardinality(v_auth_ids), 0) > 0 then
        update public.game_room_members
        set left_at = timezone('utc', now())
        where user_id = any (v_auth_ids) and left_at is null;

        delete from public.player_active_sessions where user_id = any (v_auth_ids);
        delete from public.load_test_players where user_id = any (v_auth_ids);
        begin
          delete from auth.identities where user_id = any (v_auth_ids);
          delete from auth.users where id = any (v_auth_ids);
        exception when others then
          null;
        end;
        v_count := v_count + coalesce(cardinality(v_auth_ids), 0);
      end if;
    end if;
  exception when others then
    null;
  end;

  return json_build_object('stopped', coalesce(v_count, 0));
end;
$$;

revoke all on function public.admin_stop_load_test() from public, anon;
grant execute on function public.admin_stop_load_test() to authenticated;

create or replace function public.admin_start_load_test(
  p_count int,
  p_room_type text default 'normal'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int := greatest(1, least(coalesce(p_count, 0), 100));
  v_room_type text := lower(trim(coalesce(p_room_type, 'normal')));
  v_i int;
  v_ghost_id uuid;
  v_device_id text;
  v_room_id uuid;
  v_created int := 0;
  v_rooms int;
  v_next_instance int;
begin
  perform public._require_admin();

  if v_room_type not in ('normal', 'elite', 'unique') then
    return json_build_object('error', 'invalid_room_type', 'started', 0);
  end if;

  perform public.admin_stop_load_test();

  for v_i in 1..v_count
  loop
    perform pg_advisory_xact_lock(hashtext('join_game_room_' || v_room_type));

    v_ghost_id := gen_random_uuid();
    v_device_id := format('loadtest_%s', replace(v_ghost_id::text, '-', ''));
    v_room_id := null;

    select gri.id
    into v_room_id
    from public.game_room_instances gri
    where gri.room_type = v_room_type
      and gri.status = 'open'
      and gri.leader_radius < 250
      and public._room_occupancy(gri.id) < 10
    order by gri.instance_number asc
    limit 1
    for update;

    if v_room_id is null then
      select gri.id
      into v_room_id
      from public.game_room_instances gri
      where gri.room_type = v_room_type
        and gri.status = 'closed'
      order by gri.instance_number asc
      limit 1
      for update;

      if v_room_id is not null then
        delete from public.game_room_members where room_instance_id = v_room_id;
        delete from public.load_test_ghosts where room_instance_id = v_room_id;
        update public.game_room_instances
        set
          status = 'open',
          leader_radius = 25,
          peak_leader_radius = 25,
          leader_radius_synced_at = null,
          real_player_count = 0,
          updated_at = timezone('utc', now())
        where id = v_room_id;
      else
        select coalesce(max(instance_number), 0) + 1
        into v_next_instance
        from public.game_room_instances
        where room_type = v_room_type;

        insert into public.game_room_instances (
          room_type,
          instance_number,
          real_player_count,
          leader_radius,
          peak_leader_radius,
          status
        ) values (
          v_room_type,
          v_next_instance,
          0,
          25,
          25,
          'open'
        )
        returning id into v_room_id;
      end if;
    end if;

    insert into public.load_test_ghosts (
      id,
      device_id,
      room_type,
      room_instance_id
    ) values (
      v_ghost_id,
      v_device_id,
      v_room_type,
      v_room_id
    );

    perform public._sync_room_occupancy(v_room_id);
    v_created := v_created + 1;
  end loop;

  select count(distinct room_instance_id)::int
  into v_rooms
  from public.load_test_ghosts;

  return json_build_object(
    'started', v_created,
    'room_type', v_room_type,
    'rooms_used', coalesce(v_rooms, 0),
    'active_players', (select count(*)::int from public.load_test_ghosts),
    'mode', 'ghost'
  );
exception when others then
  begin
    delete from public.load_test_ghosts where true;
  exception when others then
    null;
  end;
  return json_build_object(
    'error', SQLERRM,
    'started', 0,
    'active_players', 0
  );
end;
$$;

revoke all on function public.admin_start_load_test(int, text) from public, anon;
grant execute on function public.admin_start_load_test(int, text) to authenticated;
