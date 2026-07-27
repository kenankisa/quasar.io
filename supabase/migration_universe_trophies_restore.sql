-- Restore universe cup awards in apply_match_result.
-- migration_app_economy_config.sql previously replaced the function and dropped
-- trophy_wins_* increments (diamonds/rank still applied). Run this on any DB
-- that already applied the broken economy migration.
-- Idempotent: no-op if trophy_wins_normal is already in the function body.

do $$
declare
  v_def text;
  v_marker text :=
    'updated_at = timezone(''utc'', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;';
  v_with_trophies text :=
    'trophy_wins_simple = case
      when v_room = ''simple'' and v_kind = ''reward'' and coalesce(p_placement, 0) = 1
        then least(1, coalesce(trophy_wins_simple, 0) + 1)
      else trophy_wins_simple
    end,
    trophy_wins_normal = case
      when v_room = ''normal'' and v_kind = ''reward'' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_normal, 0) + 1)
      else trophy_wins_normal
    end,
    trophy_wins_elite = case
      when v_room = ''elite'' and v_kind = ''reward'' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_elite, 0) + 1)
      else trophy_wins_elite
    end,
    trophy_wins_unique = case
      when v_room = ''unique'' and v_kind = ''reward'' and coalesce(p_placement, 0) = 1
        then least(3, coalesce(trophy_wins_unique, 0) + 1)
      else trophy_wins_unique
    end,
    updated_at = timezone(''utc'', now())
  where id = v_uid
  returning diamonds into v_new_diamonds;';
begin
  begin
    v_def := pg_get_functiondef(
      'public.apply_match_result(text,int,boolean,uuid)'::regprocedure
    );
  exception when undefined_function then
    raise notice 'apply_match_result missing — skip trophy restore';
    return;
  end;

  if position('trophy_wins_normal' in v_def) > 0 then
    raise notice 'universe trophies already present in apply_match_result';
    return;
  end if;

  -- 1st-place must not early-return when diamond/rank deltas are 0 (cups only).
  v_def := replace(
    v_def,
    'and not (v_room = ''simple'' and v_kind = ''reward'' and coalesce(p_placement, 0) = 1) then',
    'and not (v_kind = ''reward'' and coalesce(p_placement, 0) = 1) then'
  );

  if position(v_marker in v_def) = 0 then
    raise exception 'universe trophy restore failed — profile update marker not found';
  end if;

  v_def := replace(v_def, v_marker, v_with_trophies);

  if position('trophy_wins_normal' in v_def) = 0 then
    raise exception 'universe trophy restore failed — inject did not apply';
  end if;

  execute v_def;
  raise notice 'universe trophies restored in apply_match_result';
end $$;

notify pgrst, 'reload schema';
