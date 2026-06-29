-- Robot Barát Execution Handoff Readiness smoke test.
-- This creates approved action-request test rows, records one passed dry run,
-- records one final confirmation, and verifies that nothing is executed.
-- No cleanup is performed so Retool can inspect the smoke rows.

with created as (
  select *
  from public.agent_v2_create_action_request(
    'smoke_test_execution_handoff',
    '[SMOKE] Robot Barát Execution Handoff ready ' || to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS.MS'),
    'Smoke test row for Robot Barát execution handoff readiness.',
    'Verify execution handoff readiness after approval, passed dry run, and final confirmation.',
    'Manual smoke test for execution handoff readiness.',
    'info',
    'smoke_test',
    'robot_barat_execution_handoff_ready',
    null,
    null,
    null,
    null,
    jsonb_build_object(
      'smoke_test', 'robot_barat_execution_handoff_readiness',
      'nonce', gen_random_uuid()::text,
      'executor_route', 'manual_review',
      'safety', 'readiness_view_only_no_executor'
    ),
    'manual-smoke-test'
  )
), approved as (
  select approved_row.*
  from created c
  cross join lateral public.agent_v2_approve_action_request(
    c.id,
    'manual-smoke-test',
    'Smoke approval for Robot Barát execution handoff readiness test.'
  ) approved_row
)
select *
from approved;

with picked as (
  select ar.id
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_execution_handoff'
    and ar.title like '[SMOKE] Robot Barát Execution Handoff ready%'
  order by ar.created_at desc
  limit 1
), passed_dry_run as (
  select dr.*
  from picked p
  cross join lateral public.agent_v2_record_dry_run_result(
    p.id,
    'passed',
    'smoke_future_executor',
    'smoke',
    jsonb_build_object('input', 'smoke_execution_handoff'),
    jsonb_build_object('validated', true),
    jsonb_build_object('preview', 'handoff-ready'),
    '[]'::jsonb,
    jsonb_build_array('Smoke warning: readiness view only, no executor.'),
    '[]'::jsonb,
    jsonb_build_object(
      'smoke_safety_check', true,
      'execution_allowed_now', false,
      'no_local_agent_execution', true
    ),
    true,
    'manual-smoke-test',
    'Smoke passed dry-run for execution handoff readiness.'
  ) dr
)
select *
from passed_dry_run;

with gate as (
  select g.*
  from public.agent_v2_get_final_confirmation_gate(100) g
  where g.request_type = 'smoke_test_execution_handoff'
    and g.action_title like '[SMOKE] Robot Barát Execution Handoff ready%'
  order by g.approved_at desc nulls last
  limit 1
), confirmed as (
  select fc.*
  from gate g
  cross join lateral public.agent_v2_confirm_final_action_request(
    g.action_request_id,
    g.dry_run_id,
    'manual-smoke-test',
    'Smoke final confirmation for execution handoff readiness. This does not execute anything.',
    true,
    true,
    true
  ) fc
)
select *
from confirmed;

select *
from public.agent_v2_get_execution_handoff_readiness(100) h
where h.request_type = 'smoke_test_execution_handoff'
  and h.title like '[SMOKE] Robot Barát Execution Handoff ready%'
order by h.confirmed_at desc nulls last, h.approved_at desc nulls last;

do $$
declare
  v_handoff record;
  v_executed_count integer;
begin
  select h.*
  into v_handoff
  from public.agent_v2_get_execution_handoff_readiness(100) h
  where h.request_type = 'smoke_test_execution_handoff'
    and h.title like '[SMOKE] Robot Barát Execution Handoff ready%'
  order by h.confirmed_at desc nulls last, h.approved_at desc nulls last
  limit 1;

  if v_handoff.action_request_id is null then
    raise exception 'Execution handoff smoke row was not found.';
  end if;

  if v_handoff.handoff_status <> 'ready' then
    raise exception 'Expected handoff_status ready, got %.', v_handoff.handoff_status;
  end if;

  if v_handoff.execution_allowed_now is distinct from false then
    raise exception 'execution_allowed_now must be false, got %.', v_handoff.execution_allowed_now;
  end if;

  if v_handoff.dry_run_required is distinct from true then
    raise exception 'dry_run_required must be true, got %.', v_handoff.dry_run_required;
  end if;

  if v_handoff.manual_final_confirmation_required is distinct from true then
    raise exception 'manual_final_confirmation_required must be true, got %.', v_handoff.manual_final_confirmation_required;
  end if;

  if v_handoff.future_executor_contract->>'current_task_allows_execution' <> 'false' then
    raise exception 'future_executor_contract.current_task_allows_execution must be false.';
  end if;

  select count(*)
  into v_executed_count
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_execution_handoff'
    and ar.title like '[SMOKE]%'
    and ar.status = 'executed';

  if v_executed_count <> 0 then
    raise exception 'Execution handoff smoke found % executed smoke action requests; expected zero.', v_executed_count;
  end if;
end $$;

with created as (
  select *
  from public.agent_v2_create_action_request(
    'smoke_test_execution_handoff',
    '[SMOKE] Robot Barát Execution Handoff blocked ' || to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS.MS'),
    'Smoke test blocked row without dry run or final confirmation.',
    'Verify blocked execution handoff readiness path.',
    'Manual blocked-path smoke test for execution handoff readiness.',
    'warning',
    'smoke_test',
    'robot_barat_execution_handoff_blocked',
    null,
    null,
    null,
    null,
    jsonb_build_object(
      'smoke_test', 'robot_barat_execution_handoff_readiness_blocked',
      'nonce', gen_random_uuid()::text,
      'safety', 'blocked_path_no_dry_run_no_final_confirmation'
    ),
    'manual-smoke-test'
  )
), approved as (
  select approved_row.*
  from created c
  cross join lateral public.agent_v2_approve_action_request(
    c.id,
    'manual-smoke-test',
    'Smoke approval for blocked execution handoff readiness path.'
  ) approved_row
)
select *
from approved;

select *
from public.agent_v2_get_execution_handoff_readiness(100) h
where h.request_type = 'smoke_test_execution_handoff'
  and h.title like '[SMOKE] Robot Barát Execution Handoff blocked%'
order by h.approved_at desc nulls last;

do $$
declare
  v_handoff record;
begin
  select h.*
  into v_handoff
  from public.agent_v2_get_execution_handoff_readiness(100) h
  where h.request_type = 'smoke_test_execution_handoff'
    and h.title like '[SMOKE] Robot Barát Execution Handoff blocked%'
  order by h.approved_at desc nulls last
  limit 1;

  if v_handoff.action_request_id is null then
    raise exception 'Blocked execution handoff smoke row was not found.';
  end if;

  if v_handoff.handoff_status not in ('blocked_missing_passed_dry_run', 'blocked_missing_final_confirmation') then
    raise exception 'Expected blocked handoff status, got %.', v_handoff.handoff_status;
  end if;

  if v_handoff.execution_allowed_now is distinct from false then
    raise exception 'Blocked execution_allowed_now must be false, got %.', v_handoff.execution_allowed_now;
  end if;
end $$;
