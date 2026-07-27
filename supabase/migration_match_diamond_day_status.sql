-- Rolling 24h match diamond progress for reward UI ("Today X / cap").
-- Run after migration_app_economy_config.sql.

create or replace function public.get_match_diamond_day_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_cap int;
  v_earned int;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  v_cap := greatest(1, public._economy_cfg_int('dailyMatchDiamondCap', 120));

  select coalesce(sum(greatest(c.diamond_delta, 0)), 0)::int
  into v_earned
  from public.match_reward_claims c
  where c.user_id = v_uid
    and c.claim_kind = 'reward'
    and c.created_at >= timezone('utc', now()) - interval '24 hours';

  return jsonb_build_object(
    'earned', coalesce(v_earned, 0),
    'cap', v_cap
  );
end;
$$;

revoke all on function public.get_match_diamond_day_status() from public, anon;
grant execute on function public.get_match_diamond_day_status() to authenticated;
