-- =============================================================================
-- Quasar.io — Evren cosmic olay senkronu (süpernova / meteor)
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
--
-- Her açık oda için paylaşılan maç saati + cosmic_seed tutulur.
-- İstemciler aynı seed ile aynı yer/zamanda olay üretir.
-- =============================================================================

alter table public.game_room_instances
  add column if not exists match_started_at timestamptz;

alter table public.game_room_instances
  add column if not exists cosmic_seed bigint;

comment on column public.game_room_instances.match_started_at is
  'UTC maç başlangıcı — tüm istemciler paylaşılan olay saatini bundan türetir.';

comment on column public.game_room_instances.cosmic_seed is
  'Deterministik süpernova/meteor takvimi için oda seed''i.';

-- Oda her kapanışta saati/seed'i sıfırla (join / reaper / close fark etmez)
create or replace function public._clear_cosmic_sync_on_room_close()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'closed' and old.status is distinct from 'closed' then
    new.match_started_at := null;
    new.cosmic_seed := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_clear_cosmic_sync_on_room_close
  on public.game_room_instances;

create trigger trg_clear_cosmic_sync_on_room_close
  before update of status on public.game_room_instances
  for each row
  execute function public._clear_cosmic_sync_on_room_close();

-- -----------------------------------------------------------------------------
-- ensure_room_cosmic_sync — aktif üye ilk çağrıda saati/seed'i sabitler
-- -----------------------------------------------------------------------------
create or replace function public.ensure_room_cosmic_sync(p_room_instance_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_room public.game_room_instances%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_room_instance_id is null then
    raise exception 'invalid room_instance';
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

  select * into v_room
  from public.game_room_instances
  where id = p_room_instance_id
  for update;

  if not found then
    raise exception 'room_not_found';
  end if;

  if v_room.status <> 'open' then
    raise exception 'room_closed';
  end if;

  if v_room.match_started_at is null or v_room.cosmic_seed is null then
    update public.game_room_instances
    set
      match_started_at = coalesce(match_started_at, timezone('utc', now())),
      cosmic_seed = coalesce(
        cosmic_seed,
        (floor(random() * 2147483646) + 1)::bigint
      ),
      updated_at = timezone('utc', now())
    where id = p_room_instance_id
    returning * into v_room;
  end if;

  return json_build_object(
    'room_instance_id', v_room.id,
    'match_started_at', v_room.match_started_at,
    'cosmic_seed', v_room.cosmic_seed
  );
end;
$$;

revoke all on function public.ensure_room_cosmic_sync(uuid) from public, anon;
grant execute on function public.ensure_room_cosmic_sync(uuid) to authenticated;

notify pgrst, 'reload schema';
