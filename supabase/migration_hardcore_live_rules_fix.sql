-- Hardcore live rules fix:
-- - Victory validation applies to ALL users (including admin)
-- - Hardcore victory peak from room_game_tuning.victoryRadius (default 600), not 550
-- - Hardcore victory requires min-alive (economy hardcoreArenaMinAlive, default 6)
-- - Admin keeps bypass for session/cooldown/daily caps; audit claim row on admin wins

-- -----------------------------------------------------------------------------
-- 1) Helper: hardcore victory radius from room_game_tuning
-- -----------------------------------------------------------------------------
create or replace function public._hardcore_victory_min_peak()
returns int
language plpgsql
stable
set search_path = public
as $$
declare
  v_cfg jsonb := '{}'::jsonb;
begin
  begin
    select coalesce(config, '{}'::jsonb)
    into v_cfg
    from public.room_game_tuning
    where room_type = 'hardcore'
    limit 1;
  exception when others then
    v_cfg := '{}'::jsonb;
  end;

  return greatest(
    100,
    least(900, coalesce((v_cfg->>'victoryRadius')::int, 600))
  );
end;
$$;

revoke all on function public._hardcore_victory_min_peak() from public, anon, authenticated;

comment on function public._hardcore_victory_min_peak() is
  'Hardcore victory min leader/peak radius from room_game_tuning (default 600).';

-- -----------------------------------------------------------------------------
-- 2) Patch apply_match_result
-- -----------------------------------------------------------------------------
do $$
declare
  v_def text;
  v_new text;
  v_marker text := 'hardcore_live_rules_v1';
begin
  begin
    v_def := pg_get_functiondef(
      'public.apply_match_result(text,int,boolean,uuid)'::regprocedure
    );
  exception when undefined_function then
    raise notice 'apply_match_result missing — skip hardcore live rules fix';
    return;
  end;

  if position(v_marker in v_def) > 0 then
    raise notice 'apply_match_result already has %', v_marker;
    return;
  end if;

  v_new := v_def;

  -- Add v_alive to declare block (idempotent).
  if position('v_alive int' in v_new) = 0 then
    v_new := replace(
      v_new,
      '  v_day_cap int;',
      '  v_day_cap int;' || E'\n  v_alive int;'
    );
  end if;

  -- Victory validation for everyone (before admin bypass).
  if position(v_marker in v_new) = 0 then
    v_new := replace(
      v_new,
      E'  if not public._is_admin_user(v_uid) then\n',
      $patch$  -- hardcore_live_rules_v1: victory validation for all users
  if v_kind = 'reward' and coalesce(p_placement, 0) = 1 and v_room <> 'simple' then
    if p_room_instance_id is null then
      raise exception 'room_instance_required';
    end if;

    if v_room_row.id is null or v_room_row.id is distinct from p_room_instance_id then
      select * into v_room_row
      from public.game_room_instances
      where id = p_room_instance_id;

      if not found then
        raise exception 'room_not_found';
      end if;
    end if;

    if lower(v_room_row.room_type) <> v_room then
      raise exception 'room_type_mismatch';
    end if;

    v_peak := greatest(
      coalesce(v_room_row.peak_leader_radius, 25),
      coalesce(v_room_row.leader_radius, 25)
    );

    if not coalesce(public._is_game_trial_auth_user(v_uid), false) then
      if v_room = 'hardcore' then
        select count(*)::int
        into v_alive
        from public.game_room_members
        where room_instance_id = p_room_instance_id
          and left_at is null;

        if coalesce(v_alive, 0) < greatest(
          2,
          least(20, public._economy_cfg_int('hardcoreArenaMinAlive', 6))
        ) then
          raise exception 'hardcore_arena_inactive';
        end if;

        if v_peak < public._hardcore_victory_min_peak() then
          raise exception 'victory_not_verified';
        end if;
      elsif v_peak < 350 then
        raise exception 'victory_not_verified';
      end if;
    end if;
  end if;

  if not public._is_admin_user(v_uid) then
$patch$
    );
  end if;

  -- Remove duplicate victory peak check inside non-admin room block (game_trial variant).
  v_new := replace(
    v_new,
    $old1$      if v_kind = 'reward' and p_placement = 1 then
        -- game_trial_victory_peak_bypass
        if not coalesce(public._is_game_trial_auth_user(v_uid), false) then
          if v_room = 'hardcore' then
            if v_peak < 550 then
              raise exception 'victory_not_verified';
            end if;
          elsif v_peak < 350 then
            raise exception 'victory_not_verified';
          end if;
        end if;
      end if;$old1$,
    $new1$      -- hardcore_live_rules_v1: victory peak verified above for all users
      null;$new1$
  );

  -- Remove duplicate victory peak check (plain hardcore 550 variant).
  v_new := replace(
    v_new,
    $old2$      if v_kind = 'reward' and p_placement = 1 then
        if v_room = 'hardcore' then
          if v_peak < 550 then
            raise exception 'victory_not_verified';
          end if;
        elsif v_peak < 350 then
          raise exception 'victory_not_verified';
        end if;
      end if;$old2$,
    $new2$      -- hardcore_live_rules_v1: victory peak verified above for all users
      null;$new2$
  );

  -- Admin audit claim (no session / caps) so rewards are traceable.
  if position('hardcore_live_rules_admin_claim' in v_new) = 0 then
    v_new := replace(
      v_new,
      E'  end if;\n\n  perform public._allow_trusted_profile_write();',
      $admin$  elsif public._is_admin_user(v_uid)
    and v_room <> 'simple'
    and p_room_instance_id is not null
    and not exists (
      select 1
      from public.match_reward_claims c
      where c.user_id = v_uid
        and c.room_instance_id = p_room_instance_id
    )
  then
    -- hardcore_live_rules_admin_claim
    if v_room_row.id is null or v_room_row.id is distinct from p_room_instance_id then
      select * into v_room_row
      from public.game_room_instances
      where id = p_room_instance_id;
    end if;

    if found then
      v_match_gen := coalesce(v_room_row.match_generation, 1);
      begin
        insert into public.match_reward_claims (
          user_id,
          room_type,
          room_instance_id,
          play_session_id,
          claim_kind,
          placement,
          diamond_delta,
          match_generation
        )
        values (
          v_uid,
          v_room,
          p_room_instance_id,
          null,
          v_kind,
          case when v_kind = 'penalty' then null else p_placement end,
          v_delta,
          v_match_gen
        );
      exception
        when unique_violation then
          raise exception 'already_claimed';
      end;
    end if;
  end if;

  perform public._allow_trusted_profile_write();$admin$
    );
  end if;

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'apply_match_result patched: %', v_marker;
  else
    raise notice 'apply_match_result unchanged — patterns not matched';
  end if;
exception
  when others then
    raise notice 'apply_match_result hardcore live rules fix failed: %', sqlerrm;
end;
$$;

notify pgrst, 'reload schema';
