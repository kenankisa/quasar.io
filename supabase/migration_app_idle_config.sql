-- =============================================================================
-- Quasar.io — Global AFK / idle koruma ayarları (tek satır JSON)
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- Authenticated okuyabilir; yalnızca admin (_is_admin_user) yazabilir.
-- =============================================================================

create table if not exists public.app_idle_config (
  id int primary key default 1 check (id = 1),
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

insert into public.app_idle_config (id, config) values
  (1, jsonb_build_object(
    'v', 1,
    'lobbyIdleBeforeWarningSeconds', 30,
    'lobbyWarningCountdownSeconds', 15,
    'matchIdleBeforeWarningSeconds', 10,
    'matchWarningCountdownSeconds', 3,
    'matchMassDrainPerSecond', 20,
    'matchKickMassThreshold', 25
  ))
on conflict (id) do nothing;

-- Mevcut satıra yeni alan yoksa ekle (idempotent).
update public.app_idle_config
set config = config || jsonb_build_object('matchWarningCountdownSeconds', 3),
    updated_at = timezone('utc', now())
where id = 1
  and not (config ? 'matchWarningCountdownSeconds');

alter table public.app_idle_config enable row level security;

drop policy if exists "app_idle_config_select_authenticated" on public.app_idle_config;
create policy "app_idle_config_select_authenticated"
  on public.app_idle_config
  for select
  to authenticated
  using (true);

drop policy if exists "app_idle_config_upsert_admin" on public.app_idle_config;
create policy "app_idle_config_upsert_admin"
  on public.app_idle_config
  for all
  to authenticated
  using (public._is_admin_user(auth.uid()))
  with check (public._is_admin_user(auth.uid()));

-- Bayat oturum eşiği: lobi 30+15 sn uyarısı + heartbeat payı
create or replace function public._purge_stale_player_sessions()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.player_active_sessions
  where last_heartbeat_at < timezone('utc', now()) - interval '90 seconds';
end;
$$;

notify pgrst, 'reload schema';
