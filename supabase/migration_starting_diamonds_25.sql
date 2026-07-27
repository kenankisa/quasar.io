-- New accounts start with 25 Diamonds (Normal unlock threshold) — existing players unchanged.

alter table public.profiles
  alter column diamonds set default 25,
  alter column peak_diamonds set default 25;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, avatar_url, diamonds, peak_diamonds, games_won, active_skin, updated_at)
  values (
    new.id,
    left(
      trim(
        coalesce(
          new.raw_user_meta_data->>'full_name',
          new.raw_user_meta_data->>'name',
          'Cosmic Void'
        )
      ),
      12
    ),
    new.raw_user_meta_data->>'avatar_url',
    25,
    25,
    0,
    'default',
    timezone('utc', now())
  )
  on conflict (id) do nothing;

  insert into public.user_skins (user_id, skin_id)
  values (new.id, 'default')
  on conflict (user_id, skin_id) do nothing;

  return new;
end;
$$;

notify pgrst, 'reload schema';
