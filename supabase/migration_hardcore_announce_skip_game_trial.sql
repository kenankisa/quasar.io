-- =============================================================================
-- Quasar.io — Oyun Deneme Hardcore zaferleri canlı duyuru SPAM'ini kes
-- SQL Editor'da bir kez çalıştırın.
--
-- Sorun: game_trial sim'leri peş peşe hardcore_points +1 → onlarca
--        "… Hardcore Evreni'ni fethetti" balonu tüm ekranı kaplıyor.
-- Çözüm: is_game_trial kullanıcılarında duyuru yazma.
-- =============================================================================

create or replace function public._announce_hardcore_victory()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_is_trial boolean := false;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if coalesce(new.hardcore_points, 0) <= coalesce(old.hardcore_points, 0) then
    return new;
  end if;

  begin
    v_is_trial := coalesce(public._is_game_trial_auth_user(new.id), false);
  exception when undefined_function then
    v_is_trial := false;
  end;

  -- Oyun Deneme / sim grind → gerçek oyunculara balon yağdırma.
  if v_is_trial then
    return new;
  end if;

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

revoke all on function public._announce_hardcore_victory()
  from public, anon, authenticated;

drop trigger if exists trg_announce_hardcore_victory on public.profiles;
create trigger trg_announce_hardcore_victory
  after update of hardcore_points on public.profiles
  for each row
  execute function public._announce_hardcore_victory();

notify pgrst, 'reload schema';
