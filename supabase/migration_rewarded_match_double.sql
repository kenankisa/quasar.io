-- =============================================================================
-- Quasar.io — Rewarded ad: maç ödülünü 2× (base claim sonrası ekstra elmas)
--
-- - Eğitim (simple) kapalı
-- - Maç başına 1 (mevcut reward claim satırında flag)
-- - Hesap başına 24 saatte en fazla 5 ad_double
-- SQL Editor'da migration_match_reward_per_match.sql sonrası çalıştırın.
-- =============================================================================

alter table public.match_reward_claims
  add column if not exists ad_double_claimed_at timestamptz;

comment on column public.match_reward_claims.ad_double_claimed_at is
  'Set when a rewarded ad grants a second copy of diamond_delta for this claim.';

create index if not exists match_reward_claims_ad_double_user_idx
  on public.match_reward_claims (user_id, ad_double_claimed_at desc)
  where ad_double_claimed_at is not null;

create or replace function public.claim_rewarded_match_double(
  p_room_type text default 'normal',
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
  v_room_row public.game_room_instances%rowtype;
  v_claim public.match_reward_claims%rowtype;
  v_match_gen int;
  v_day_count int;
  v_bonus int;
  v_new_diamonds int;
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
  set ad_double_claimed_at = timezone('utc', now())
  where id = v_claim.id
    and ad_double_claimed_at is null;

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

revoke all on function public.claim_rewarded_match_double(text, uuid) from public;
grant execute on function public.claim_rewarded_match_double(text, uuid) to authenticated;
