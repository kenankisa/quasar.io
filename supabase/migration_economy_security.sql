-- =============================================================================
-- Quasar.io — Ekonomi & maç ödülü güvenliği (C1 / C2 / C3 + H1 / H2 / H3)
-- SQL Editor'da çalıştırın (önceki migration'lardan sonra).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Profil ekonomi / skin koruması (istemci doğrudan yazamasın)
-- -----------------------------------------------------------------------------

create or replace function public._allow_trusted_profile_write()
returns void
language plpgsql
as $$
begin
  perform set_config('quasar.trusted_profile_write', '1', true);
end;
$$;

create or replace function public._guard_profile_economy()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_setting('quasar.trusted_profile_write', true) = '1' then
    return NEW;
  end if;

  if NEW.diamonds is distinct from OLD.diamonds
     or NEW.gold is distinct from OLD.gold
     or NEW.games_won is distinct from OLD.games_won
     or NEW.active_skin is distinct from OLD.active_skin then
    raise exception 'forbidden_profile_field';
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_guard_profile_economy on public.profiles;
create trigger trg_guard_profile_economy
  before update on public.profiles
  for each row
  execute function public._guard_profile_economy();

-- -----------------------------------------------------------------------------
-- 2) Kozmetik katalog + satın alma / kuşanma RPC
-- -----------------------------------------------------------------------------

create table if not exists public.cosmetic_catalog (
  item_id text primary key,
  category text not null check (category in ('skin', 'emote')),
  price_gold int not null check (price_gold >= 0),
  is_starter boolean not null default false
);

insert into public.cosmetic_catalog (item_id, category, price_gold, is_starter) values
  ('default', 'skin', 0, true),
  ('frost', 'skin', 0, true),
  ('ember', 'skin', 0, true),
  ('pulsar', 'skin', 30, false),
  ('nebula', 'skin', 40, false),
  ('plasma', 'skin', 50, false),
  ('void', 'skin', 55, false),
  ('quasar', 'skin', 70, false),
  ('eclipse', 'skin', 85, false),
  ('supernova', 'skin', 100, false),
  ('aurora', 'skin', 110, false),
  ('binary', 'skin', 140, false),
  ('singularity', 'skin', 180, false),
  ('celestial', 'skin', 200, false),
  ('emote_wave', 'emote', 10, false),
  ('emote_burst', 'emote', 20, false),
  ('emote_void', 'emote', 35, false)
on conflict (item_id) do update set
  category = excluded.category,
  price_gold = excluded.price_gold,
  is_starter = excluded.is_starter;

alter table public.cosmetic_catalog enable row level security;

drop policy if exists "cosmetic_catalog_select" on public.cosmetic_catalog;
create policy "cosmetic_catalog_select"
  on public.cosmetic_catalog
  for select
  to authenticated, anon
  using (true);

grant select on public.cosmetic_catalog to anon, authenticated;

-- Doğrudan yazmayı kapat (RPC security definer ile yazar).
drop policy if exists "Kullanıcılar görünüm satın alabilir" on public.user_skins;
revoke insert, update, delete on public.user_skins from authenticated, anon, public;

create or replace function public.purchase_cosmetic(p_item_id text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.cosmetic_catalog%rowtype;
  v_gold int;
  v_new_gold int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_item
  from public.cosmetic_catalog
  where item_id = trim(p_item_id);

  if not found then
    raise exception 'unknown_item';
  end if;

  if exists (
    select 1 from public.user_skins
    where user_id = v_uid and skin_id = v_item.item_id
  ) then
    raise exception 'already_owned';
  end if;

  select gold into v_gold
  from public.profiles
  where id = v_uid
  for update;

  if v_gold is null then
    raise exception 'profile_not_found';
  end if;

  if v_gold < v_item.price_gold then
    raise exception 'insufficient_gold';
  end if;

  perform public._allow_trusted_profile_write();

  update public.profiles
  set
    gold = gold - v_item.price_gold,
    updated_at = timezone('utc', now())
  where id = v_uid
  returning gold into v_new_gold;

  insert into public.user_skins (user_id, skin_id)
  values (v_uid, v_item.item_id);

  return json_build_object(
    'item_id', v_item.item_id,
    'gold', v_new_gold
  );
end;
$$;

grant execute on function public.purchase_cosmetic(text) to authenticated;

create or replace function public.equip_cosmetic(p_item_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_item public.cosmetic_catalog%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_item
  from public.cosmetic_catalog
  where item_id = trim(p_item_id);

  if not found then
    raise exception 'unknown_item';
  end if;

  if v_item.category <> 'skin' then
    raise exception 'not_equippable';
  end if;

  if not v_item.is_starter and not exists (
    select 1 from public.user_skins
    where user_id = v_uid and skin_id = v_item.item_id
  ) then
    raise exception 'not_owned';
  end if;

  perform public._allow_trusted_profile_write();

  update public.profiles
  set
    active_skin = v_item.item_id,
    updated_at = timezone('utc', now())
  where id = v_uid;
end;
$$;

grant execute on function public.equip_cosmetic(text) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) Leaderboard doğrudan yazmayı kapat
-- -----------------------------------------------------------------------------

drop policy if exists "Kullanıcılar kendi skorlarını ekleyebilir" on public.leaderboard;
drop policy if exists "Kullanıcılar kendi skorlarını güncelleyebilir" on public.leaderboard;
revoke insert, update, delete on public.leaderboard from authenticated, anon, public;

create or replace function public.save_leaderboard_score(
  p_max_mass int,
  p_room_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_max_mass < 0 or p_max_mass > 500 then
    raise exception 'invalid max_mass';
  end if;

  select username into v_username
  from public.profiles
  where id = auth.uid();

  insert into public.leaderboard (user_id, username, max_mass, room_type, updated_at)
  values (
    auth.uid(),
    coalesce(v_username, 'Traveler'),
    p_max_mass,
    p_room_type,
    timezone('utc', now())
  )
  on conflict (user_id) do update set
    max_mass = greatest(public.leaderboard.max_mass, excluded.max_mass),
    username = excluded.username,
    room_type = excluded.room_type,
    updated_at = excluded.updated_at;
end;
$$;

grant execute on function public.save_leaderboard_score(int, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) Maç ödül claim tablosu + güvenli apply_match_result
-- -----------------------------------------------------------------------------

create table if not exists public.match_reward_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  room_type text not null,
  room_instance_id uuid references public.game_room_instances(id) on delete set null,
  play_session_id uuid references public.analytics_play_sessions(id) on delete set null,
  claim_kind text not null check (claim_kind in ('reward', 'penalty')),
  placement int,
  diamond_delta int not null,
  created_at timestamptz not null default timezone('utc', now())
);

-- Oda / oturum başına tek sonuç (ödül veya ceza).
create unique index if not exists match_reward_claims_room_uidx
  on public.match_reward_claims (user_id, room_instance_id)
  where room_instance_id is not null;

create unique index if not exists match_reward_claims_session_uidx
  on public.match_reward_claims (user_id, play_session_id)
  where play_session_id is not null;

create index if not exists match_reward_claims_user_created_idx
  on public.match_reward_claims (user_id, created_at desc);

alter table public.match_reward_claims enable row level security;
revoke all on public.match_reward_claims from public, anon, authenticated;

-- Eski 3 parametreli imzayı kaldır (yenisi 4 parametre).
drop function if exists public.apply_match_result(text, int, boolean);

create or replace function public.apply_match_result(
  p_room_type text default 'normal',
  p_placement int default null,
  p_eliminated boolean default false,
  p_room_instance_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_delta int := 0;
  v_won int := 0;
  v_new_diamonds int;
  v_kind text;
  v_member record;
  v_room_row public.game_room_instances%rowtype;
  v_session public.analytics_play_sessions%rowtype;
  v_reward_count int;
  v_last_reward_at timestamptz;
  v_min_seconds int := 60;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('simple', 'normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  if coalesce(p_eliminated, false) then
    v_kind := 'penalty';
    v_delta := case v_room
      when 'simple' then 0
      when 'elite' then -2
      when 'unique' then -3
      else -1
    end;
  else
    v_kind := 'reward';
    case v_room
      when 'simple' then
        if p_placement = 1 then
          v_delta := 3;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 2;
        elsif p_placement = 3 then
          v_delta := 1;
        end if;
      when 'elite' then
        if p_placement = 1 then
          v_delta := 10;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 6;
        elsif p_placement = 3 then
          v_delta := 4;
        end if;
      when 'unique' then
        if p_placement = 1 then
          v_delta := 15;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 10;
        elsif p_placement = 3 then
          v_delta := 5;
        end if;
      else
        if p_placement = 1 then
          v_delta := 5;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 3;
        elsif p_placement = 3 then
          v_delta := 2;
        end if;
    end case;
  end if;

  if v_delta = 0 and v_won = 0 then
    select diamonds into v_new_diamonds
    from public.profiles
    where id = v_uid;
    return coalesce(v_new_diamonds, 0);
  end if;

  -- Admin test hesabı: oturum/claim kısıtlarını atla (ekonomi yine uygulanır).
  if not public._is_admin_user(v_uid) then
    -- ---- Oturum / oda kanıtı ----
    if v_room = 'simple' then
      if p_room_instance_id is not null then
        raise exception 'training_no_room_instance';
      end if;

      select *
      into v_session
      from public.analytics_play_sessions
      where user_id = v_uid
        and room_type = 'simple'
        and (
          ended_at is null
          or ended_at >= timezone('utc', now()) - interval '15 minutes'
        )
      order by started_at desc
      limit 1
      for update;

      if not found then
        raise exception 'no_play_session';
      end if;

      if v_session.started_at > timezone('utc', now()) - make_interval(secs => v_min_seconds) then
        raise exception 'match_too_short';
      end if;
    else
      if p_room_instance_id is null then
        raise exception 'room_instance_required';
      end if;

      select * into v_room_row
      from public.game_room_instances
      where id = p_room_instance_id
      for update;

      if not found then
        raise exception 'room_not_found';
      end if;

      if lower(v_room_row.room_type) <> v_room then
        raise exception 'room_type_mismatch';
      end if;

      select *
      into v_member
      from public.game_room_members
      where room_instance_id = p_room_instance_id
        and user_id = v_uid
        and (
          left_at is null
          or left_at >= timezone('utc', now()) - interval '2 hours'
        )
      order by joined_at desc
      limit 1
      for update;

      if not found then
        raise exception 'not_room_member';
      end if;

      if v_member.joined_at > timezone('utc', now()) - make_interval(secs => v_min_seconds) then
        raise exception 'match_too_short';
      end if;
    end if;

    -- ---- Rate limit (yalnızca pozitif ödüller) ----
    if v_kind = 'reward' then
      select count(*)::int, max(created_at)
      into v_reward_count, v_last_reward_at
      from public.match_reward_claims
      where user_id = v_uid
        and claim_kind = 'reward'
        and created_at >= timezone('utc', now()) - interval '24 hours';

      if coalesce(v_reward_count, 0) >= 25 then
        raise exception 'reward_daily_limit';
      end if;

      if v_last_reward_at is not null
         and v_last_reward_at > timezone('utc', now()) - interval '60 seconds' then
        raise exception 'reward_cooldown';
      end if;
    end if;

    -- ---- Tekil claim ----
    begin
      insert into public.match_reward_claims (
        user_id,
        room_type,
        room_instance_id,
        play_session_id,
        claim_kind,
        placement,
        diamond_delta
      )
      values (
        v_uid,
        v_room,
        case when v_room = 'simple' then null else p_room_instance_id end,
        case when v_room = 'simple' then v_session.id else null end,
        v_kind,
        case when v_kind = 'penalty' then null else p_placement end,
        v_delta
      );
    exception
      when unique_violation then
        raise exception 'already_claimed';
    end;
  end if;

  perform public._allow_trusted_profile_write();
  perform set_config('quasar.analytics_room_type', v_room, true);
  perform set_config(
    'quasar.analytics_placement',
    case
      when v_kind = 'penalty' then ''
      else coalesce(p_placement::text, '')
    end,
    true
  );
  perform set_config(
    'quasar.analytics_eliminated',
    case when v_kind = 'penalty' then 'true' else 'false' end,
    true
  );

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_delta),
    games_won = games_won + v_won,
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;
$$;

grant execute on function public.apply_match_result(text, int, boolean, uuid) to authenticated;

create or replace function public.record_universe_victory(
  p_room_type text default 'normal',
  p_room_instance_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.apply_match_result(p_room_type, 1, false, p_room_instance_id);
end;
$$;

drop function if exists public.record_universe_victory(text);
grant execute on function public.record_universe_victory(text, uuid) to authenticated;

-- apply_match_result içindeki ekonomi yazımı için analytics trigger'ı zaten var.
-- Eski apply_match_result'ların trusted flag kullanması: yukarıda eklendi.

-- Mevcut apply yolları dışında profiles.diamonds değiştiren RPC yoksa tamam.
-- update_player_profile yalnızca username/avatar — guard izin verir.

-- -----------------------------------------------------------------------------
-- 5) join_game_room — sunucu tarafı kilit (H1)
-- -----------------------------------------------------------------------------

create or replace function public.join_game_room(p_room_type text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room_type text := lower(trim(p_room_type));
  v_room public.game_room_instances%rowtype;
  v_next_instance int;
  v_stale_before timestamptz := timezone('utc', now()) - interval '3 minutes';
  v_diamonds int;
  v_games_won int;
  v_required int;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_room_type = 'simple' then
    raise exception 'training_room_no_matchmaking';
  end if;

  if v_room_type not in ('normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  if not public._is_admin_user(v_user_id) then
    select diamonds, games_won
    into v_diamonds, v_games_won
    from public.profiles
    where id = v_user_id;

    if coalesce(v_games_won, 0) = 0 then
      raise exception 'first_login_lock';
    end if;

    v_required := case v_room_type
      when 'normal' then 25
      when 'elite' then 100
      when 'unique' then 200
      else 0
    end;

    if coalesce(v_diamonds, 0) < v_required then
      raise exception 'insufficient_diamonds';
    end if;
  end if;

  perform public.leave_game_room(null);

  perform pg_advisory_xact_lock(hashtext('join_game_room_' || v_room_type));

  update public.game_room_members grm
  set left_at = timezone('utc', now())
  from public.game_room_instances gri
  where grm.room_instance_id = gri.id
    and gri.room_type = v_room_type
    and grm.left_at is null
    and coalesce(gri.updated_at, gri.created_at) < v_stale_before;

  update public.game_room_instances gri
  set
    status = 'closed',
    real_player_count = 0,
    leader_radius = 25,
    updated_at = timezone('utc', now())
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and (
      not exists (
        select 1
        from public.game_room_members grm
        where grm.room_instance_id = gri.id
          and grm.left_at is null
      )
      or coalesce(gri.updated_at, gri.created_at) < v_stale_before
    );

  update public.game_room_instances gri
  set
    real_player_count = sub.cnt,
    updated_at = timezone('utc', now())
  from (
    select grm.room_instance_id, count(*)::int as cnt
    from public.game_room_members grm
    where grm.left_at is null
    group by grm.room_instance_id
  ) as sub
  where gri.id = sub.room_instance_id
    and gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.real_player_count != sub.cnt;

  select *
  into v_room
  from public.game_room_instances gri
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.leader_radius < 250
    and gri.real_player_count < 20
    and coalesce(gri.updated_at, gri.created_at) >= v_stale_before
    and exists (
      select 1
      from public.game_room_members grm
      where grm.room_instance_id = gri.id
        and grm.left_at is null
    )
  order by gri.instance_number asc
  limit 1
  for update;

  if not found then
    select *
    into v_room
    from public.game_room_instances
    where room_type = v_room_type
      and status = 'closed'
    order by instance_number asc
    limit 1
    for update;

    if found then
      delete from public.game_room_members
      where room_instance_id = v_room.id;

      update public.game_room_instances
      set
        status = 'open',
        leader_radius = 25,
        real_player_count = 0,
        updated_at = timezone('utc', now())
      where id = v_room.id
      returning * into v_room;
    else
      select coalesce(max(instance_number), 0) + 1
      into v_next_instance
      from public.game_room_instances
      where room_type = v_room_type;

      insert into public.game_room_instances (
        room_type,
        instance_number,
        real_player_count,
        leader_radius,
        status
      )
      values (v_room_type, v_next_instance, 0, 25, 'open')
      returning * into v_room;
    end if;
  end if;

  insert into public.game_room_members (room_instance_id, user_id)
  values (v_room.id, v_user_id);

  update public.game_room_instances
  set
    real_player_count = real_player_count + 1,
    updated_at = timezone('utc', now())
  where id = v_room.id
  returning * into v_room;

  return json_build_object(
    'room_instance_id', v_room.id,
    'instance_number', v_room.instance_number,
    'real_player_count', v_room.real_player_count,
    'leader_radius', v_room.leader_radius
  );
end;
$$;

grant execute on function public.join_game_room(text) to authenticated;

-- -----------------------------------------------------------------------------
-- 6) close_game_room — griefing önleme (H3)
-- -----------------------------------------------------------------------------

create or replace function public.close_game_room(p_room_instance_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1
    from public.game_room_members grm
    where grm.room_instance_id = p_room_instance_id
      and grm.user_id = v_uid
      and grm.left_at is null
  ) then
    raise exception 'not an active room member';
  end if;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found or v_room.status <> 'open' then
    return;
  end if;

  -- Önce çağıranı çıkar; kalan yoksa veya zafer eşiğine yakınsa odayı kapat.
  update public.game_room_members
  set left_at = timezone('utc', now())
  where room_instance_id = p_room_instance_id
    and user_id = v_uid
    and left_at is null;

  update public.game_room_instances
  set
    real_player_count = (
      select count(*)::int
      from public.game_room_members grm
      where grm.room_instance_id = p_room_instance_id
        and grm.left_at is null
    ),
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
  returning * into v_room;

  if v_room.leader_radius < 400 and v_room.real_player_count > 0 then
    -- Griefing: diğer oyuncular varken erken kapatma yok.
    return;
  end if;

  update public.game_room_members
  set left_at = timezone('utc', now())
  where room_instance_id = p_room_instance_id
    and left_at is null;

  update public.game_room_instances
  set
    status = 'closed',
    real_player_count = 0,
    leader_radius = 25,
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
    and status = 'open';
end;
$$;

grant execute on function public.close_game_room(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 7) Eski apply_match_result yollarında trusted write (analytics migration kopyası)
--    handle_new_user INSERT etkilenmez.
-- -----------------------------------------------------------------------------

-- Not: purchase / equip / apply_match_result yukarıda flag kullanıyor.
-- Başka SECURITY DEFINER profil güncellemesi varsa flag eklenmeli.
