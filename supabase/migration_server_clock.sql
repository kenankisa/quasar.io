-- =============================================================================
-- Quasar.io — Sunucu saati (istemci clock skew düzeltmesi)
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- Canlı duyuru / lobi saati bu RPC ile senkronize edilir.
-- =============================================================================

create or replace function public.get_server_now()
returns timestamptz
language sql
stable
security definer
set search_path = public
as $$
  select timezone('utc', now());
$$;

revoke all on function public.get_server_now() from public;
grant execute on function public.get_server_now() to authenticated, anon;

notify pgrst, 'reload schema';
