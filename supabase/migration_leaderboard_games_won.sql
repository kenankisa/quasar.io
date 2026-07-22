-- =============================================================================
-- Quasar.io — Global sıralamada galibiyet sayısı (games_won) de döner
-- Sıra hâlâ: diamonds DESC, sonra games_won (tie-break).
-- SQL Editor'da çalıştırın (migration_rank_points sonrası da güvenli).
-- =============================================================================

create or replace function public.get_global_leaderboard(p_limit int default 100)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 100);
  v_top json;
  v_local json;
  v_local_rank int;
  v_in_top boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select coalesce(json_agg(row_to_json(t) order by t.rank_pos), '[]'::json)
  into v_top
  from (
    select
      row_number() over (
        order by p.diamonds desc, p.games_won desc, p.updated_at desc nulls last
      ) as rank_pos,
      p.id as user_id,
      coalesce(nullif(trim(p.username), ''), 'Traveler') as username,
      p.diamonds,
      coalesce(p.games_won, 0) as games_won,
      coalesce(p.rank_points, 0) as rank_points
    from public.profiles p
    where not public._is_admin_user(p.id)
    order by p.diamonds desc, p.games_won desc, p.updated_at desc nulls last
    limit v_limit
  ) t;

  select exists (
    select 1
    from json_array_elements(v_top) e
    where (e->>'user_id')::uuid = v_uid
  ) into v_in_top;

  if not v_in_top then
    select position into v_local_rank
    from (
      select
        id,
        row_number() over (
          order by diamonds desc, games_won desc, updated_at desc nulls last
        ) as position
      from public.profiles
      where not public._is_admin_user(id)
    ) ranked
    where id = v_uid;

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
    'local_in_top', v_in_top
  );
end;
$$;

revoke all on function public.get_global_leaderboard(int) from public, anon;
grant execute on function public.get_global_leaderboard(int) to authenticated;

notify pgrst, 'reload schema';
