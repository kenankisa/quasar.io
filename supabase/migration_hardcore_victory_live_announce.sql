-- =============================================================================
-- Quasar.io — Hardcore zaferi → canlı duyuru (12 sn, global)
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- Gereksinim: app_live_announcements (migration_live_announcements.sql)
-- =============================================================================

-- profiles.hardcore_points artınca herkese canlı balon (body kodlu; istemci çevirir).
create or replace function public._announce_hardcore_victory()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if coalesce(new.hardcore_points, 0) <= coalesce(old.hardcore_points, 0) then
    return new;
  end if;

  -- Oyun Deneme sim'leri canlı duyuru üretmesin (ekran spam).
  begin
    if coalesce(public._is_game_trial_auth_user(new.id), false) then
      return new;
    end if;
  exception when undefined_function then
    null;
  end;

  v_name := left(
    coalesce(nullif(trim(new.username), ''), 'Traveler'),
    12
  );

  insert into public.app_live_announcements (body, created_by, expires_at)
  values (
    '__HC_WIN__|' || v_name,
    new.id,
    timezone('utc', now()) + interval '12 seconds'
  );

  delete from public.app_live_announcements
  where expires_at < timezone('utc', now()) - interval '5 minutes';

  return new;
end;
$$;

revoke all on function public._announce_hardcore_victory() from public, anon, authenticated;

drop trigger if exists trg_announce_hardcore_victory on public.profiles;
create trigger trg_announce_hardcore_victory
  after update of hardcore_points on public.profiles
  for each row
  execute function public._announce_hardcore_victory();

notify pgrst, 'reload schema';
