-- =============================================================================
-- Quasar.io — Global sıralama: varsayılan rütbe (rank_points), zenginlik ayrı
-- p_sort: 'rank' | 'wealth'  (varsayılan: rank)
-- get_user_rank da rütbe sırasına geçer.
-- SQL Editor'da çalıştırın (migration_leaderboard_games_won sonrası).
-- =============================================================================

-- Eski tek-argüman imzasını kaldır (PostgREST overload karışıklığı olmasın).
drop function if exists public.get_global_leaderboard(int);

create or replace function public.get_global_leaderboard(
  p_limit int default 100,
  p_sort text default 'rank'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 100);
  v_sort text := lower(coalesce(nullif(trim(p_sort), ''), 'rank'));
  v_top json;
  v_local json;
  v_local_rank int;
  v_in_top boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_sort not in ('rank', 'wealth') then
    v_sort := 'rank';
  end if;

  if v_sort = 'wealth' then
    select coalesce(json_agg(row_to_json(t) order by t.rank_pos), '[]'::json)
    into v_top
    from (
      select
        row_number() over (
          order by
            p.diamonds desc,
            coalesce(p.games_won, 0) desc,
            coalesce(p.rank_points, 0) desc,
            p.updated_at desc nulls last
        ) as rank_pos,
        p.id as user_id,
        coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
        p.diamonds,
        coalesce(p.games_won, 0) as games_won,
        coalesce(p.rank_points, 0) as rank_points
      from public.profiles p
      where not public._is_admin_user(p.id)
      order by
        p.diamonds desc,
        coalesce(p.games_won, 0) desc,
        coalesce(p.rank_points, 0) desc,
        p.updated_at desc nulls last
      limit v_limit
    ) t;
  else
    select coalesce(json_agg(row_to_json(t) order by t.rank_pos), '[]'::json)
    into v_top
    from (
      select
        row_number() over (
          order by
            coalesce(p.rank_points, 0) desc,
            coalesce(p.games_won, 0) desc,
            p.diamonds desc,
            p.updated_at desc nulls last
        ) as rank_pos,
        p.id as user_id,
        coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
        p.diamonds,
        coalesce(p.games_won, 0) as games_won,
        coalesce(p.rank_points, 0) as rank_points
      from public.profiles p
      where not public._is_admin_user(p.id)
      order by
        coalesce(p.rank_points, 0) desc,
        coalesce(p.games_won, 0) desc,
        p.diamonds desc,
        p.updated_at desc nulls last
      limit v_limit
    ) t;
  end if;

  select exists (
    select 1
    from json_array_elements(v_top) e
    where (e->>'user_id')::uuid = v_uid
  ) into v_in_top;

  if not v_in_top then
    if v_sort = 'wealth' then
      select position into v_local_rank
      from (
        select
          id,
          row_number() over (
            order by
              diamonds desc,
              coalesce(games_won, 0) desc,
              coalesce(rank_points, 0) desc,
              updated_at desc nulls last
          ) as position
        from public.profiles
        where not public._is_admin_user(id)
      ) ranked
      where id = v_uid;
    else
      select position into v_local_rank
      from (
        select
          id,
          row_number() over (
            order by
              coalesce(rank_points, 0) desc,
              coalesce(games_won, 0) desc,
              diamonds desc,
              updated_at desc nulls last
          ) as position
        from public.profiles
        where not public._is_admin_user(id)
      ) ranked
      where id = v_uid;
    end if;

    select json_build_object(
      'rank_pos', coalesce(v_local_rank, 0),
      'user_id', p.id,
      'username', coalesce(nullif(trim(p.username), ''), 'Traveler'),
      'diamonds', p.diamonds,
      'games_won', coalesce(p.games_won, 0),
      'rank_points', coalesce(p.rank_points, 0)
    )
    into v_local
    from public.profiles p
    where p.id = v_uid;
  end if;

  return json_build_object(
    'top', v_top,
    'local', v_local,
    'local_in_top', v_in_top,
    'sort', v_sort
  );
end;
$$;

revoke all on function public.get_global_leaderboard(int, text) from public, anon;
grant execute on function public.get_global_leaderboard(int, text) to authenticated;

-- Profildeki "global sıra" = rütbe sıralaması
create or replace function public.get_user_rank(user_uuid uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  user_position int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if user_uuid is distinct from v_uid
     and not public._is_admin_user(v_uid) then
    raise exception 'forbidden';
  end if;

  select position into user_position
  from (
    select
      id,
      row_number() over (
        order by
          coalesce(rank_points, 0) desc,
          coalesce(games_won, 0) desc,
          diamonds desc,
          updated_at desc nulls last
      ) as position
    from public.profiles
    where not public._is_admin_user(id)
  ) ranked
  where id = user_uuid;

  return coalesce(user_position, 0);
end;
$$;

revoke all on function public.get_user_rank(uuid) from public, anon;
grant execute on function public.get_user_rank(uuid) to authenticated;

notify pgrst, 'reload schema';
