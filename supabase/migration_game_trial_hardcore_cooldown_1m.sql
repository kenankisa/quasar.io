-- Game trial Hardcore re-entry cooldown: 1 minute (live universe stays 1 hour).
-- Reverts zero-cooldown bypasses for trial accounts.

create or replace function public._hardcore_cooldown_until(p_user_id uuid)
returns timestamptz
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_trial boolean := false;
begin
  begin
    v_trial := coalesce(public._is_game_trial_auth_user(p_user_id), false);
  exception when undefined_function then
    v_trial := false;
  end;

  if v_trial then
    return timezone('utc', now()) + interval '1 minute';
  end if;

  return timezone('utc', now()) + interval '1 hour';
end;
$$;

revoke all on function public._hardcore_cooldown_until(uuid)
  from public, anon;
grant execute on function public._hardcore_cooldown_until(uuid)
  to authenticated;

comment on function public._hardcore_cooldown_until(uuid) is
  'Hardcore win/elim cooldown end time: 1 min (game trial) or 1 hour (live).';

-- apply_match_result: trial users get shorter cooldown via helper.
do $$
declare
  v_def text;
  v_new text;
begin
  begin
    v_def := pg_get_functiondef(
      'public.apply_match_result(text,int,boolean,uuid)'::regprocedure
    );
  exception when undefined_function then
    raise notice 'apply_match_result missing — skip';
    return;
  end;

  v_new := v_def;
  if position('_hardcore_cooldown_until(v_uid)' in v_new) = 0 then
    v_new := replace(
      v_new,
      $q$then timezone('utc', now()) + interval '1 hour'
      else hardcore_cooldown_until$q$,
      $q$then public._hardcore_cooldown_until(v_uid)
      else hardcore_cooldown_until$q$
    );
    v_new := replace(
      v_new,
      $q$then timezone('utc', now()) + interval ''1 hour''
      else hardcore_cooldown_until$q$,
      $q$then public._hardcore_cooldown_until(v_uid)
      else hardcore_cooldown_until$q$
    );
  end if;

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'apply_match_result: hardcore cooldown uses _hardcore_cooldown_until';
  end if;
end;
$$;

-- Trial victory + sim win claims: 1 min cooldown (not zero).
do $$
declare
  v_def text;
  v_new text;
begin
  begin
    v_def := pg_get_functiondef(
      'public.game_trial_claim_hardcore_victory(uuid)'::regprocedure
    );
  exception when undefined_function then
    raise notice 'game_trial_claim_hardcore_victory missing — skip';
    return;
  end;

  v_new := replace(
    v_def,
    'hardcore_cooldown_until = null,',
    'hardcore_cooldown_until = public._hardcore_cooldown_until(v_uid),'
  );

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'game_trial_claim_hardcore_victory: 1 min cooldown';
  end if;
end;
$$;

do $$
declare
  v_def text;
  v_new text;
begin
  begin
    v_def := pg_get_functiondef(
      'public.sim_claim_hardcore_victory(uuid)'::regprocedure
    );
  exception when undefined_function then
    raise notice 'sim_claim_hardcore_victory missing — skip';
    return;
  end;

  v_new := replace(
    v_def,
    'hardcore_cooldown_until = null,',
    'hardcore_cooldown_until = public._hardcore_cooldown_until(v_uid),'
  );

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'sim_claim_hardcore_victory: cooldown via helper';
  end if;
end;
$$;

-- join_hardcore_universe: trial accounts respect cooldown (no auto-clear).
do $$
declare
  v_def text;
  v_new text;
begin
  begin
    v_def := pg_get_functiondef(
      'public.join_hardcore_universe()'::regprocedure
    );
  exception when undefined_function then
    raise notice 'join_hardcore_universe missing — skip';
    return;
  end;

  v_new := v_def;

  if position('game_trial_hardcore_cd_bypass' in v_new) > 0 then
    v_new := replace(
      v_new,
      $q$-- game_trial_hardcore_cd_bypass
    if v_cd is not null and v_cd > timezone('utc', now())
       and not coalesce(public._is_game_trial_auth_user(v_user_id), false) then
      raise exception 'hardcore_cooldown'
        using detail = to_char(v_cd at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
    end if;
    if coalesce(public._is_game_trial_auth_user(v_user_id), false) then
      update public.profiles
      set hardcore_cooldown_until = null
      where id = v_user_id
        and hardcore_cooldown_until is not null;
    end if;$q$,
      $q$if v_cd is not null and v_cd > timezone('utc', now()) then
      raise exception 'hardcore_cooldown'
        using detail = to_char(v_cd at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
    end if;$q$
    );
  end if;

  -- Legacy sim branch: stop clearing cooldown on join.
  if position('hardcore_cooldown_until = null' in v_new) > 0
     and position('v_is_sim' in v_new) > 0 then
    v_new := regexp_replace(
      v_new,
      $re$elsif v_is_sim then\s*-- Clear any leftover cooldown[^\n]*\n\s*begin\s*perform public\._allow_trusted_profile_write\(\);\s*exception when undefined_function then\s*null;\s*end;\s*update public\.profiles\s*set hardcore_cooldown_until = null\s*where id = v_user_id\s*and hardcore_cooldown_until is not null;\s*end if;$re$,
      '',
      'n'
    );
  end if;

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'join_hardcore_universe: trial cooldown bypass removed';
  end if;
end;
$$;

comment on function public.game_trial_clear_hardcore_cooldown() is
  'Deprecated: trial uses 1 min HC cooldown. Admin reset only.';

notify pgrst, 'reload schema';
