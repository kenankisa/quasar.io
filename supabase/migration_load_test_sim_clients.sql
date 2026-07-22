-- =============================================================================
-- Quasar.io — Gerçek istemci yük testi (sim hesap bootstrap)
-- Her sim oyuncu ayrı auth oturumu açar; bu RPC profili maça hazırlar.
-- SQL Editor'da çalıştırın.
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
  v_app jsonb;
  v_name text;
  v_ok boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select u.email, u.raw_user_meta_data, u.raw_app_meta_data
  into v_email, v_meta, v_app
  from auth.users u
  where u.id = v_uid;

  if not found then
    raise exception 'not authenticated';
  end if;

  v_ok :=
    coalesce(v_meta->>'is_sim', '') = 'true'
    or coalesce(v_email, '') like 'sim.%@quasar.sim.local'
    or coalesce(v_app->>'provider', '') = 'anonymous'
    or coalesce(v_app->'providers', '[]'::jsonb) ? 'anonymous';

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

  -- Kullanıcı adı çakışırsa benzersizleştir
  if exists (
    select 1 from public.profiles p
    where lower(trim(p.username)) = lower(v_name)
      and p.id <> v_uid
  ) then
    v_name := left('S' || substr(replace(v_uid::text, '-', ''), 1, 11), 12);
  end if;

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

-- Admin: sim e-posta hesaplarını temizle (best-effort)
create or replace function public.admin_cleanup_simulated_players()
returns json
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ids uuid[];
  v_n int := 0;
begin
  perform public._require_admin();

  select coalesce(array_agg(u.id), '{}'::uuid[])
  into v_ids
  from auth.users u
  where coalesce(u.raw_user_meta_data->>'is_sim', '') = 'true'
     or coalesce(u.email, '') like 'sim.%@quasar.sim.local';

  v_n := coalesce(cardinality(v_ids), 0);
  if v_n = 0 then
    return json_build_object('deleted', 0);
  end if;

  update public.game_room_members
  set left_at = timezone('utc', now())
  where user_id = any (v_ids)
    and left_at is null;

  delete from public.player_active_sessions where user_id = any (v_ids);

  begin
    delete from auth.identities where user_id = any (v_ids);
    delete from auth.users where id = any (v_ids);
  exception when others then
    return json_build_object(
      'deleted', 0,
      'error', SQLERRM,
      'candidates', v_n
    );
  end;

  return json_build_object('deleted', v_n);
end;
$$;

revoke all on function public.admin_cleanup_simulated_players() from public, anon;
grant execute on function public.admin_cleanup_simulated_players() to authenticated;
