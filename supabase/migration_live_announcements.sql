-- =============================================================================
-- Quasar.io — Canlı admin duyuru balonu (ephemeral, sunucu saatli)
-- SQL Editor'da TAMAMINI bir kez çalıştırın.
-- Gereksinim: _require_admin / _is_admin_user (migration_admin_analytics veya sonrası)
-- =============================================================================

create table if not exists public.app_live_announcements (
  id uuid primary key default gen_random_uuid(),
  body text not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null
);

create index if not exists app_live_announcements_active_idx
  on public.app_live_announcements (expires_at desc, created_at desc);

alter table public.app_live_announcements enable row level security;

revoke all on public.app_live_announcements from public, anon;
grant select on public.app_live_announcements to authenticated;

drop policy if exists "app_live_announcements_select_authenticated"
  on public.app_live_announcements;
create policy "app_live_announcements_select_authenticated"
  on public.app_live_announcements
  for select
  to authenticated
  using (true);

-- Yazma yalnızca security definer RPC ile.
revoke insert, update, delete on public.app_live_announcements
  from public, anon, authenticated;

-- Realtime (geç bağlananlar SELECT ile de yakalar).
alter table public.app_live_announcements replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.app_live_announcements;
exception
  when duplicate_object then null;
end;
$$;

-- Admin canlı duyuru gönderir. Cooldown 30 sn, metin max 160, görünürlük 12 sn.
create or replace function public.admin_post_live_announcement(p_body text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_body text := left(trim(coalesce(p_body, '')), 160);
  v_row public.app_live_announcements;
  v_last_at timestamptz;
begin
  perform public._require_admin();

  if length(v_body) < 1 then
    raise exception 'empty_body';
  end if;

  select max(a.created_at)
    into v_last_at
  from public.app_live_announcements a
  where a.created_by = v_uid;

  if v_last_at is not null
     and v_last_at > timezone('utc', now()) - interval '30 seconds' then
    raise exception 'live_announce_cooldown';
  end if;

  insert into public.app_live_announcements (body, created_by, expires_at)
  values (
    v_body,
    v_uid,
    timezone('utc', now()) + interval '12 seconds'
  )
  returning * into v_row;

  -- Eski kayıtları temizle (bayat satırlar birikmesin).
  delete from public.app_live_announcements
  where expires_at < timezone('utc', now()) - interval '5 minutes';

  return jsonb_build_object(
    'id', v_row.id,
    'body', v_row.body,
    'created_at', v_row.created_at,
    'expires_at', v_row.expires_at
  );
end;
$$;

revoke all on function public.admin_post_live_announcement(text) from public;
grant execute on function public.admin_post_live_announcement(text) to authenticated;

notify pgrst, 'reload schema';
