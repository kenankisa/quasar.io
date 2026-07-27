-- =============================================================================
-- Quasar.io — Hardcore match AFK overrides inside app_idle_config JSON
-- Run once in Supabase SQL Editor (after migration_app_idle_config.sql).
-- =============================================================================

update public.app_idle_config
set
  config = config || jsonb_build_object(
    'hardcoreAfkLateGameRadius', 450,
    'hardcoreMatchIdleBeforeWarningSeconds', 15,
    'hardcoreMatchIdleBeforeWarningLateSeconds', 10,
    'hardcoreMatchWarningCountdownSeconds', 3,
    'hardcoreMatchMassDrainPerSecond', 7,
    'hardcoreMatchMassDrainLatePerSecond', 10
  ),
  updated_at = timezone('utc', now())
where id = 1;

notify pgrst, 'reload schema';
