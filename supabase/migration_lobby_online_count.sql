-- Public lobby online player count (authenticated users only).
-- Returns signed-in / in-session players from player_active_sessions.
-- No PII — count only. Excludes admin accounts. Does not include load_test_ghosts.

create or replace function public.get_lobby_online_player_count()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public._purge_stale_player_sessions();

  select count(*)::int
  into v_count
  from public.player_active_sessions s
  where not public._is_admin_user(s.user_id);

  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.get_lobby_online_player_count() from public, anon;
grant execute on function public.get_lobby_online_player_count() to authenticated;
