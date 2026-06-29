-- Robot Barát Final Confirmation Gate smoke test.
-- Creates an approved action request, records a passed dry run, confirms final gate,
-- and verifies guardrails. This does not execute anything.

with created as (
  select *
  from public.agent_v2_create_action_request(
    'smoke_test_final_confirmation',
    '[SMOKE] Robot Barát Final Confirmation Gate ' || to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS.MS'),
    'Smoke test row for Robot Barát final confirmation gate.',
    'Verify final confirmation gate after a passed dry run.',
    'Manual smoke test for final confirmation gate.',
    'info',
    'smoke_test',
    'robot_barat_final_confirmation_gate',
    null,
    null,
    null,
    null,
    jsonb_build_object(
      'smoke_test', 'robot_barat_final_confirmation_gate',
      'nonce', gen_random_uuid()::text,
      'safety', 'final_confirmation_only_no_executor'
    ),
    'manual-smoke-test'
  )
), approved as (
  select approved_row.*
  from created c
  cross join lateral public.agent_v2_approve_action_request(
    c.id,
    'manual-smoke-test',
    'Smoke approval for Robot Barát final confirmation gate test.'
  ) approved_row
)
select *
from approved;

with picked as (
  select ar.id
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_final_confirmation'
    and ar.title like '[SMOKE]%'
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
    jsonb_build_object('input', 'smoke'),
    jsonb_build_object('validated', true),
    jsonb_build_object('preview', 'ok'),
    '[]'::jsonb,
    jsonb_build_array('Smoke warning: this is final-confirmation test data.'),
    '[]'::jsonb,
    jsonb_build_object('smoke_safety_check', true),
    true,
    'manual-smoke-test',
    'Smoke passed dry-run for final confirmation gate.'
  ) dr
)
select *
from passed_dry_run;

select *
from public.agent_v2_get_final_confirmation_gate(100) g
where g.request_type = 'smoke_test_final_confirmation'
  and g.action_title like '[SMOKE]%'
order by g.approved_at desc nulls last;

do $$
declare
  v_gate record;
begin
  select g.*
  into v_gate
  from public.agent_v2_get_final_confirmation_gate(100) g
  where g.request_type = 'smoke_test_final_confirmation'
    and g.action_title like '[SMOKE]%'
  order by g.approved_at desc nulls last
  limit 1;

  if v_gate.action_request_id is null then
    raise exception 'Final confirmation smoke gate row was not found.';
  end if;

  if v_gate.final_gate_status <> 'ready_for_final_confirmation' then
    raise exception 'Expected final_gate_status ready_for_final_confirmation before confirmation, got %.', v_gate.final_gate_status;
  end if;

  begin
    perform *
    from public.agent_v2_confirm_final_action_request(
      v_gate.action_request_id,
      v_gate.dry_run_id,
      'manual-smoke-test-negative',
      'This negative smoke confirmation should fail because acknowledgements are false.',
      false,
      false,
      true
    );
    raise exception 'Final confirmation without required acknowledgements unexpectedly succeeded.';
  exception
    when sqlstate '22023' then
      null;
  end;
end $$;

with gate as (
  select g.*
  from public.agent_v2_get_final_confirmation_gate(100) g
  where g.request_type = 'smoke_test_final_confirmation'
    and g.action_title like '[SMOKE]%'
  order by g.approved_at desc nulls last
  limit 1
), confirmed as (
  select fc.*
  from gate g
  cross join lateral public.agent_v2_confirm_final_action_request(
    g.action_request_id,
    g.dry_run_id,
    'manual-smoke-test',
    'Smoke final confirmation. This does not execute anything.',
    true,
    true,
    true
  ) fc
)
select *
from confirmed;

select *
from public.agent_v2_get_final_confirmation_gate(100) g
where g.request_type = 'smoke_test_final_confirmation'
  and g.action_title like '[SMOKE]%'
order by g.confirmed_at desc nulls last, g.approved_at desc nulls last;

do $$
declare
  v_gate record;
  v_confirmation record;
  v_executed_count integer;
begin
  select g.*
  into v_gate
  from public.agent_v2_get_final_confirmation_gate(100) g
  where g.request_type = 'smoke_test_final_confirmation'
    and g.action_title like '[SMOKE]%'
  order by g.confirmed_at desc nulls last, g.approved_at desc nulls last
  limit 1;

  if v_gate.final_gate_status <> 'final_confirmation_recorded' then
    raise exception 'Expected final_gate_status final_confirmation_recorded after confirmation, got %.', v_gate.final_gate_status;
  end if;

  if v_gate.execution_allowed_now is distinct from false then
    raise exception 'Final gate execution_allowed_now must be false, got %.', v_gate.execution_allowed_now;
  end if;

  select fc.*
  into v_confirmation
  from public.agent_action_final_confirmations fc
  where fc.id = v_gate.latest_confirmation_id;

  if v_confirmation.safety_snapshot->>'no_local_agent_execution' <> 'true' then
    raise exception 'Final confirmation safety_snapshot.no_local_agent_execution must be true.';
  end if;

  if v_confirmation.safety_snapshot->>'no_eh_oif_execution' <> 'true' then
    raise exception 'Final confirmation safety_snapshot.no_eh_oif_execution must be true.';
  end if;

  if v_confirmation.safety_snapshot->>'no_notifications' <> 'true' then
    raise exception 'Final confirmation safety_snapshot.no_notifications must be true.';
  end if;

  select count(*)
  into v_executed_count
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_final_confirmation'
    and ar.title like '[SMOKE]%'
    and ar.status = 'executed';

  if v_executed_count <> 0 then
    raise exception 'Final confirmation smoke found % executed smoke action requests; expected zero.', v_executed_count;
  end if;
end $$;
