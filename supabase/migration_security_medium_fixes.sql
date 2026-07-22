-- =============================================================================
-- Quasar.io — Medium güvenlik düzeltmeleri
-- 1) Rewarded 2×: prepare oturumu + min izleme süresi (RPC-only spoof zorlaştırma)
-- 2) leader_radius: maç süresi tavanı (peak farm kapatma)
-- SQL Editor'da migration_security_high_fixes.sql sonrası çalıştırın.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Rewarded ad double — prepare + claim session
-- -----------------------------------------------------------------------------

alter table public.match_reward_claims
  add column if not exists ad_double_session_id uuid,
  add column if not exists ad_double_prepared_at timestamptz;

comment on column public.match_reward_claims.ad_double_session_id is
  'One-time session from prepare_rewarded_match_double; required to claim.';
comment on column public.match_reward_claims.ad_double_prepared_at is
  'When the ad session started; claim requires min watch window.';

-- Reklam göstermeden önce oturum aç. Kimlik sunucudan; claim tek kullanımlık.
create or replace function public.prepare_rewarded_match_double(
  p_room_type text default 'normal',
  p_room_instance_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_room_row public.game_room_instances%rowtype;
  v_claim public.match_reward_claims%rowtype;
  v_match_gen int;
  v_day_count int;
  v_session uuid := gen_random_uuid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('normal', 'elite', 'unique') then
    raise exception 'ad_double_not_allowed';
  end if;

  if p_room_instance_id is null then
    raise exception 'room_required';
  end if;

  select *
  into v_room_row
  from public.game_room_instances
  where id = p_room_instance_id
  for share;

  if not found then
    raise exception 'room_not_found';
  end if;

  if lower(v_room_row.room_type) <> v_room then
    raise exception 'room_type_mismatch';
  end if;

  v_match_gen := coalesce(v_room_row.match_generation, 1);

  select *
  into v_claim
  from public.match_reward_claims
  where user_id = v_uid
    and room_instance_id = p_room_instance_id
    and match_generation = v_match_gen
    and claim_kind = 'reward'
    and diamond_delta > 0
  for update;

  if not found then
    raise exception 'no_reward_claim';
  end if;

  if v_claim.ad_double_claimed_at is not null then
    raise exception 'already_doubled';
  end if;

  -- Ödül claim'inden sonra en fazla 10 dk (ekran açıkken).
  if v_claim.created_at < timezone('utc', now()) - interval '10 minutes' then
    raise exception 'ad_double_expired';
  end if;

  select count(*)::int
  into v_day_count
  from public.match_reward_claims
  where user_id = v_uid
    and ad_double_claimed_at is not null
    and ad_double_claimed_at >= timezone('utc', now()) - interval '24 hours';

  if coalesce(v_day_count, 0) >= 5 then
    raise exception 'ad_double_daily_limit';
  end if;

  -- Aktif oturum varsa yeniden kullan (aynı reklam akışı).
  if v_claim.ad_double_session_id is not null
     and v_claim.ad_double_prepared_at is not null
     and v_claim.ad_double_prepared_at > timezone('utc', now()) - interval '5 minutes' then
    return v_claim.ad_double_session_id;
  end if;

  update public.match_reward_claims
  set
    ad_double_session_id = v_session,
    ad_double_prepared_at = timezone('utc', now())
  where id = v_claim.id
    and ad_double_claimed_at is null;

  return v_session;
end;
$$;

revoke all on function public.prepare_rewarded_match_double(text, uuid)
  from public, anon;
grant execute on function public.prepare_rewarded_match_double(text, uuid)
  to authenticated;

create or replace function public.claim_rewarded_match_double(
  p_room_type text default 'normal',
  p_room_instance_id uuid default null,
  p_session_id uuid default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room text := lower(coalesce(nullif(trim(p_room_type), ''), 'normal'));
  v_room_row public.game_room_instances%rowtype;
  v_claim public.match_reward_claims%rowtype;
  v_match_gen int;
  v_day_count int;
  v_bonus int;
  v_new_diamonds int;
  v_elapsed_sec double precision;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_room not in ('normal', 'elite', 'unique') then
    raise exception 'ad_double_not_allowed';
  end if;

  if p_room_instance_id is null then
    raise exception 'room_required';
  end if;

  if p_session_id is null then
    raise exception 'ad_session_required';
  end if;

  select *
  into v_room_row
  from public.game_room_instances
  where id = p_room_instance_id
  for share;

  if not found then
    raise exception 'room_not_found';
  end if;

  if lower(v_room_row.room_type) <> v_room then
    raise exception 'room_type_mismatch';
  end if;

  v_match_gen := coalesce(v_room_row.match_generation, 1);

  select *
  into v_claim
  from public.match_reward_claims
  where user_id = v_uid
    and room_instance_id = p_room_instance_id
    and match_generation = v_match_gen
    and claim_kind = 'reward'
    and diamond_delta > 0
  for update;

  if not found then
    raise exception 'no_reward_claim';
  end if;

  if v_claim.ad_double_claimed_at is not null then
    raise exception 'already_doubled';
  end if;

  if v_claim.ad_double_session_id is distinct from p_session_id then
    raise exception 'ad_session_invalid';
  end if;

  if v_claim.ad_double_prepared_at is null then
    raise exception 'ad_session_invalid';
  end if;

  v_elapsed_sec := extract(
    epoch from (timezone('utc', now()) - v_claim.ad_double_prepared_at)
  );

  -- Anında prepare→claim spoof'unu keser (gerçek reklam genelde daha uzun).
  if v_elapsed_sec < 5 then
    raise exception 'ad_watch_too_short';
  end if;

  if v_elapsed_sec > 300 then
    raise exception 'ad_session_expired';
  end if;

  if v_claim.created_at < timezone('utc', now()) - interval '10 minutes' then
    raise exception 'ad_double_expired';
  end if;

  select count(*)::int
  into v_day_count
  from public.match_reward_claims
  where user_id = v_uid
    and ad_double_claimed_at is not null
    and ad_double_claimed_at >= timezone('utc', now()) - interval '24 hours';

  if coalesce(v_day_count, 0) >= 5 then
    raise exception 'ad_double_daily_limit';
  end if;

  v_bonus := v_claim.diamond_delta;

  update public.match_reward_claims
  set
    ad_double_claimed_at = timezone('utc', now()),
    ad_double_session_id = null,
    ad_double_prepared_at = null
  where id = v_claim.id
    and ad_double_claimed_at is null
    and ad_double_session_id = p_session_id;

  if not found then
    raise exception 'already_doubled';
  end if;

  perform public._allow_trusted_profile_write();
  perform set_config('quasar.analytics_room_type', v_room, true);
  perform set_config('quasar.analytics_placement', coalesce(v_claim.placement::text, ''), true);
  perform set_config('quasar.analytics_eliminated', 'false', true);

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_bonus),
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  perform set_config('quasar.analytics_room_type', '', true);
  perform set_config('quasar.analytics_placement', '', true);
  perform set_config('quasar.analytics_eliminated', '', true);

  return coalesce(v_new_diamonds, 0);
end;
$$;

-- Eski 2-arg imza çağrılarını kır (session zorunlu).
drop function if exists public.claim_rewarded_match_double(text, uuid);

revoke all on function public.claim_rewarded_match_double(text, uuid, uuid)
  from public, anon;
grant execute on function public.claim_rewarded_match_double(text, uuid, uuid)
  to authenticated;

-- -----------------------------------------------------------------------------
-- 2) leader_radius — maç süresi tavanı (AFK/API farm)
-- -----------------------------------------------------------------------------

create or replace function public.update_room_leader_radius(
  p_room_instance_id uuid,
  p_leader_radius int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_new int;
  v_elapsed_sec double precision;
  v_time_cap int;
  v_match_start timestamptz;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_leader_radius < 0 or p_leader_radius > 550 then
    raise exception 'invalid leader_radius';
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

  -- En fazla ~4 sn'de bir sync; tek adımda +50.
  if v_room.leader_radius_synced_at is not null
     and v_room.leader_radius_synced_at > timezone('utc', now()) - interval '4 seconds' then
    return;
  end if;

  v_match_start := coalesce(v_room.match_started_at, v_room.created_at);
  v_elapsed_sec := greatest(
    0,
    extract(epoch from (timezone('utc', now()) - v_match_start))
  );

  -- ~1.8 r/sn tavan: 1. sıra (350) ≈ 3 dk, 2/3 (180) ≈ 86 sn.
  -- API ile 25→350'yi ~26 sn'de şişirmeyi engeller.
  v_time_cap := least(
    550,
    25 + floor(v_elapsed_sec * 1.8)::int
  );

  v_new := least(
    v_time_cap,
    550,
    greatest(v_room.leader_radius, least(p_leader_radius, v_room.leader_radius + 50))
  );

  if v_new <= v_room.leader_radius then
    update public.game_room_instances
    set leader_radius_synced_at = timezone('utc', now())
    where id = p_room_instance_id;
    return;
  end if;

  update public.game_room_instances
  set
    leader_radius = v_new,
    peak_leader_radius = greatest(peak_leader_radius, v_new),
    leader_radius_synced_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
    and status = 'open';
end;
$$;

revoke all on function public.update_room_leader_radius(uuid, int)
  from public, anon;
grant execute on function public.update_room_leader_radius(uuid, int)
  to authenticated;

notify pgrst, 'reload schema';
