-- Lobi sohbeti: mesajlar arası bekleme süresini kaldır.

create or replace function public.send_lobby_chat(p_body text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_body text := left(trim(coalesce(p_body, '')), 120);
  v_name text;
  v_row public.lobby_chat_messages;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if length(v_body) < 1 then
    raise exception 'empty_body';
  end if;

  select left(
    coalesce(nullif(trim(p.username), ''), 'Traveler'),
    12
  )
  into v_name
  from public.profiles p
  where p.id = v_uid;

  v_name := coalesce(v_name, 'Traveler');

  insert into public.lobby_chat_messages (user_id, username, body)
  values (v_uid, v_name, v_body)
  returning * into v_row;

  perform public.purge_stale_lobby_chat();

  return jsonb_build_object(
    'id', v_row.id,
    'user_id', v_row.user_id,
    'username', v_row.username,
    'body', v_row.body,
    'created_at', v_row.created_at
  );
end;
$$;

revoke all on function public.send_lobby_chat(text) from public, anon;
grant execute on function public.send_lobby_chat(text) to authenticated;

notify pgrst, 'reload schema';
