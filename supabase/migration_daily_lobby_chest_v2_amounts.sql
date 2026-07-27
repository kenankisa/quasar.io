-- Daily lobby chest reward tweak: only 5 / 10 / 15 diamonds.
-- Run after migration_daily_lobby_chest.sql (safe to re-run).

alter table public.daily_lobby_chest_claims
  drop constraint if exists daily_lobby_chest_claims_diamond_delta_check;

alter table public.daily_lobby_chest_claims
  add constraint daily_lobby_chest_claims_diamond_delta_check
  check (diamond_delta in (5, 10, 15));

create or replace function public.claim_daily_lobby_chest()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_day date := (timezone('utc', now()))::date;
  v_amount int;
  v_new_diamonds int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Equal chance of 5, 10, or 15.
  v_amount := (array[5, 10, 15])[1 + floor(random() * 3)::int];

  begin
    insert into public.daily_lobby_chest_claims (user_id, claim_day, diamond_delta)
    values (v_uid, v_day, v_amount);
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
    'diamonds', v_new_diamonds,
    'claim_day', v_day
  );
end;
$$;

revoke all on function public.claim_daily_lobby_chest() from public, anon;
grant execute on function public.claim_daily_lobby_chest() to authenticated;

notify pgrst, 'reload schema';
