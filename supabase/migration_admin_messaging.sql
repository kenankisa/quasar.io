-- =============================================================================
-- Quasar.io — Admin ↔ oyuncu mesajlaşma
-- SQL Editor'da çalıştırın (migration_admin_analytics.sql sonrası; _require_admin gerekir)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) TABLOLAR
-- -----------------------------------------------------------------------------

create table if not exists public.admin_message_threads (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  category text not null
    check (category in ('feedback', 'suggestion', 'bug', 'direct', 'broadcast')),
  subject text not null default '',
  status text not null default 'open'
    check (status in ('open', 'closed')),
  last_message_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists admin_message_threads_player_idx
  on public.admin_message_threads (player_id, last_message_at desc);

create index if not exists admin_message_threads_status_idx
  on public.admin_message_threads (status, last_message_at desc);

create index if not exists admin_message_threads_category_idx
  on public.admin_message_threads (category, last_message_at desc);

create table if not exists public.admin_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.admin_message_threads(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_role text not null check (sender_role in ('player', 'admin')),
  body text not null,
  created_at timestamptz not null default timezone('utc', now()),
  read_at timestamptz
);

create index if not exists admin_messages_thread_idx
  on public.admin_messages (thread_id, created_at asc);

create index if not exists admin_messages_unread_idx
  on public.admin_messages (thread_id, sender_role)
  where read_at is null;

-- -----------------------------------------------------------------------------
-- 2) RLS — doğrudan tablo erişimi yok; tüm işlemler security definer RPC
-- -----------------------------------------------------------------------------

alter table public.admin_message_threads enable row level security;
alter table public.admin_messages enable row level security;

revoke all on public.admin_message_threads from public, anon, authenticated;
revoke all on public.admin_messages from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 3) YARDIMCI
-- -----------------------------------------------------------------------------

create or replace function public._messaging_trim(p_text text, p_max int)
returns text
language sql
immutable
as $$
  select left(trim(coalesce(p_text, '')), greatest(p_max, 1));
$$;

create or replace function public._messaging_thread_json(p_thread public.admin_message_threads)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_username text;
  v_avatar text;
  v_preview text;
  v_unread int;
  v_viewer uuid := auth.uid();
begin
  select p.username, p.avatar_url
    into v_username, v_avatar
  from public.profiles p
  where p.id = p_thread.player_id;

  select m.body
    into v_preview
  from public.admin_messages m
  where m.thread_id = p_thread.id
  order by m.created_at desc
  limit 1;

  if public._is_admin_user(v_viewer) then
    select count(*)::int
      into v_unread
    from public.admin_messages m
    where m.thread_id = p_thread.id
      and m.sender_role = 'player'
      and m.read_at is null;
  elsif v_viewer = p_thread.player_id then
    select count(*)::int
      into v_unread
    from public.admin_messages m
    where m.thread_id = p_thread.id
      and m.sender_role = 'admin'
      and m.read_at is null;
  else
    v_unread := 0;
  end if;

  return jsonb_build_object(
    'id', p_thread.id,
    'player_id', p_thread.player_id,
    'player_username', coalesce(nullif(trim(v_username), ''), 'Player'),
    'player_avatar_url', v_avatar,
    'category', p_thread.category,
    'subject', p_thread.subject,
    'status', p_thread.status,
    'preview', coalesce(v_preview, ''),
    'unread_count', coalesce(v_unread, 0),
    'last_message_at', p_thread.last_message_at,
    'created_at', p_thread.created_at
  );
end;
$$;

create or replace function public._messaging_message_json(p_msg public.admin_messages)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'id', p_msg.id,
    'thread_id', p_msg.thread_id,
    'sender_id', p_msg.sender_id,
    'sender_role', p_msg.sender_role,
    'body', p_msg.body,
    'created_at', p_msg.created_at,
    'read_at', p_msg.read_at
  );
$$;

create or replace function public._messaging_insert_message(
  p_thread_id uuid,
  p_sender_id uuid,
  p_sender_role text,
  p_body text
)
returns public.admin_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_body text := public._messaging_trim(p_body, 4000);
  v_msg public.admin_messages;
begin
  if length(v_body) < 1 then
    raise exception 'empty_body';
  end if;

  insert into public.admin_messages (thread_id, sender_id, sender_role, body)
  values (p_thread_id, p_sender_id, p_sender_role, v_body)
  returning * into v_msg;

  update public.admin_message_threads
  set
    last_message_at = v_msg.created_at,
    updated_at = timezone('utc', now()),
    status = case when status = 'closed' then 'open' else status end
  where id = p_thread_id;

  return v_msg;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4) OYUNCU RPC
-- -----------------------------------------------------------------------------

create or replace function public.submit_player_message(
  p_category text,
  p_subject text,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_category text := lower(trim(coalesce(p_category, '')));
  v_subject text := public._messaging_trim(p_subject, 120);
  v_thread public.admin_message_threads;
  v_msg public.admin_messages;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if v_category not in ('feedback', 'suggestion', 'bug') then
    raise exception 'invalid_category';
  end if;

  if length(v_subject) < 1 then
    v_subject := case v_category
      when 'bug' then 'Bug report'
      when 'suggestion' then 'Suggestion'
      else 'Feedback'
    end;
  end if;

  insert into public.admin_message_threads (player_id, category, subject)
  values (v_uid, v_category, v_subject)
  returning * into v_thread;

  v_msg := public._messaging_insert_message(v_thread.id, v_uid, 'player', p_body);

  return jsonb_build_object(
    'thread', public._messaging_thread_json(v_thread),
    'message', public._messaging_message_json(v_msg)
  );
end;
$$;

create or replace function public.player_list_threads()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_items jsonb := '[]'::jsonb;
  v_row public.admin_message_threads;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  for v_row in
    select *
    from public.admin_message_threads t
    where t.player_id = v_uid
    order by t.last_message_at desc
    limit 100
  loop
    v_items := v_items || jsonb_build_array(public._messaging_thread_json(v_row));
  end loop;

  return jsonb_build_object('threads', v_items);
end;
$$;

create or replace function public.player_get_thread(p_thread_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_thread public.admin_message_threads;
  v_messages jsonb := '[]'::jsonb;
  v_msg public.admin_messages;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_thread
  from public.admin_message_threads
  where id = p_thread_id and player_id = v_uid;

  if not found then
    raise exception 'not found';
  end if;

  update public.admin_messages
  set read_at = timezone('utc', now())
  where thread_id = p_thread_id
    and sender_role = 'admin'
    and read_at is null;

  for v_msg in
    select *
    from public.admin_messages
    where thread_id = p_thread_id
    order by created_at asc
    limit 500
  loop
    v_messages := v_messages || jsonb_build_array(public._messaging_message_json(v_msg));
  end loop;

  return jsonb_build_object(
    'thread', public._messaging_thread_json(v_thread),
    'messages', v_messages
  );
end;
$$;

create or replace function public.player_reply_to_thread(
  p_thread_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_thread public.admin_message_threads;
  v_msg public.admin_messages;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_thread
  from public.admin_message_threads
  where id = p_thread_id and player_id = v_uid
  for update;

  if not found then
    raise exception 'not found';
  end if;

  if v_thread.category = 'broadcast' then
    raise exception 'cannot_reply_broadcast';
  end if;

  v_msg := public._messaging_insert_message(p_thread_id, v_uid, 'player', p_body);

  select * into v_thread from public.admin_message_threads where id = p_thread_id;

  return jsonb_build_object(
    'thread', public._messaging_thread_json(v_thread),
    'message', public._messaging_message_json(v_msg)
  );
end;
$$;

create or replace function public.player_unread_message_count()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count int;
begin
  if v_uid is null then
    return 0;
  end if;

  select count(*)::int
    into v_count
  from public.admin_messages m
  join public.admin_message_threads t on t.id = m.thread_id
  where t.player_id = v_uid
    and m.sender_role = 'admin'
    and m.read_at is null;

  return coalesce(v_count, 0);
end;
$$;

-- -----------------------------------------------------------------------------
-- 5) ADMIN RPC
-- -----------------------------------------------------------------------------

create or replace function public.admin_list_message_threads(
  p_status text default 'open',
  p_category text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(p_status, 'open')));
  v_category text := lower(nullif(trim(coalesce(p_category, '')), ''));
  v_items jsonb := '[]'::jsonb;
  v_row public.admin_message_threads;
begin
  perform public._require_admin();

  if v_status not in ('open', 'closed', 'all') then
    v_status := 'open';
  end if;

  for v_row in
    select *
    from public.admin_message_threads t
    where (v_status = 'all' or t.status = v_status)
      and (v_category is null or t.category = v_category)
    order by t.last_message_at desc
    limit 200
  loop
    v_items := v_items || jsonb_build_array(public._messaging_thread_json(v_row));
  end loop;

  return jsonb_build_object('threads', v_items);
end;
$$;

create or replace function public.admin_get_message_thread(p_thread_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_thread public.admin_message_threads;
  v_messages jsonb := '[]'::jsonb;
  v_msg public.admin_messages;
begin
  perform public._require_admin();

  select * into v_thread
  from public.admin_message_threads
  where id = p_thread_id;

  if not found then
    raise exception 'not found';
  end if;

  update public.admin_messages
  set read_at = timezone('utc', now())
  where thread_id = p_thread_id
    and sender_role = 'player'
    and read_at is null;

  for v_msg in
    select *
    from public.admin_messages
    where thread_id = p_thread_id
    order by created_at asc
    limit 500
  loop
    v_messages := v_messages || jsonb_build_array(public._messaging_message_json(v_msg));
  end loop;

  return jsonb_build_object(
    'thread', public._messaging_thread_json(v_thread),
    'messages', v_messages
  );
end;
$$;

create or replace function public.admin_reply_to_thread(
  p_thread_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_thread public.admin_message_threads;
  v_msg public.admin_messages;
begin
  perform public._require_admin();

  select * into v_thread
  from public.admin_message_threads
  where id = p_thread_id
  for update;

  if not found then
    raise exception 'not found';
  end if;

  v_msg := public._messaging_insert_message(p_thread_id, v_uid, 'admin', p_body);

  select * into v_thread from public.admin_message_threads where id = p_thread_id;

  return jsonb_build_object(
    'thread', public._messaging_thread_json(v_thread),
    'message', public._messaging_message_json(v_msg)
  );
end;
$$;

create or replace function public.admin_send_direct_message(
  p_player_id uuid,
  p_subject text,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_subject text := public._messaging_trim(p_subject, 120);
  v_thread public.admin_message_threads;
  v_msg public.admin_messages;
begin
  perform public._require_admin();

  if p_player_id is null then
    raise exception 'invalid_player';
  end if;

  if not exists (select 1 from public.profiles where id = p_player_id) then
    raise exception 'player_not_found';
  end if;

  if length(v_subject) < 1 then
    v_subject := 'Message from admin';
  end if;

  insert into public.admin_message_threads (player_id, category, subject)
  values (p_player_id, 'direct', v_subject)
  returning * into v_thread;

  v_msg := public._messaging_insert_message(v_thread.id, v_uid, 'admin', p_body);

  return jsonb_build_object(
    'thread', public._messaging_thread_json(v_thread),
    'message', public._messaging_message_json(v_msg)
  );
end;
$$;

create or replace function public.admin_broadcast_message(
  p_subject text,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_subject text := public._messaging_trim(p_subject, 120);
  v_body text := public._messaging_trim(p_body, 4000);
  v_player record;
  v_thread public.admin_message_threads;
  v_count int := 0;
begin
  perform public._require_admin();

  if length(v_body) < 1 then
    raise exception 'empty_body';
  end if;

  if length(v_subject) < 1 then
    v_subject := 'Announcement';
  end if;

  for v_player in
    select p.id
    from public.profiles p
    where not public._is_admin_user(p.id)
  loop
    insert into public.admin_message_threads (player_id, category, subject)
    values (v_player.id, 'broadcast', v_subject)
    returning * into v_thread;

    perform public._messaging_insert_message(v_thread.id, v_uid, 'admin', v_body);
    v_count := v_count + 1;
  end loop;

  return jsonb_build_object(
    'sent_count', v_count,
    'subject', v_subject
  );
end;
$$;

create or replace function public.admin_set_thread_status(
  p_thread_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text := lower(trim(coalesce(p_status, '')));
  v_thread public.admin_message_threads;
begin
  perform public._require_admin();

  if v_status not in ('open', 'closed') then
    raise exception 'invalid_status';
  end if;

  update public.admin_message_threads
  set
    status = v_status,
    updated_at = timezone('utc', now())
  where id = p_thread_id
  returning * into v_thread;

  if not found then
    raise exception 'not found';
  end if;

  return public._messaging_thread_json(v_thread);
end;
$$;

create or replace function public.admin_list_message_players(p_query text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q text := lower(trim(coalesce(p_query, '')));
  v_items jsonb := '[]'::jsonb;
begin
  perform public._require_admin();

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'username', coalesce(nullif(trim(p.username), ''), 'Player'),
        'avatar_url', p.avatar_url
      )
      order by lower(coalesce(p.username, ''))
    ),
    '[]'::jsonb
  )
  into v_items
  from (
    select *
    from public.profiles p
    where not public._is_admin_user(p.id)
      and (
        v_q = ''
        or lower(coalesce(p.username, '')) like '%' || v_q || '%'
      )
    order by lower(coalesce(p.username, ''))
    limit 100
  ) p;

  return jsonb_build_object('players', coalesce(v_items, '[]'::jsonb));
end;
$$;

create or replace function public.admin_unread_message_count()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  perform public._require_admin();

  select count(*)::int
    into v_count
  from public.admin_messages m
  where m.sender_role = 'player'
    and m.read_at is null;

  return coalesce(v_count, 0);
end;
$$;

-- -----------------------------------------------------------------------------
-- 6) İZİNLER
-- -----------------------------------------------------------------------------

revoke all on function public.submit_player_message(text, text, text) from public;
revoke all on function public.player_list_threads() from public;
revoke all on function public.player_get_thread(uuid) from public;
revoke all on function public.player_reply_to_thread(uuid, text) from public;
revoke all on function public.player_unread_message_count() from public;
revoke all on function public.admin_list_message_threads(text, text) from public;
revoke all on function public.admin_get_message_thread(uuid) from public;
revoke all on function public.admin_reply_to_thread(uuid, text) from public;
revoke all on function public.admin_send_direct_message(uuid, text, text) from public;
revoke all on function public.admin_broadcast_message(text, text) from public;
revoke all on function public.admin_set_thread_status(uuid, text) from public;
revoke all on function public.admin_list_message_players(text) from public;
revoke all on function public.admin_unread_message_count() from public;

grant execute on function public.submit_player_message(text, text, text) to authenticated;
grant execute on function public.player_list_threads() to authenticated;
grant execute on function public.player_get_thread(uuid) to authenticated;
grant execute on function public.player_reply_to_thread(uuid, text) to authenticated;
grant execute on function public.player_unread_message_count() to authenticated;
grant execute on function public.admin_list_message_threads(text, text) to authenticated;
grant execute on function public.admin_get_message_thread(uuid) to authenticated;
grant execute on function public.admin_reply_to_thread(uuid, text) to authenticated;
grant execute on function public.admin_send_direct_message(uuid, text, text) to authenticated;
grant execute on function public.admin_broadcast_message(text, text) to authenticated;
grant execute on function public.admin_set_thread_status(uuid, text) to authenticated;
grant execute on function public.admin_list_message_players(text) to authenticated;
grant execute on function public.admin_unread_message_count() to authenticated;
