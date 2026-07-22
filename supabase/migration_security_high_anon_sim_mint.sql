-- =============================================================================
-- Quasar.io — High: anonymous üzerinden prepare_simulated_player elmas mint kapat
-- SQL Editor'da çalıştırın (önceki load-test / security migration'larından sonra).
-- =============================================================================

create or replace function public.prepare_simulated_player(
  p_display_name text default null
)
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_meta jsonb;
  v_name text;
  v_ok boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select u.email, u.raw_user_meta_data
  into v_email, v_meta
  from auth.users u
  where u.id = v_uid;

  if not found then
    raise exception 'not authenticated';
  end if;

  -- Yalnızca admin_mint_sim_player ile üretilmiş sim hesaplar.
  -- Anonymous Auth yolu kasıtlı olarak kapalı (ücretsiz 500 elmas abuse).
  v_ok :=
    coalesce(v_meta->>'is_sim', '') = 'true'
    or coalesce(v_email, '') like 'sim.%@quasar.sim.local'
    or coalesce(v_email, '') like 'sim.%@example.com';

  if not v_ok then
    raise exception 'forbidden';
  end if;

  v_name := left(
    coalesce(
      nullif(trim(p_display_name), ''),
      nullif(trim(v_meta->>'full_name'), ''),
      'Sim' || substr(replace(v_uid::text, '-', ''), 1, 8)
    ),
    12
  );

  if exists (
    select 1 from public.profiles p
    where lower(trim(p.username)) = lower(v_name)
      and p.id <> v_uid
  ) then
    v_name := left('S' || substr(replace(v_uid::text, '-', ''), 1, 11), 12);
  end if;

  perform public._allow_trusted_profile_write();

  insert into public.profiles (
    id, username, diamonds, games_won, active_skin, updated_at
  ) values (
    v_uid, v_name, 500, 1, 'default', timezone('utc', now())
  )
  on conflict (id) do update
  set
    username = excluded.username,
    diamonds = greatest(public.profiles.diamonds, 500),
    games_won = greatest(public.profiles.games_won, 1),
    updated_at = timezone('utc', now());

  return json_build_object(
    'ok', true,
    'user_id', v_uid,
    'username', v_name
  );
end;
$$;

revoke all on function public.prepare_simulated_player(text) from public, anon;
grant execute on function public.prepare_simulated_player(text) to authenticated;

notify pgrst, 'reload schema';
