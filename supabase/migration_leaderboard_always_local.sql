-- =============================================================================
-- Quasar.io — Dünya sıralamasında her zaman "SENİN SIRAN" (sticky local)
-- SQL Editor'da bir kez çalıştırın.
--
-- Önceki davranış: top 100 içindeysen local dönmezdi → alt satır yoktu.
-- Hardcore'da çoğu oyuncu top dışında olduğu için altta kendini görüyordu.
-- Artık Rütbe / Zenginlik / Hardcore için local her zaman hesaplanır.
-- =============================================================================

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

  if v_sort not in ('rank', 'wealth', 'hardcore') then
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
        coalesce(p.rank_points, 0) as rank_points,
        coalesce(p.hardcore_points, 0) as hardcore_points
      from public.profiles p
      where not public._is_admin_user(p.id)
      order by
        p.diamonds desc,
        coalesce(p.games_won, 0) desc,
        coalesce(p.rank_points, 0) desc,
        p.updated_at desc nulls last
      limit v_limit
    ) t;
  elsif v_sort = 'hardcore' then
    select coalesce(json_agg(row_to_json(t) order by t.rank_pos), '[]'::json)
    into v_top
    from (
      select
        row_number() over (
          order by
            coalesce(p.hardcore_points, 0) desc,
            coalesce(p.games_won, 0) desc,
            p.diamonds desc,
            p.updated_at desc nulls last
        ) as rank_pos,
        p.id as user_id,
        coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
        p.diamonds,
        coalesce(p.games_won, 0) as games_won,
        coalesce(p.rank_points, 0) as rank_points,
        coalesce(p.hardcore_points, 0) as hardcore_points
      from public.profiles p
      where not public._is_admin_user(p.id)
        and coalesce(p.hardcore_points, 0) > 0
      order by
        coalesce(p.hardcore_points, 0) desc,
        coalesce(p.games_won, 0) desc,
        p.diamonds desc,
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
        coalesce(p.rank_points, 0) as rank_points,
        coalesce(p.hardcore_points, 0) as hardcore_points
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

  -- Local sıra: top içinde olsan da her zaman hesapla (sticky "SENİN SIRAN").
  if v_sort = 'wealth' then
    select position into v_local_rank
    from (
      select id, row_number() over (
        order by diamonds desc, coalesce(games_won, 0) desc,
                 coalesce(rank_points, 0) desc, updated_at desc nulls last
      ) as position
      from public.profiles
      where not public._is_admin_user(id)
    ) ranked where id = v_uid;
  elsif v_sort = 'hardcore' then
    select position into v_local_rank
    from (
      select id, row_number() over (
        order by coalesce(hardcore_points, 0) desc, coalesce(games_won, 0) desc,
                 diamonds desc, updated_at desc nulls last
      ) as position
      from public.profiles
      where not public._is_admin_user(id)
        and coalesce(hardcore_points, 0) > 0
    ) ranked where id = v_uid;

    -- HC puanı yoksa tüm profiller arasında sırayı göster (eski davranış).
    if v_local_rank is null then
      select position into v_local_rank
      from (
        select id, row_number() over (
          order by coalesce(hardcore_points, 0) desc, coalesce(games_won, 0) desc,
                   diamonds desc, updated_at desc nulls last
        ) as position
        from public.profiles
        where not public._is_admin_user(id)
      ) ranked where id = v_uid;
    end if;
  else
    select position into v_local_rank
    from (
      select id, row_number() over (
        order by coalesce(rank_points, 0) desc, coalesce(games_won, 0) desc,
                 diamonds desc, updated_at desc nulls last
      ) as position
      from public.profiles
      where not public._is_admin_user(id)
    ) ranked where id = v_uid;
  end if;

  select json_build_object(
    'rank_pos', coalesce(v_local_rank, 0),
    'user_id', p.id,
    'username', coalesce(nullif(trim(p.username), ''), 'Traveler'),
    'diamonds', p.diamonds,
    'games_won', coalesce(p.games_won, 0),
    'rank_points', coalesce(p.rank_points, 0),
    'hardcore_points', coalesce(p.hardcore_points, 0)
  )
  into v_local
  from public.profiles p
  where p.id = v_uid;

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

notify pgrst, 'reload schema';
