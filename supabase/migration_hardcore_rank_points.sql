-- =============================================================================
-- Quasar.io — Hardcore 1.’lik → +7 galibiyet puanı (rank_points)
-- SQL Editor'da bir kez çalıştırın.
--
-- Hardcore zaferi zaten +1 hardcore_points verir.
-- Aynı 1.’lik rütbe (galibiyet) puanına da +7 ekler (canlı PvP, ~1s cooldown).
-- Admin paneli: winPointsHardcore (varsayılan 7).
-- Not: Eski kurulumlarda 5 kaldıysa migration_hardcore_rank_points_7.sql çalıştırın.
-- =============================================================================

-- 1) Mevcut / yeni config satırına winPointsHardcore ekle
update public.app_rank_config
set
  config = coalesce(config, '{}'::jsonb) || jsonb_build_object('winPointsHardcore', 7),
  updated_at = timezone('utc', now())
where id = 1;

insert into public.app_rank_config (id, config)
values (
  1,
  jsonb_build_object(
    'v', 1,
    'winPointsSimple', 0,
    'winPointsNormal', 1,
    'winPointsElite', 2,
    'winPointsUnique', 3,
    'winPointsHardcore', 7,
    'minPointsStellar', 8,
    'minPointsNova', 25,
    'minPointsQuasar', 75,
    'minPointsSingularity', 200
  )
)
on conflict (id) do nothing;

-- 2) Oda tipine göre 1.’lik puanı — hardcore dahil
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
