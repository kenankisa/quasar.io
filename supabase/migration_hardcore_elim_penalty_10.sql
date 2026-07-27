-- Hardcore elimination penalty: 15 → 10 diamonds (active arena elim only).

update public.app_economy_config
set
  config = config || jsonb_build_object('penaltyHardcore', 10),
  updated_at = timezone('utc', now())
where id = 1
  and coalesce((config->>'penaltyHardcore')::int, 15) = 15;

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
    return -greatest(0, public._economy_cfg_int('penaltyHardcore', 10));
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
