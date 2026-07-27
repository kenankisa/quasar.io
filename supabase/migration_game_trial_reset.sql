-- =============================================================================
-- Quasar.io — Oyun Deneme: tüm deneme oyuncularını ve her şeylerini sıfırla
-- - Odadan / HC kuyruğundan çıkar
-- - Oturumları sil
-- - Profil (elmas, kupa, HC puan, cooldown, tutorial) sıfırla
-- - is_game_trial sim hesaplarını sil
-- SQL Editor'da çalıştırın. Safe to re-run.
-- =============================================================================

create or replace function public.admin_reset_game_trial()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ids uuid[];
  v_n int := 0;
  v_left int := 0;
  v_queued int := 0;
  v_rooms uuid[];
  v_room_id uuid;
begin
  perform public._require_admin();

  select coalesce(array_agg(u.id), '{}'::uuid[])
  into v_ids
  from auth.users u
  where coalesce(u.raw_user_meta_data->>'is_game_trial', '') = 'true';

  v_n := coalesce(cardinality(v_ids), 0);
  if v_n = 0 then
    return json_build_object(
      'ok', true,
      'deleted', 0,
      'members_cleared', 0,
      'queue_cleared', 0
    );
  end if;

  -- Rooms that need occupancy sync after kick
  select coalesce(array_agg(distinct grm.room_instance_id), '{}'::uuid[])
  into v_rooms
  from public.game_room_members grm
  where grm.user_id = any (v_ids)
    and grm.left_at is null;

  update public.game_room_members
  set left_at = timezone('utc', now())
  where user_id = any (v_ids)
    and left_at is null;
  get diagnostics v_left = row_count;

  delete from public.hardcore_queue
  where user_id = any (v_ids);
  get diagnostics v_queued = row_count;

  delete from public.player_active_sessions
  where user_id = any (v_ids);

  begin
    perform public._allow_trusted_profile_write();
  exception when undefined_function then
    null;
  end;

  -- Wipe economy / career before auth delete (orphans cleaned with users)
  update public.profiles
  set
    diamonds = 20,
    games_won = 0,
    trophy_wins_simple = 0,
    trophy_wins_normal = 0,
    trophy_wins_elite = 0,
    trophy_wins_unique = 0,
    hardcore_points = 0,
    hardcore_cooldown_until = null,
    tutorial_completed = false,
    updated_at = timezone('utc', now())
  where id = any (v_ids);

  foreach v_room_id in array v_rooms
  loop
    begin
      perform public._sync_room_occupancy(v_room_id);
    exception when undefined_function then
      null;
    end;
    begin
      perform public._promote_hardcore_queue(v_room_id);
    exception when undefined_function then
      null;
    end;
  end loop;

  begin
    delete from auth.identities where user_id = any (v_ids);
    delete from auth.users where id = any (v_ids);
  exception when others then
    return json_build_object(
      'ok', false,
      'deleted', 0,
      'candidates', v_n,
      'members_cleared', v_left,
      'queue_cleared', v_queued,
      'error', SQLERRM
    );
  end;

  return json_build_object(
    'ok', true,
    'deleted', v_n,
    'members_cleared', v_left,
    'queue_cleared', v_queued
  );
end;
$$;

revoke all on function public.admin_reset_game_trial() from public, anon;
grant execute on function public.admin_reset_game_trial() to authenticated;

comment on function public.admin_reset_game_trial() is
  'Admin: stop game-trial sims server-side — leave rooms, clear HC queue, wipe profiles, delete auth users.';

-- Rankings: include trophies + show career progress (not only HC > 0)
create or replace function public.get_admin_game_trial_rankings(
  p_user_ids uuid[] default null
)
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_rows json;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if not public._is_admin_user(v_uid) then
    raise exception 'forbidden';
  end if;

  select coalesce(
    json_agg(row_to_json(t) order by t.hardcore_points desc, t.trophies desc, t.diamonds desc, t.username),
    '[]'::json
  )
  into v_rows
  from (
    select
      p.id as user_id,
      p.username,
      coalesce(p.hardcore_points, 0) as hardcore_points,
      coalesce(p.games_won, 0) as games_won,
      coalesce(p.diamonds, 0) as diamonds,
      (
        coalesce(p.trophy_wins_simple, 0)
        + coalesce(p.trophy_wins_normal, 0)
        + coalesce(p.trophy_wins_elite, 0)
        + coalesce(p.trophy_wins_unique, 0)
      ) as trophies,
      (
        select count(*) > 0
        from public.game_room_members grm
        join public.game_room_instances gri on gri.id = grm.room_instance_id
        where grm.user_id = p.id
          and gri.room_type = 'hardcore'
          and coalesce(gri.is_load_test, false) = false
          and grm.left_at is null
      ) as in_hardcore,
      exists (
        select 1 from public.hardcore_queue hq where hq.user_id = p.id
      ) as queued
    from public.profiles p
    where (
      p_user_ids is not null and p.id = any(p_user_ids)
    ) or (
      p_user_ids is null
      and exists (
        select 1 from auth.users u
        where u.id = p.id
          and coalesce(u.raw_user_meta_data->>'is_game_trial', '') = 'true'
      )
    )
    order by
      coalesce(p.hardcore_points, 0) desc,
      (
        coalesce(p.trophy_wins_simple, 0)
        + coalesce(p.trophy_wins_normal, 0)
        + coalesce(p.trophy_wins_elite, 0)
        + coalesce(p.trophy_wins_unique, 0)
      ) desc,
      coalesce(p.diamonds, 0) desc,
      p.username
    limit 100
  ) t;

  return json_build_object(
    'rankings', coalesce(v_rows, '[]'::json),
    'fetched_at', timezone('utc', now())
  );
end;
$$;

revoke all on function public.get_admin_game_trial_rankings(uuid[]) from public, anon;
grant execute on function public.get_admin_game_trial_rankings(uuid[]) to authenticated;
