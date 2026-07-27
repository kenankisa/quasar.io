-- Daily lobby chest: admins bypass UTC daily limit (QA / testing).
-- Run after migration_daily_lobby_chest_v3_ad_double.sql.

create or replace function public.get_daily_lobby_chest_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (timezone('utc', now()))::date;
  v_claimed boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Admins may open repeatedly for testing.
  if public._is_admin_user(v_uid) then
    return jsonb_build_object(
      'available', true,
      'claim_day', v_day,
      'next_available_at', null,
      'admin_bypass', true
    );
  end if;

  select exists (
    select 1
    from public.daily_lobby_chest_claims c
    where c.user_id = v_uid
      and c.claim_day = v_day
  ) into v_claimed;

  if v_claimed then
    return jsonb_build_object(
      'available', false,
      'claim_day', v_day,
      'next_available_at',
        ((v_day + 1)::timestamp at time zone 'utc'),
      'admin_bypass', false
    );
  end if;

  return jsonb_build_object(
    'available', true,
    'claim_day', v_day,
    'next_available_at', null,
    'admin_bypass', false
  );
end;
$$;

revoke all on function public.get_daily_lobby_chest_status() from public, anon;
grant execute on function public.get_daily_lobby_chest_status() to authenticated;

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
  v_admin boolean := false;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  v_admin := public._is_admin_user(v_uid);

  -- Equal chance of base 5, 10, or 15; optional ad doubles the roll.
  v_base := (array[5, 10, 15])[1 + floor(random() * 3)::int];
  v_amount := case when coalesce(p_doubled, false) then v_base * 2 else v_base end;

  if v_admin then
    -- Clear today's claim so the unique (user_id, claim_day) insert succeeds again.
    delete from public.daily_lobby_chest_claims
    where user_id = v_uid
      and claim_day = v_day;
  end if;

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
    'claim_day', v_day,
    'admin_bypass', v_admin
  );
end;
$$;

revoke all on function public.claim_daily_lobby_chest(boolean) from public, anon;
grant execute on function public.claim_daily_lobby_chest(boolean) to authenticated;

notify pgrst, 'reload schema';
