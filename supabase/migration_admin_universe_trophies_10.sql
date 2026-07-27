-- =============================================================================
-- Quasar.io — Admin'e 10 evren kupasını (1+3+3+3) ver
-- Cap: simple 1 · normal/elite/unique 3  →  max 10 (hardcore gate).
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- Run after migration_universe_trophies.sql
-- =============================================================================

do $$
declare
  v_updated int := 0;
begin
  perform public._allow_trusted_profile_write();

  update public.profiles p
  set
    trophy_wins_simple = 1,
    trophy_wins_normal = 3,
    trophy_wins_elite = 3,
    trophy_wins_unique = 3,
    updated_at = timezone('utc', now())
  where p.id in (select a.user_id from public.admin_users a)
     or (
       nullif(trim(coalesce(current_setting('app.admin_seed_email', true), '')), '')
         is not null
       and p.id in (
         select u.id
         from auth.users u
         where lower(coalesce(u.email, '')) = lower(trim(
           current_setting('app.admin_seed_email', true)
         ))
       )
     );

  get diagnostics v_updated = row_count;

  raise notice 'admin_universe_trophies_set_10 rows=%', v_updated;
end $$;
