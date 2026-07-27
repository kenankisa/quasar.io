-- Daily lobby chest: optional rewarded-ad double (base 5/10/15 → 10/20/30).
-- Run after migration_daily_lobby_chest_v2_amounts.sql.

alter table public.daily_lobby_chest_claims
  add column if not exists ad_doubled boolean not null default false;

alter table public.daily_lobby_chest_claims
  drop constraint if exists daily_lobby_chest_claims_diamond_delta_check;

alter table public.daily_lobby_chest_claims
  add constraint daily_lobby_chest_claims_diamond_delta_check
  check (diamond_delta in (5, 10, 15, 20, 30));

-- Replace zero-arg overload from v1/v2 with boolean (default false).
drop function if exists public.claim_daily_lobby_chest();

create or replace function public.claim_daily_lobby_chest(
  p_doubled boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (timezone('utc', now()))::date;
  v_base int;
  v_amount int;
  v_new_diamonds int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Equal chance of base 5, 10, or 15; optional ad doubles the roll.
  v_base := (array[5, 10, 15])[1 + floor(random() * 3)::int];
  v_amount := case when coalesce(p_doubled, false) then v_base * 2 else v_base end;

  begin
    insert into public.daily_lobby_chest_claims (
      user_id, claim_day, diamond_delta, ad_doubled
    )
    values (v_uid, v_day, v_amount, coalesce(p_doubled, false));
  exception
    when unique_violation then
      return jsonb_build_object(
        'ok', false,
        'reason', 'already_claimed',
        'claim_day', v_day,
        'next_available_at',
          ((v_day + 1)::timestamp at time zone 'utc')
      );
  end;

  perform public._allow_trusted_profile_write();

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_amount),
    updated_at = timezone('utc', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;

  if v_new_diamonds is null then
    raise exception 'profile_missing';
  end if;

  return jsonb_build_object(
    'ok', true,
    'awarded', v_amount,
    'base_awarded', v_base,
    'doubled', coalesce(p_doubled, false),
    'diamonds', v_new_diamonds,
    'claim_day', v_day
  );
end;
$$;

revoke all on function public.claim_daily_lobby_chest(boolean) from public, anon;
grant execute on function public.claim_daily_lobby_chest(boolean) to authenticated;

notify pgrst, 'reload schema';
