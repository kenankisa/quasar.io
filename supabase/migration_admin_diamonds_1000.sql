-- =============================================================================
-- Quasar.io — Admin elmas bakiyesini 1000 yap
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- =============================================================================

do $$
declare
  v_updated int := 0;
begin
  perform public._allow_trusted_profile_write();

  update public.profiles p
  set
    diamonds = 1000,
    peak_diamonds = greatest(coalesce(p.peak_diamonds, 0), 1000),
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

  raise notice 'admin_diamonds_set_1000 rows=%', v_updated;
end $$;
