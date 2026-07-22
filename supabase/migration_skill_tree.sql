-- =============================================================================
-- Quasar.io — Skill tree (peak diamonds → SP, JSON levels, spend RPC)
-- SQL Editor'da çalıştırın.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Profile columns
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists peak_diamonds int not null default 20,
  add column if not exists skill_tree jsonb not null default '{}'::jsonb;

-- Everyone gets SP from current diamond balance (milestone model).
update public.profiles
set peak_diamonds = greatest(coalesce(peak_diamonds, 0), diamonds, 0);

comment on column public.profiles.peak_diamonds is
  'Highest diamond balance ever reached; floor(peak/20) = earned skill points.';
comment on column public.profiles.skill_tree is
  'Map of skill node id → level (0–10). SP spent = sum of levels.';

-- -----------------------------------------------------------------------------
-- 2) Keep peak_diamonds in sync when diamonds rise
-- -----------------------------------------------------------------------------

create or replace function public._sync_peak_diamonds()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    new.peak_diamonds := greatest(coalesce(new.peak_diamonds, 0), coalesce(new.diamonds, 0));
    return new;
  end if;

  if new.diamonds > coalesce(old.peak_diamonds, 0) then
    new.peak_diamonds := new.diamonds;
  elsif coalesce(new.peak_diamonds, 0) < coalesce(old.peak_diamonds, 0) then
    -- Clients / untrusted writes must not lower peak.
    if current_setting('quasar.trusted_profile_write', true) is distinct from '1' then
      new.peak_diamonds := old.peak_diamonds;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_peak_diamonds on public.profiles;
create trigger trg_sync_peak_diamonds
  before insert or update of diamonds, peak_diamonds on public.profiles
  for each row
  execute function public._sync_peak_diamonds();

-- -----------------------------------------------------------------------------
-- 3) Guard: block client writes to skill_tree / peak_diamonds
-- -----------------------------------------------------------------------------

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
     or NEW.active_skin is distinct from OLD.active_skin
     or NEW.peak_diamonds is distinct from OLD.peak_diamonds
     or NEW.skill_tree is distinct from OLD.skill_tree then
    raise exception 'forbidden_profile_field';
  end if;

  return NEW;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4) Helpers
-- -----------------------------------------------------------------------------

create or replace function public._skill_tree_spent(p_tree jsonb)
returns int
language sql
immutable
as $$
  select coalesce(sum((value)::int), 0)::int
  from jsonb_each_text(coalesce(p_tree, '{}'::jsonb))
  where (value) ~ '^[0-9]+$';
$$;

create or replace function public._skill_node_valid(p_node_id text)
returns boolean
language sql
immutable
as $$
  select trim(p_node_id) in (
    'boost_speed',
    'boost_duration',
    'boost_charge',
    'teleport_cooldown',
    'teleport_shield',
    'shield_cooldown',
    'shield_duration',
    'shockwave_cooldown',
    'shockwave_range',
    'shockwave_power'
  );
$$;

-- -----------------------------------------------------------------------------
-- 5) Spend skill point RPC
-- -----------------------------------------------------------------------------

create or replace function public.spend_skill_point(p_node_id text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_node text := trim(p_node_id);
  v_peak int;
  v_tree jsonb;
  v_level int;
  v_spent int;
  v_earned int;
  v_new_tree jsonb;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not public._skill_node_valid(v_node) then
    raise exception 'unknown_skill_node';
  end if;

  select peak_diamonds, coalesce(skill_tree, '{}'::jsonb)
  into v_peak, v_tree
  from public.profiles
  where id = v_uid
  for update;

  if not found then
    raise exception 'profile_not_found';
  end if;

  v_level := coalesce((v_tree ->> v_node)::int, 0);
  if v_level < 0 then
    v_level := 0;
  end if;
  if v_level >= 10 then
    raise exception 'skill_max_level';
  end if;

  v_spent := public._skill_tree_spent(v_tree);
  v_earned := greatest(0, floor(greatest(v_peak, 0) / 20.0)::int);
  if v_spent >= v_earned then
    raise exception 'insufficient_skill_points';
  end if;

  v_new_tree := jsonb_set(
    coalesce(v_tree, '{}'::jsonb),
    array[v_node],
    to_jsonb(v_level + 1),
    true
  );

  perform public._allow_trusted_profile_write();

  update public.profiles
  set
    skill_tree = v_new_tree,
    updated_at = timezone('utc', now())
  where id = v_uid;

  return json_build_object(
    'node_id', v_node,
    'level', v_level + 1,
    'skill_tree', v_new_tree,
    'peak_diamonds', v_peak,
    'earned_sp', v_earned,
    'spent_sp', v_spent + 1,
    'available_sp', v_earned - (v_spent + 1)
  );
end;
$$;

grant execute on function public.spend_skill_point(text) to authenticated;
