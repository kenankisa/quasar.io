-- =============================================================================
-- Quasar.io — Evren sunucu yaşam döngüsü (düzeltme)
-- Normal Evren 1 boşken Evren 2'ye atlama sorununu giderir.
-- SQL Editor'da TAMAMINI çalıştırın.
-- =============================================================================

create or replace function public.join_game_room(p_room_type text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_room_type text := lower(trim(p_room_type));
  v_room public.game_room_instances%rowtype;
  v_next_instance int;
  v_stale_before timestamptz := timezone('utc', now()) - interval '3 minutes';
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if v_room_type = 'simple' then
    raise exception 'training_room_no_matchmaking';
  end if;

  if v_room_type not in ('normal', 'elite', 'unique') then
    raise exception 'invalid room_type';
  end if;

  -- Önce kendi eski üyeliklerini kapat
  perform public.leave_game_room(null);

  perform pg_advisory_xact_lock(hashtext('join_game_room_' || v_room_type));

  -- Crash / zorla çıkış: 3 dk güncellenmeyen odalardaki hayalet üyeleri temizle
  -- (aktif oyunda leader_radius ~5 sn'de bir güncellenir)
  update public.game_room_members grm
  set left_at = timezone('utc', now())
  from public.game_room_instances gri
  where grm.room_instance_id = gri.id
    and gri.room_type = v_room_type
    and grm.left_at is null
    and coalesce(gri.updated_at, gri.created_at) < v_stale_before;

  -- Sahipsiz veya bayat açık sunucuları kapat
  update public.game_room_instances gri
  set
    status = 'closed',
    real_player_count = 0,
    leader_radius = 25,
    updated_at = timezone('utc', now())
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and (
      not exists (
        select 1
        from public.game_room_members grm
        where grm.room_instance_id = gri.id
          and grm.left_at is null
      )
      or coalesce(gri.updated_at, gri.created_at) < v_stale_before
    );

  -- Oyuncu sayısını gerçek üyelikle senkronla
  update public.game_room_instances gri
  set
    real_player_count = sub.cnt,
    updated_at = timezone('utc', now())
  from (
    select grm.room_instance_id, count(*)::int as cnt
    from public.game_room_members grm
    where grm.left_at is null
    group by grm.room_instance_id
  ) as sub
  where gri.id = sub.room_instance_id
    and gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.real_player_count != sub.cnt;

  -- 1) Gerçekten devam eden (taze) oyunculu açık sunucuya katıl
  select *
  into v_room
  from public.game_room_instances gri
  where gri.room_type = v_room_type
    and gri.status = 'open'
    and gri.leader_radius < 300
    and gri.real_player_count < 20
    and coalesce(gri.updated_at, gri.created_at) >= v_stale_before
    and exists (
      select 1
      from public.game_room_members grm
      where grm.room_instance_id = gri.id
        and grm.left_at is null
    )
  order by gri.instance_number asc
  limit 1
  for update;

  -- 2) Aktif oyun yoksa en düşük numaralı kapalı sunucuyu aç (Normal Evren 1)
  if not found then
    select *
    into v_room
    from public.game_room_instances
    where room_type = v_room_type
      and status = 'closed'
    order by instance_number asc
    limit 1
    for update;

    if found then
      delete from public.game_room_members
      where room_instance_id = v_room.id;

      update public.game_room_instances
      set
        status = 'open',
        leader_radius = 25,
        real_player_count = 0,
        updated_at = timezone('utc', now())
      where id = v_room.id
      returning * into v_room;
    else
      select coalesce(max(instance_number), 0) + 1
      into v_next_instance
      from public.game_room_instances
      where room_type = v_room_type;

      insert into public.game_room_instances (
        room_type,
        instance_number,
        real_player_count,
        leader_radius,
        status
      )
      values (v_room_type, v_next_instance, 0, 25, 'open')
      returning * into v_room;
    end if;
  end if;

  insert into public.game_room_members (room_instance_id, user_id)
  values (v_room.id, v_user_id);

  update public.game_room_instances
  set
    real_player_count = real_player_count + 1,
    updated_at = timezone('utc', now())
  where id = v_room.id
  returning * into v_room;

  return json_build_object(
    'room_instance_id', v_room.id,
    'instance_number', v_room.instance_number,
    'real_player_count', v_room.real_player_count,
    'leader_radius', v_room.leader_radius
  );
end;
$$;

create or replace function public.close_game_room(p_room_instance_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1
    from public.game_room_members grm
    where grm.room_instance_id = p_room_instance_id
      and grm.user_id = auth.uid()
      and grm.left_at is null
  ) then
    raise exception 'not an active room member';
  end if;

  update public.game_room_members
  set left_at = timezone('utc', now())
  where room_instance_id = p_room_instance_id
    and left_at is null;

  update public.game_room_instances
  set
    status = 'closed',
    real_player_count = 0,
    leader_radius = 25,
    updated_at = timezone('utc', now())
  where id = p_room_instance_id
    and status = 'open';
end;
$$;

-- -----------------------------------------------------------------------------
-- ŞİMDİ ÇALIŞAN TEMİZLİK (sizin tablonuzdaki durum için)
-- Evren 1: closed ama leader_radius 488 → 25'e çek
-- Evren 2: eğer siz lobideseniz / hayalet üye varsa kapat
-- -----------------------------------------------------------------------------

-- Kapalı odaların radius'unu sıfırla
update public.game_room_instances
set
  leader_radius = 25,
  real_player_count = 0,
  updated_at = timezone('utc', now())
where status = 'closed'
  and (leader_radius <> 25 or real_player_count <> 0);

-- 3 dk'dan eski açık üyeleri çıkar
update public.game_room_members grm
set left_at = timezone('utc', now())
from public.game_room_instances gri
where grm.room_instance_id = gri.id
  and grm.left_at is null
  and coalesce(gri.updated_at, gri.created_at)
      < timezone('utc', now()) - interval '3 minutes';

-- Sahipsiz / bayat açık evrenleri kapat
update public.game_room_instances gri
set
  status = 'closed',
  real_player_count = 0,
  leader_radius = 25,
  updated_at = timezone('utc', now())
where gri.status = 'open'
  and (
    not exists (
      select 1
      from public.game_room_members grm
      where grm.room_instance_id = gri.id
        and grm.left_at is null
    )
    or coalesce(gri.updated_at, gri.created_at)
        < timezone('utc', now()) - interval '3 minutes'
  );
