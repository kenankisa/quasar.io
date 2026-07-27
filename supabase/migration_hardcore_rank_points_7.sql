-- =============================================================================
-- Quasar.io — Hardcore 1.’lik galibiyet puanı: 5 → 7
-- SQL Editor'da bir kez çalıştırın.
--
-- Gerekçe: HC saatte ~1 zafer + canlı PvP → Unique (+3) üzerinde olmalı.
-- Varsayılan: Normal 1 · Elite 2 · Unique 3 · Hardcore 7
-- =============================================================================

update public.app_rank_config
set
  config = coalesce(config, '{}'::jsonb) || jsonb_build_object('winPointsHardcore', 7),
  updated_at = timezone('utc', now())
where id = 1;

create or replace function public._rank_win_points_for_room(p_room text)
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_room text := lower(coalesce(nullif(trim(p_room), ''), 'normal'));
  v_cfg jsonb;
  v_key text;
  v_default int;
  v_val int;
begin
  v_key := case v_room
    when 'simple' then 'winPointsSimple'
    when 'elite' then 'winPointsElite'
    when 'unique' then 'winPointsUnique'
    when 'hardcore' then 'winPointsHardcore'
    else 'winPointsNormal'
  end;

  v_default := case v_room
    when 'simple' then 0
    when 'elite' then 2
    when 'unique' then 3
    when 'hardcore' then 7
    else 1
  end;

  select config into v_cfg
  from public.app_rank_config
  where id = 1;

  if v_cfg is null or not (v_cfg ? v_key) then
    return v_default;
  end if;

  begin
    v_val := (v_cfg ->> v_key)::int;
  exception
    when others then
      return v_default;
  end;

  if v_val is null or v_val < 0 then
    return v_default;
  end if;

  return least(v_val, 50);
end;
$$;

revoke all on function public._rank_win_points_for_room(text)
  from public, anon, authenticated;

notify pgrst, 'reload schema';
