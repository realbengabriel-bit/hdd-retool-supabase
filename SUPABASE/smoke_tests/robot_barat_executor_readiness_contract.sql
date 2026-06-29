-- Robot Barát Executor Readiness Contract smoke test.
-- Creates and approves a clearly marked smoke action request, then verifies the
-- read-only readiness contract guardrails. This does not execute anything.

with created as (
  select *
  from public.agent_v2_create_action_request(
    'smoke_test_executor_contract',
    '[SMOKE] Robot Barát Executor Readiness Contract ' || to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS.MS'),
    'Smoke test row for the Robot Barát Executor Readiness Contract.',
    'Verify readiness contract guardrails for approved action requests.',
    'Manual smoke test for read-only executor readiness validation.',
    'info',
    'smoke_test',
    'robot_barat_executor_readiness_contract',
    null,
    null,
    null,
    null,
    jsonb_build_object(
      'smoke_test', 'robot_barat_executor_readiness_contract',
      'nonce', gen_random_uuid()::text,
      'safety', 'read_only_contract_no_executor'
    ),
    'manual-smoke-test'
  )
), approved as (
  select approved_row.*
  from created c
  cross join lateral public.agent_v2_approve_action_request(
    c.id,
    'manual-smoke-test',
    'Smoke approval for Robot Barát Executor Readiness Contract.'
  ) approved_row
)
select *
from approved;

select *
from public.agent_v2_get_executor_readiness_queue(100) q
where q.request_type = 'smoke_test_executor_contract'
  and q.title like '[SMOKE]%'
order by q.approved_at desc nulls last, q.created_at desc;

do $$
declare
  v_row record;
  v_executed_count integer;
begin
  select q.*
  into v_row
  from public.agent_v2_get_executor_readiness_queue(100) q
  where q.request_type = 'smoke_test_executor_contract'
    and q.title like '[SMOKE]%'
  order by q.approved_at desc nulls last, q.created_at desc
  limit 1;

  if v_row.id is null then
    raise exception 'Executor readiness smoke row was not found in public.agent_v2_get_executor_readiness_queue(100).';
  end if;

  if v_row.execution_allowed_now is distinct from false then
    raise exception 'execution_allowed_now must be false, got %.', v_row.execution_allowed_now;
  end if;

  if v_row.dry_run_required is distinct from true then
    raise exception 'dry_run_required must be true, got %.', v_row.dry_run_required;
  end if;

  if v_row.manual_final_confirmation_required is distinct from true then
    raise exception 'manual_final_confirmation_required must be true, got %.', v_row.manual_final_confirmation_required;
  end if;

  if v_row.guardrails->>'no_local_agent_execution' <> 'true' then
    raise exception 'guardrails.no_local_agent_execution must be true.';
  end if;

  if v_row.guardrails->>'no_eh_oif_execution' <> 'true' then
    raise exception 'guardrails.no_eh_oif_execution must be true.';
  end if;

  if v_row.guardrails->>'no_notifications' <> 'true' then
    raise exception 'guardrails.no_notifications must be true.';
  end if;

  if nullif(v_row.safety_note, '') is null then
    raise exception 'Executor readiness smoke row safety_note is missing.';
  end if;

  select count(*)
  into v_executed_count
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_executor_contract'
    and ar.title like '[SMOKE]%'
    and ar.status = 'executed';

  if v_executed_count <> 0 then
    raise exception 'Executor readiness smoke found % executed smoke rows; expected zero.', v_executed_count;
  end if;
end $$;
