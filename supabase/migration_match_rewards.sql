-- =============================================================================
-- Quasar.io — Maç sonucu elmas RPC (mevcut projeye ekleyin)
-- Supabase SQL Editor'da çalıştırın
-- =============================================================================

create or replace function public.apply_match_result(
  p_room_type text default 'normal',
  p_placement int default null,
  p_eliminated boolean default false
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delta int := 0;
  v_won int := 0;
  v_new_diamonds int;
  v_room text := lower(coalesce(p_room_type, 'normal'));
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if coalesce(p_eliminated, false) then
    -- Basit 0, Normal −1, Elite −2, Unique −3 (floor 0)
    v_delta := case v_room
      when 'simple' then 0
      when 'elite' then -2
      when 'unique' then -3
      else -1
    end;
  else
    case v_room
      when 'simple' then
        if p_placement = 1 then
          v_delta := 3;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 2;
        elsif p_placement = 3 then
          v_delta := 1;
        end if;
      when 'elite' then
        if p_placement = 1 then
          v_delta := 10;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 6;
        elsif p_placement = 3 then
          v_delta := 4;
        end if;
      when 'unique' then
        if p_placement = 1 then
          v_delta := 15;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 10;
        elsif p_placement = 3 then
          v_delta := 5;
        end if;
      else
        -- normal
        if p_placement = 1 then
          v_delta := 5;
          v_won := 1;
        elsif p_placement = 2 then
          v_delta := 3;
        elsif p_placement = 3 then
          v_delta := 2;
        end if;
    end case;
  end if;

  if v_delta = 0 and v_won = 0 then
    select diamonds into v_new_diamonds
    from public.profiles
    where id = auth.uid();
    return coalesce(v_new_diamonds, 0);
  end if;

  update public.profiles
  set
    diamonds = greatest(0, diamonds + v_delta),
    games_won = games_won + v_won,
    updated_at = timezone('utc', now())
  where id = auth.uid()
  returning diamonds into v_new_diamonds;

  return coalesce(v_new_diamonds, 0);
end;
$$;

grant execute on function public.apply_match_result(text, int, boolean) to authenticated;

create or replace function public.record_universe_victory(p_room_type text default 'normal')
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.apply_match_result(p_room_type, 1, false);
end;
$$;

grant execute on function public.record_universe_victory(text) to authenticated;
