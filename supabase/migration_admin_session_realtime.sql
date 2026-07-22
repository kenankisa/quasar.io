-- =============================================================================
-- Quasar.io — Admin paneli: oturum aç/kapa anında "giriş yapmış oyuncular"
-- SQL Editor'da çalıştırın.
-- Not: Admin yetkisi _is_admin_user / admin_users (email hardcode yok).
-- =============================================================================

-- Admin tüm oturum satırlarını okuyabilsin (Realtime RLS için gerekli).
drop policy if exists "Admin tüm oturumları görebilir" on public.player_active_sessions;
create policy "Admin tüm oturumları görebilir"
  on public.player_active_sessions for select
  to authenticated
  using (public._is_admin_user(auth.uid()));

-- DELETE olaylarında eski satırın Realtime'a düşmesi için.
alter table public.player_active_sessions replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.player_active_sessions;
exception
  when duplicate_object then null;
end;
$$;

-- Admin kendi oturumunu "giriş yapmış oyuncular" sayısına dahil etmez.
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
