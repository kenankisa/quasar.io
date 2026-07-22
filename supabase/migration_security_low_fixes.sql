-- =============================================================================
-- Quasar.io — Low güvenlik: iç helper RPC EXECUTE kapat
-- _rank_win_points_for_room / _needs_first_login_lock istemciden çağrılamasın.
-- (SECURITY DEFINER üst RPC'ler aynı DB rolüyle çağırmaya devam eder.)
-- SQL Editor'da migration_security_medium_round2.sql sonrası çalıştırın.
-- =============================================================================

revoke all on function public._rank_win_points_for_room(text)
  from public, anon, authenticated;

revoke all on function public._needs_first_login_lock(uuid)
  from public, anon, authenticated;

-- Belt & suspenders (medium round2 sonrası da garantile)
revoke all on function public._is_admin_user(uuid)
  from public, anon, authenticated;

notify pgrst, 'reload schema';
