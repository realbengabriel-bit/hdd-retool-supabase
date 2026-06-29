-- Robot Barát Approved Action Queue smoke test.
-- Creates a clearly marked smoke action request, approves it through the lifecycle RPC,
-- then validates that it appears in the read-only approved queue and is not executed.

with created as (
  select *
  from public.agent_v2_create_action_request(
    'smoke_test_approved_queue',
    '[SMOKE] Robot Barát Approved Action Queue ' || to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS.MS'),
    'Smoke test row for the Robot Barát Approved Action Queue.',
    'Verify that approved action requests appear in the read-only queue.',
    'Manual smoke test for approved queue visibility.',
    'info',
    'smoke_test',
    'robot_barat_approved_action_queue',
    null,
    null,
    null,
    null,
    jsonb_build_object(
      'smoke_test', 'robot_barat_approved_action_queue',
      'nonce', gen_random_uuid()::text,
      'safety', 'read_only_queue_no_executor'
    ),
    'manual-smoke-test'
  )
),
approved as (
  select approved_row.*
  from created c
  cross join lateral public.agent_v2_approve_action_request(
    c.id,
    'manual-smoke-test',
    'Smoke approval for Robot Barát Approved Action Queue.'
  ) approved_row
)
select *
from approved;

select *
from public.agent_v2_get_approved_action_queue(100) q
where q.request_type = 'smoke_test_approved_queue'
  and q.title like '[SMOKE]%'
order by q.approved_at desc nulls last, q.created_at desc;

do $$
declare
  v_row record;
  v_executed_count integer;
begin
  select q.*
  into v_row
  from public.agent_v2_get_approved_action_queue(100) q
  where q.request_type = 'smoke_test_approved_queue'
    and q.title like '[SMOKE]%'
  order by q.approved_at desc nulls last, q.created_at desc
  limit 1;

  if v_row.id is null then
    raise exception 'Approved Queue smoke row was not found in public.agent_v2_get_approved_action_queue(100).';
  end if;

  if v_row.status <> 'approved' then
    raise exception 'Approved Queue smoke row has unexpected status: %.', v_row.status;
  end if;

  if v_row.executor_status <> 'waiting_for_future_executor' then
    raise exception 'Approved Queue smoke row has unexpected executor_status: %.', v_row.executor_status;
  end if;

  if nullif(v_row.safety_note, '') is null then
    raise exception 'Approved Queue smoke row safety_note is missing.';
  end if;

  select count(*)
  into v_executed_count
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_approved_queue'
    and ar.title like '[SMOKE]%'
    and ar.status = 'executed';

  if v_executed_count <> 0 then
    raise exception 'Approved Queue smoke found % executed smoke rows; expected zero.', v_executed_count;
  end if;
end $$;
