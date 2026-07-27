-- Daily lobby chest: once per UTC calendar day, server picks 5 / 10 / 15 diamonds.
-- Apply in Supabase SQL Editor after prior economy security migrations.

create table if not exists public.daily_lobby_chest_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  claim_day date not null default (timezone('utc', now()))::date,
  diamond_delta int not null check (diamond_delta in (5, 10, 15)),
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists daily_lobby_chest_claims_user_day_uidx
  on public.daily_lobby_chest_claims (user_id, claim_day);

alter table public.daily_lobby_chest_claims enable row level security;

revoke all on table public.daily_lobby_chest_claims from public, anon, authenticated;

-- Status only (no grant). available = not yet claimed today (UTC).
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
        ((v_day + 1)::timestamp at time zone 'utc')
    );
  end if;

  return jsonb_build_object(
    'available', true,
    'claim_day', v_day,
    'next_available_at', null
  );
end;
$$;

revoke all on function public.get_daily_lobby_chest_status() from public, anon;
grant execute on function public.get_daily_lobby_chest_status() to authenticated;

-- Claim once per UTC day. Amount is one of 5 / 10 / 15 (server RNG).
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
