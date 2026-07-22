-- =============================================================================
-- Quasar.io — Aktif oturum = giriş yapmış oyuncu
-- Boşta kalma: istemci 30 sn + 10 sn uyarı; sunucu bayat eşiği 60 sn.
-- SQL Editor'da çalıştırın.
-- Not: Admin yetkisi _is_admin_user / _require_admin (email hardcode yok).
-- =============================================================================

create or replace function public._purge_stale_player_sessions()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.player_active_sessions
  where last_heartbeat_at < timezone('utc', now()) - interval '60 seconds';
end;
$$;

create or replace function public.get_admin_active_session_count()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  perform public._require_admin();
  perform public._purge_stale_player_sessions();

  select count(*)::integer
  into v_count
  from public.player_active_sessions s
  where not public._is_admin_user(s.user_id);

  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.get_admin_active_session_count() from public;
grant execute on function public.get_admin_active_session_count() to authenticated;
