-- =============================================================================
-- Quasar.io — Oyun Deneme: victory_not_verified + leader_radius tavan bypass
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
--
-- Sorun: update_room_leader_radius +50 / 4sn / süre tavanı (25+1.8*t)
--        yüzünden test sim'leri 350/550 peak'e ulaşamıyor → victory_not_verified.
-- Çözüm: is_game_trial kullanıcıları için sync limitleri + zafer peak kontrolü yok.
-- Gereksinim: _is_game_trial_auth_user (migration_game_trial_real_rules.sql)
-- =============================================================================

-- 1) Leader radius — game_trial: anında hedef boyuta yaz
create or replace function public.update_room_leader_radius(
  p_room_instance_id uuid,
  p_leader_radius int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
  v_new int;
  v_elapsed_sec double precision;
  v_time_cap int;
  v_match_start timestamptz;
  v_hard_cap int := 550;
  v_is_game_trial boolean := false;
  v_step int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  begin
    v_is_game_trial := coalesce(public._is_game_trial_auth_user(v_uid), false);
  exception when undefined_function then
    v_is_game_trial := false;
  end;

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found or v_room.status <> 'open' then
    return;
  end if;

  if lower(v_room.room_type) = 'hardcore' then
    -- Oyun Deneme: zafer 600 — lider 900'e şişmesin. Canlı oyuncu: 900 headroom.
    v_hard_cap := case when v_is_game_trial then 600 else 900 end;
  end if;

  if p_leader_radius < 0 or p_leader_radius > v_hard_cap then
    raise exception 'invalid leader_radius';
  end if;

  if not exists (
    select 1
    from public.game_room_members grm
    where grm.room_instance_id = p_room_instance_id
      and grm.user_id = v_uid
      and grm.left_at is null
  ) then
    raise exception 'not an active room member';
  end if;

  -- Oyun Deneme test: throttle / step / süre tavanı yok — peak hemen doğrulanır.
  -- Hardcore trial hard_cap=600: eski 900 şişmesini aşağı çekebilsin.
  if v_is_game_trial then
    v_new := least(
      v_hard_cap,
      greatest(
        p_leader_radius,
        least(coalesce(v_room.leader_radius, 0), v_hard_cap)
      )
    );
    if v_new = coalesce(v_room.leader_radius, 0) then
      update public.game_room_instances
      set leader_radius_synced_at = timezone('utc', now())
      where id = p_room_instance_id;
      return;
    end if;

    update public.game_room_instances
    set
      leader_radius = v_new,
      peak_leader_radius = greatest(coalesce(peak_leader_radius, 0), v_new),
      leader_radius_synced_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
    where id = p_room_instance_id
      and status = 'open';
    return;
  end if;

  if v_room.leader_radius_synced_at is not null
     and v_room.leader_radius_synced_at > timezone('utc', now()) - interval '4 seconds' then
    return;
  end if;

  v_match_start := coalesce(v_room.match_started_at, v_room.created_at);
  v_elapsed_sec := greatest(
    0,
    extract(epoch from (timezone('utc', now()) - v_match_start))
  );

  if lower(v_room.room_type) = 'hardcore' then
    v_time_cap := v_hard_cap;
    v_step := 200;
  else
    v_time_cap := least(
      v_hard_cap,
      25 + floor(v_elapsed_sec * 1.8)::int
    );
    v_step := 50;
  end if;

  v_new := least(
    v_time_cap,
    v_hard_cap,
    greatest(
      v_room.leader_radius,
      least(p_leader_radius, v_room.leader_radius + v_step)
    )
  );

  if v_new <= v_room.leader_radius then
    update public.game_room_instances
    set leader_radius_synced_at = timezone('utc', now())
    where id = p_room_instance_id;
    return;
  end if;

  update public.game_room_instances
  set
    leader_radius = v_new,
    peak_leader_radius = greatest(coalesce(peak_leader_radius, 0), v_new),
    leader_radius_synced_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
    and status = 'open';
end;
$$;

revoke all on function public.update_room_leader_radius(uuid, int)
  from public, anon;
grant execute on function public.update_room_leader_radius(uuid, int)
  to authenticated;

-- 2) apply_match_result — game_trial: peak radius zafer kapısı yok
do $$
declare
  v_def text;
  v_new text;
  v_marker text := 'game_trial_victory_peak_bypass';
begin
  begin
    v_def := pg_get_functiondef(
      'public.apply_match_result(text,int,boolean,uuid)'::regprocedure
    );
  exception when undefined_function then
    raise notice 'apply_match_result missing — skip peak bypass';
    return;
  end;

  if position(v_marker in v_def) > 0 then
    raise notice 'apply_match_result already has game_trial victory bypass';
    return;
  end if;

  v_new := v_def;

  -- Hardcore + competitive peak checks (economy / trophies variants)
  if position(
    $q$if v_kind = 'reward' and p_placement = 1 then
        if v_room = 'hardcore' then
          if v_peak < 550 then
            raise exception 'victory_not_verified';
          end if;
        elsif v_peak < 350 then
          raise exception 'victory_not_verified';
        end if;
      end if;$q$
    in v_new
  ) > 0 then
    v_new := replace(
      v_new,
      $q$if v_kind = 'reward' and p_placement = 1 then
        if v_room = 'hardcore' then
          if v_peak < 550 then
            raise exception 'victory_not_verified';
          end if;
        elsif v_peak < 350 then
          raise exception 'victory_not_verified';
        end if;
      end if;$q$,
      $q$if v_kind = 'reward' and p_placement = 1 then
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
      end if;$q$
    );
  elsif position(
    $q$if v_kind = 'reward' and p_placement = 1 then
        if v_peak < 350 then
          raise exception 'victory_not_verified';
        end if;
      end if;$q$
    in v_new
  ) > 0 then
    v_new := replace(
      v_new,
      $q$if v_kind = 'reward' and p_placement = 1 then
        if v_peak < 350 then
          raise exception 'victory_not_verified';
        end if;
      end if;$q$,
      $q$if v_kind = 'reward' and p_placement = 1 then
        -- game_trial_victory_peak_bypass
        if v_peak < 350
           and not coalesce(public._is_game_trial_auth_user(v_uid), false) then
          raise exception 'victory_not_verified';
        end if;
      end if;$q$
    );
  else
    raise notice 'apply_match_result victory block not matched — check manually';
    return;
  end if;

  if v_new is distinct from v_def then
    execute v_new;
    raise notice 'apply_match_result patched: game_trial victory peak bypass';
  end if;
end;
$$;

notify pgrst, 'reload schema';
