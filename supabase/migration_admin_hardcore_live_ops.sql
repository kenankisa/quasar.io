-- Admin Hardcore live ops: arena seats, queue, diamond flow (won/lost).
-- Requires: _require_admin, hardcore_queue, hardcore_kill_claims,
--           match_reward_claims, game_room_members, _room_hardcore_seat_occupancy,
--           _hardcore_max_players, _ensure_hardcore_singleton.

create or replace function public.get_admin_hardcore_live_ops()
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
  v_players json := '[]'::json;
  v_queue json := '[]'::json;
  v_won_today int := 0;
  v_lost_today int := 0;
  v_won_hour int := 0;
  v_lost_hour int := 0;
  v_day_start timestamptz := date_trunc('day', timezone('utc', now()));
  v_hour_start timestamptz := timezone('utc', now()) - interval '1 hour';
begin
  perform public._require_admin();
  perform public._ensure_hardcore_singleton();

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

    select coalesce(json_agg(row_to_json(t) order by t.joined_at asc), '[]'::json)
    into v_players
    from (
      select
        grm.user_id::text as user_id,
        coalesce(nullif(trim(p.username), ''), '—') as username,
        grm.joined_at,
        coalesce(public._is_admin_user(grm.user_id), false) as is_admin
      from public.game_room_members grm
      join public.profiles p on p.id = grm.user_id
      where grm.room_instance_id = v_room.id
        and grm.left_at is null
      order by grm.joined_at asc
    ) t;
  end if;

  select count(*)::int
  into v_queue_count
  from public.hardcore_queue
  where admitted_room_id is null;

  select coalesce(json_agg(row_to_json(t) order by t.position asc), '[]'::json)
  into v_queue
  from (
    select
      row_number() over (order by q.enqueued_at asc)::int as position,
      q.user_id::text as user_id,
      coalesce(nullif(trim(p.username), ''), '—') as username,
      q.enqueued_at
    from public.hardcore_queue q
    join public.profiles p on p.id = q.user_id
    where q.admitted_room_id is null
    order by q.enqueued_at asc
    limit 40
  ) t;

  -- Kill rewards (always positive) + placement rewards / elim penalties.
  select
    coalesce(sum(case when d.delta > 0 then d.delta else 0 end), 0)::int,
    coalesce(sum(case when d.delta < 0 then -d.delta else 0 end), 0)::int
  into v_won_today, v_lost_today
  from (
    select diamond_delta as delta, created_at
    from public.hardcore_kill_claims
    where created_at >= v_day_start
    union all
    select diamond_delta as delta, created_at
    from public.match_reward_claims
    where lower(room_type) = 'hardcore'
      and created_at >= v_day_start
  ) d;

  select
    coalesce(sum(case when d.delta > 0 then d.delta else 0 end), 0)::int,
    coalesce(sum(case when d.delta < 0 then -d.delta else 0 end), 0)::int
  into v_won_hour, v_lost_hour
  from (
    select diamond_delta as delta, created_at
    from public.hardcore_kill_claims
    where created_at >= v_hour_start
    union all
    select diamond_delta as delta, created_at
    from public.match_reward_claims
    where lower(room_type) = 'hardcore'
      and created_at >= v_hour_start
  ) d;

  return json_build_object(
    'room_id', v_room.id,
    'status', coalesce(v_room.status, 'missing'),
    'leader_radius', coalesce(v_room.leader_radius, 0),
    'real_player_count', coalesce(v_room.real_player_count, 0),
    'seat_occupancy', coalesce(v_seats, 0),
    'max_players', v_max,
    'players', coalesce(v_players, '[]'::json),
    'queue', coalesce(v_queue, '[]'::json),
    'queue_count', coalesce(v_queue_count, 0),
    'diamonds_won_today', coalesce(v_won_today, 0),
    'diamonds_lost_today', coalesce(v_lost_today, 0),
    'diamonds_won_hour', coalesce(v_won_hour, 0),
    'diamonds_lost_hour', coalesce(v_lost_hour, 0),
    'fetched_at', timezone('utc', now())
  );
end;
$$;

revoke all on function public.get_admin_hardcore_live_ops() from public, anon;
grant execute on function public.get_admin_hardcore_live_ops() to authenticated;

comment on function public.get_admin_hardcore_live_ops() is
  'Admin-only Hardcore live ops snapshot: seats, queue, diamond won/lost.';
