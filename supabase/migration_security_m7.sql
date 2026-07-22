-- =============================================================================
-- Quasar.io — M7 Low güvenlik
-- - Avatar URL: rastgele dosya adı (predictable avatar.jpg yolu)
-- SQL Editor'da migration_security_m6.sql sonrasında çalıştırın.
-- =============================================================================

create or replace function public.update_player_profile(
  p_username text,
  p_avatar_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_trimmed text;
  v_avatar text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  v_trimmed := trim(p_username);

  if char_length(v_trimmed) < 3 or char_length(v_trimmed) > 12 then
    raise exception 'invalid_username_length';
  end if;

  if exists (
    select 1 from public.profiles
    where lower(trim(username)) = lower(v_trimmed)
      and id <> v_uid
  ) then
    raise exception 'username_taken';
  end if;

  if p_avatar_url is not null then
    v_avatar := trim(p_avatar_url);
    -- Kendi klasörü altında rastgele dosya adı (eski avatar.* da geçerli)
    if v_avatar !~ (
      '^https://[a-z0-9.-]+/storage/v1/object/public/avatars/'
      || v_uid::text
      || '/[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp)$'
    ) then
      raise exception 'invalid_avatar_url';
    end if;
  end if;

  update public.profiles
  set
    username = v_trimmed,
    avatar_url = coalesce(v_avatar, avatar_url),
    updated_at = timezone('utc', now())
  where id = v_uid;

  update public.leaderboard
  set username = v_trimmed, updated_at = timezone('utc', now())
  where user_id = v_uid;
end;
$$;

revoke all on function public.update_player_profile(text, text) from public;
grant execute on function public.update_player_profile(text, text) to authenticated;
