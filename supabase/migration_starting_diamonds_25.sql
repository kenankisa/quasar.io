-- New accounts start with 25 Diamonds (Normal unlock threshold) — existing players unchanged.
alter table public.profiles
  alter column diamonds set default 25,
  alter column peak_diamonds set default 25;

notify pgrst, 'reload schema';
