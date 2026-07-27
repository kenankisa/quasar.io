-- =============================================================================
-- Quasar.io — Hardcore universe live (players-only, 10-cup gate)
-- Run once in Supabase SQL Editor.
-- =============================================================================

-- 1) Allow hardcore on room instance / tuning tables
alter table public.game_room_instances
  drop constraint if exists game_room_instances_room_type_check;

alter table public.game_room_instances
  add constraint game_room_instances_room_type_check
  check (room_type in ('normal', 'elite', 'unique', 'hardcore'));

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'room_game_tuning'
  ) then
    alter table public.room_game_tuning
      drop constraint if exists room_game_tuning_room_type_check;
    alter table public.room_game_tuning
      add constraint room_game_tuning_room_type_check
      check (room_type in ('simple', 'normal', 'elite', 'unique', 'hardcore'));
  end if;
end $$;

insert into public.room_game_tuning (room_type, config)
values ('hardcore', '{"v":1}'::jsonb)
on conflict (room_type) do nothing;

-- 2) Hardcore unlock = 0 diamonds (trophy-gated in join)
create or replace function public._economy_unlock_required(p_room text)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
begin
  return case
    when v_room = 'simple' then 0
    when v_room = 'hardcore' then 0
    when v_room = 'elite' then greatest(0, public._economy_cfg_int('unlockElite', 100))
    when v_room = 'unique' then greatest(0, public._economy_cfg_int('unlockUnique', 200))
    else greatest(0, public._economy_cfg_int('unlockNormal', 0))
  end;
end;
$$;

-- 3) Patch join_game_room: allow hardcore + 10-cup gate
do $$
declare
  v_def text;
begin
  begin
    v_def := pg_get_functiondef('public.join_game_room(text)'::regprocedure);
  exception when undefined_function then
    raise notice 'join_game_room missing — skip patch';
    return;
  end;

  v_def := replace(
    v_def,
    'if v_room_type not in (''normal'', ''elite'', ''unique'') then',
    'if v_room_type not in (''normal'', ''elite'', ''unique'', ''hardcore'') then'
  );

  if position('hardcore_trophy_lock' in v_def) = 0
     and position('_needs_first_login_lock' in v_def) > 0 then
    v_def := replace(
      v_def,
      'raise exception ''first_login_lock'';
    end if;

    v_required := public._economy_unlock_required(v_room_type);',
      'raise exception ''first_login_lock'';
    end if;

    if v_room_type = ''hardcore'' then
      if (
        select coalesce(trophy_wins_simple,0)
             + coalesce(trophy_wins_normal,0)
             + coalesce(trophy_wins_elite,0)
             + coalesce(trophy_wins_unique,0)
        from public.profiles
        where id = v_user_id
      ) < 10 then
        raise exception ''hardcore_trophy_lock'';
      end if;
    end if;

    v_required := public._economy_unlock_required(v_room_type);'
    );
  end if;

  execute v_def;
end $$;

notify pgrst, 'reload schema';

-- 4) Allow hardcore in economy reward / ad-double room allowlists
do $$
declare
  r record;
  v_def text;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'apply_match_diamond_delta',
        'claim_match_diamond_reward',
        'claim_match_ad_double'
      )
  loop
    begin
      v_def := pg_get_functiondef(r.sig);
    exception when others then
      continue;
    end;

    v_def := replace(
      v_def,
      'if v_room not in (''simple'', ''normal'', ''elite'', ''unique'') then',
      'if v_room not in (''simple'', ''normal'', ''elite'', ''unique'', ''hardcore'') then'
    );
    v_def := replace(
      v_def,
      'if v_room not in (''normal'', ''elite'', ''unique'') then',
      'if v_room not in (''normal'', ''elite'', ''unique'', ''hardcore'') then'
    );
    -- Unique-tier payouts for hardcore placement when using room case maps
    v_def := replace(
      v_def,
      'when ''unique'' then',
      'when ''unique'' then'
    );

    begin
      execute v_def;
    exception when others then
      raise notice 'skip economy patch %: %', r.sig, sqlerrm;
    end;
  end loop;
end $$;

-- Hardcore placement/penalty helpers map to unique-tier values
create or replace function public._economy_placement_delta(p_room text, p_placement int)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
begin
  if p_placement is null or p_placement < 1 or p_placement > 3 then
    return 0;
  end if;

  if v_room = 'hardcore' then
    v_room := 'unique';
  end if;

  return case v_room
    when 'simple' then
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardSimple1', 3))
        when 2 then greatest(0, public._economy_cfg_int('rewardSimple2', 2))
        else greatest(0, public._economy_cfg_int('rewardSimple3', 1))
      end
    when 'elite' then
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardElite1', 10))
        when 2 then greatest(0, public._economy_cfg_int('rewardElite2', 6))
        else greatest(0, public._economy_cfg_int('rewardElite3', 4))
      end
    when 'unique' then
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardUnique1', 15))
        when 2 then greatest(0, public._economy_cfg_int('rewardUnique2', 10))
        else greatest(0, public._economy_cfg_int('rewardUnique3', 5))
      end
    else
      case p_placement
        when 1 then greatest(0, public._economy_cfg_int('rewardNormal1', 5))
        when 2 then greatest(0, public._economy_cfg_int('rewardNormal2', 3))
        else greatest(0, public._economy_cfg_int('rewardNormal3', 2))
      end
  end;
end;
$$;

create or replace function public._economy_elimination_delta(p_room text)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
  v_loss int;
begin
  if v_room = 'hardcore' then
    v_room := 'unique';
  end if;
  v_loss := case v_room
    when 'simple' then greatest(0, public._economy_cfg_int('penaltySimple', 0))
    when 'elite' then greatest(0, public._economy_cfg_int('penaltyElite', 3))
    when 'unique' then greatest(0, public._economy_cfg_int('penaltyUnique', 4))
    else greatest(0, public._economy_cfg_int('penaltyNormal', 2))
  end;
  return -v_loss;
end;
$$;

notify pgrst, 'reload schema';
