-- =============================================================================
-- Quasar.io — Oyun Deneme: diamond_daily_cap / reward_daily_limit bypass
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
--
-- Sorun: migration_game_trial_isolated_progress.sql eski `> 120` sabitini
--        arıyordu; economy config sonrası kontrol `> v_day_cap`. Patch hiç
--        oturmadı → sim'ler 120♦/24s sonra diamond_daily_cap ile kupa da
--        alamıyor (log: win claim failed / deferred).
-- Gereksinim: _is_game_trial_auth_user (migration_game_trial_real_rules.sql)
-- =============================================================================

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
    raise notice 'apply_match_result missing — skip economy bypass';
    return;
  end;

  v_new := v_def;

  -- 1) Diamond daily cap (economy: v_day_cap)
  if position('game_trial_diamond_cap_bypass' in v_new) = 0 then
    if position(
      $q$if coalesce(v_day_diamonds, 0) + v_delta > v_day_cap then
        raise exception 'diamond_daily_cap';
      end if;$q$
      in v_new
    ) > 0 then
      v_new := replace(
        v_new,
        $q$if coalesce(v_day_diamonds, 0) + v_delta > v_day_cap then
        raise exception 'diamond_daily_cap';
      end if;$q$,
        $q$-- game_trial_diamond_cap_bypass
      if coalesce(v_day_diamonds, 0) + v_delta > v_day_cap
         and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
        raise exception 'diamond_daily_cap';
      end if;$q$
      );
    elsif position(
      $q$if coalesce(v_day_diamonds, 0) + v_delta > 120 then
        raise exception 'diamond_daily_cap';
      end if;$q$
      in v_new
    ) > 0 then
      v_new := replace(
        v_new,
        $q$if coalesce(v_day_diamonds, 0) + v_delta > 120 then
        raise exception 'diamond_daily_cap';
      end if;$q$,
        $q$-- game_trial_diamond_cap_bypass
      if coalesce(v_day_diamonds, 0) + v_delta > 120
         and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
        raise exception 'diamond_daily_cap';
      end if;$q$
      );
    else
      raise notice 'diamond_daily_cap block not matched — check apply_match_result';
    end if;
  else
    raise notice 'game_trial_diamond_cap_bypass already present';
  end if;

  -- 2) Reward claims / day (economy: v_reward_limit) — hızlı denemede 25'e takılır
  if position('game_trial_reward_limit_bypass' in v_new) = 0 then
    if position(
      $q$if coalesce(v_reward_count, 0) >= v_reward_limit then
        raise exception 'reward_daily_limit';
      end if;$q$
      in v_new
    ) > 0 then
      v_new := replace(
        v_new,
        $q$if coalesce(v_reward_count, 0) >= v_reward_limit then
        raise exception 'reward_daily_limit';
      end if;$q$,
        $q$-- game_trial_reward_limit_bypass
      if coalesce(v_reward_count, 0) >= v_reward_limit
         and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
        raise exception 'reward_daily_limit';
      end if;$q$
      );
    elsif position(
      $q$if coalesce(v_reward_count, 0) >= 25 then
        raise exception 'reward_daily_limit';
      end if;$q$
      in v_new
    ) > 0 then
      v_new := replace(
        v_new,
        $q$if coalesce(v_reward_count, 0) >= 25 then
        raise exception 'reward_daily_limit';
      end if;$q$,
        $q$-- game_trial_reward_limit_bypass
      if coalesce(v_reward_count, 0) >= 25
         and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
        raise exception 'reward_daily_limit';
      end if;$q$
      );
    else
      raise notice 'reward_daily_limit block not matched — check apply_match_result';
    end if;
  else
    raise notice 'game_trial_reward_limit_bypass already present';
  end if;

  -- 3) Training daily (economy: v_training_limit)
  if position('game_trial_training_daily_bypass' in v_new) = 0 then
    if position(
      $q$if coalesce(v_simple_reward_count, 0) >= v_training_limit then
          raise exception 'training_daily_limit';
        end if;$q$
      in v_new
    ) > 0 then
      v_new := replace(
        v_new,
        $q$if coalesce(v_simple_reward_count, 0) >= v_training_limit then
          raise exception 'training_daily_limit';
        end if;$q$,
        $q$-- game_trial_training_daily_bypass
        if coalesce(v_simple_reward_count, 0) >= v_training_limit
           and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
          raise exception 'training_daily_limit';
        end if;$q$
      );
    end if;
  end if;

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'apply_match_result patched: game_trial economy bypass';
  else
    raise notice 'apply_match_result unchanged (already patched or patterns missing)';
  end if;
end;
$$;

notify pgrst, 'reload schema';
