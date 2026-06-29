-- Robot Barát Dry Run Result smoke test.
-- Creates and approves a clearly marked smoke action request, records passed and blocked dry-runs,
-- and verifies safety constraints. This does not execute anything.

with created as (
  select *
  from public.agent_v2_create_action_request(
    'smoke_test_dry_run',
    '[SMOKE] Robot Barát Dry Run Results ' || to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS.MS'),
    'Smoke test row for Robot Barát dry-run results.',
    'Verify that dry-run results can be recorded without execution.',
    'Manual smoke test for dry-run result lifecycle.',
    'info',
    'smoke_test',
    'robot_barat_dry_run_results',
    null,
    null,
    null,
    null,
    jsonb_build_object(
      'smoke_test', 'robot_barat_dry_run_results',
      'nonce', gen_random_uuid()::text,
      'safety', 'dry_run_only_no_executor'
    ),
    'manual-smoke-test'
  )
), approved as (
  select approved_row.*
  from created c
  cross join lateral public.agent_v2_approve_action_request(
    c.id,
    'manual-smoke-test',
    'Smoke approval for Robot Barát dry-run result test.'
  ) approved_row
)
select *
from approved;

with picked as (
  select ar.id
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_dry_run'
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
    jsonb_build_array('Smoke warning: this is a dry-run only.'),
    '[]'::jsonb,
    jsonb_build_object('smoke_safety_check', true),
    true,
    'manual-smoke-test',
    'Smoke passed dry-run result.'
  ) dr
)
select *
from passed_dry_run;

with picked as (
  select ar.id
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_dry_run'
    and ar.title like '[SMOKE]%'
  order by ar.created_at desc
  limit 1
), blocked_dry_run as (
  select dr.*
  from picked p
  cross join lateral public.agent_v2_record_dry_run_result(
    p.id,
    'blocked',
    'smoke_future_executor',
    'smoke',
    jsonb_build_object('input', 'smoke-blocked'),
    '{}'::jsonb,
    jsonb_build_object('preview', 'blocked'),
    jsonb_build_array('Blocked smoke validation error.'),
    jsonb_build_array('Smoke blocked warning.'),
    jsonb_build_array('smoke_missing_field'),
    jsonb_build_object('smoke_safety_check', true),
    true,
    'manual-smoke-test',
    'Smoke blocked dry-run result. can_proceed must be forced false.'
  ) dr
)
select *
from blocked_dry_run;

select dr.*
from public.agent_v2_get_dry_run_results(null, 100) dr
join public.agent_action_requests ar on ar.id = dr.action_request_id
where ar.request_type = 'smoke_test_dry_run'
  and ar.title like '[SMOKE]%'
order by dr.created_at desc;

do $$
declare
  v_request_id uuid;
  v_passed record;
  v_blocked record;
  v_executed_count integer;
begin
  select ar.id
  into v_request_id
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_dry_run'
    and ar.title like '[SMOKE]%'
  order by ar.created_at desc
  limit 1;

  if v_request_id is null then
    raise exception 'Dry-run smoke action request was not found.';
  end if;

  select dr.*
  into v_passed
  from public.agent_v2_get_dry_run_results(v_request_id, 100) dr
  where dr.dry_run_status = 'passed'
  order by dr.created_at desc
  limit 1;

  if v_passed.id is null then
    raise exception 'Passed dry-run smoke row was not found.';
  end if;

  if v_passed.execution_allowed_now is distinct from false then
    raise exception 'Passed dry-run execution_allowed_now must be false, got %.', v_passed.execution_allowed_now;
  end if;

  if v_passed.can_proceed_to_final_confirmation is distinct from true then
    raise exception 'Passed dry-run can_proceed_to_final_confirmation must be true, got %.', v_passed.can_proceed_to_final_confirmation;
  end if;

  if v_passed.safety_checks->>'no_local_agent_execution' <> 'true' then
    raise exception 'Passed dry-run safety_checks.no_local_agent_execution must be true.';
  end if;

  if v_passed.safety_checks->>'no_eh_oif_execution' <> 'true' then
    raise exception 'Passed dry-run safety_checks.no_eh_oif_execution must be true.';
  end if;

  if v_passed.safety_checks->>'no_notifications' <> 'true' then
    raise exception 'Passed dry-run safety_checks.no_notifications must be true.';
  end if;

  select dr.*
  into v_blocked
  from public.agent_v2_get_dry_run_results(v_request_id, 100) dr
  where dr.dry_run_status = 'blocked'
  order by dr.created_at desc
  limit 1;

  if v_blocked.id is null then
    raise exception 'Blocked dry-run smoke row was not found.';
  end if;

  if v_blocked.can_proceed_to_final_confirmation is distinct from false then
    raise exception 'Blocked dry-run can_proceed_to_final_confirmation must be forced false, got %.', v_blocked.can_proceed_to_final_confirmation;
  end if;

  select count(*)
  into v_executed_count
  from public.agent_action_requests ar
  where ar.request_type = 'smoke_test_dry_run'
    and ar.title like '[SMOKE]%'
    and ar.status = 'executed';

  if v_executed_count <> 0 then
    raise exception 'Dry-run smoke found % executed smoke action requests; expected zero.', v_executed_count;
  end if;
end $$;
