-- =============================================================================
-- Quasar.io — Lider join eşiği 250 → 280 (snowball kilidi biraz daha geç)
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- Mevcut join_game_room / join_game_room_instance gövdelerini yamar.
-- =============================================================================

create or replace function public.leader_radius_join_threshold()
returns int
language sql
immutable
parallel safe
as $$
  select 280
$$;

revoke all on function public.leader_radius_join_threshold() from public;
grant execute on function public.leader_radius_join_threshold() to authenticated, anon, service_role;

do $$
declare
  v_def text;
  v_proc regprocedure;
begin
  foreach v_proc in array array[
    'public.join_game_room(text)'::regprocedure,
    'public.join_game_room_instance(uuid)'::regprocedure
  ]
  loop
    begin
      v_def := pg_get_functiondef(v_proc);
    exception when undefined_function then
      continue;
    end;

    v_def := replace(
      v_def,
      'leader_radius < 250',
      'leader_radius < public.leader_radius_join_threshold()'
    );
    v_def := replace(
      v_def,
      'leader_radius >= 250',
      'leader_radius >= public.leader_radius_join_threshold()'
    );
    -- Eski patch'ler 280 sabiti bırakmış olabilir; helper'a çek.
    v_def := replace(
      v_def,
      'leader_radius < 280',
      'leader_radius < public.leader_radius_join_threshold()'
    );
    v_def := replace(
      v_def,
      'leader_radius >= 280',
      'leader_radius >= public.leader_radius_join_threshold()'
    );

    execute v_def;
  end loop;
end $$;

notify pgrst, 'reload schema';
