-- Robot Barát Executor Runtime Guardrails smoke test.
-- Verifies that the runtime guardrail registry is present and execution remains disabled.
-- This smoke test does not execute anything and does not clean up data.

select *
from public.agent_v2_get_executor_runtime_guardrails();

select *
from public.agent_v2_assert_executor_runtime_disabled();

do $$
declare
  v_guardrail record;
  v_assertion record;
  v_executed_count integer;
begin
  select gr.*
  into v_guardrail
  from public.agent_v2_get_executor_runtime_guardrails() gr
  limit 1;

  if v_guardrail.id is null then
    raise exception 'Executor runtime guardrail default row was not found.';
  end if;

  if v_guardrail.guardrail_status <> 'disabled' then
    raise exception 'Expected guardrail_status disabled, got %.', v_guardrail.guardrail_status;
  end if;

  if v_guardrail.runtime_enable_flag is distinct from false then
    raise exception 'runtime_enable_flag must be false, got %.', v_guardrail.runtime_enable_flag;
  end if;

  if v_guardrail.local_agent_execution_enabled is distinct from false then
    raise exception 'local_agent_execution_enabled must be false, got %.', v_guardrail.local_agent_execution_enabled;
  end if;

  if v_guardrail.eh_oif_execution_enabled is distinct from false then
    raise exception 'eh_oif_execution_enabled must be false, got %.', v_guardrail.eh_oif_execution_enabled;
  end if;

  if v_guardrail.notifications_enabled is distinct from false then
    raise exception 'notifications_enabled must be false, got %.', v_guardrail.notifications_enabled;
  end if;

  if v_guardrail.business_data_mutation_enabled is distinct from false then
    raise exception 'business_data_mutation_enabled must be false, got %.', v_guardrail.business_data_mutation_enabled;
  end if;

  if v_guardrail.execution_allowed_now is distinct from false then
    raise exception 'execution_allowed_now must be false, got %.', v_guardrail.execution_allowed_now;
  end if;

  if v_guardrail.safety_policy->>'current_task_allows_execution' <> 'false' then
    raise exception 'safety_policy.current_task_allows_execution must be false.';
  end if;

  select ar.*
  into v_assertion
  from public.agent_v2_assert_executor_runtime_disabled() ar
  limit 1;

  if v_assertion.assertion_status <> 'runtime_disabled_ok' then
    raise exception 'Expected assertion_status runtime_disabled_ok, got %.', v_assertion.assertion_status;
  end if;

  if v_assertion.execution_allowed_now is distinct from false then
    raise exception 'assertion execution_allowed_now must be false, got %.', v_assertion.execution_allowed_now;
  end if;

  if v_assertion.guardrails->>'current_task_allows_execution' <> 'false' then
    raise exception 'assertion guardrails.current_task_allows_execution must be false.';
  end if;

  select count(*)
  into v_executed_count
  from public.agent_action_requests action_request
  where action_request.status = 'executed';

  if v_executed_count <> 0 then
    raise exception 'Executor runtime guardrail smoke found % executed action requests; expected zero.', v_executed_count;
  end if;
end $$;
