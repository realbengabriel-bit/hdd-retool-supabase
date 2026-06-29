create or replace function public.agent_v2_get_execution_handoff_readiness(
  p_limit integer default 100
)
returns table (
  action_request_id uuid,
  request_key text,
  request_type text,
  severity text,
  title text,
  summary text,
  recommended_action text,
  reason text,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  alert_event_id uuid,
  payload jsonb,
  approved_by text,
  approved_at timestamptz,
  dry_run_id uuid,
  dry_run_status text,
  dry_run_finished_at timestamptz,
  dry_run_preview_result jsonb,
  dry_run_validation_errors jsonb,
  dry_run_warnings jsonb,
  can_proceed_to_final_confirmation boolean,
  final_confirmation_id uuid,
  confirmation_status text,
  confirmed_by text,
  confirmed_at timestamptz,
  confirmation_note text,
  handoff_status text,
  handoff_blockers jsonb,
  executor_type text,
  executor_route text,
  execution_allowed_now boolean,
  dry_run_required boolean,
  manual_final_confirmation_required boolean,
  future_executor_contract jsonb,
  safety_note text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 200);
begin
  return query
  with base_rows as (
    select
      ar.id as action_request_id,
      ar.request_key,
      ar.request_type,
      ar.status as action_status,
      ar.severity,
      ar.title,
      ar.summary,
      ar.recommended_action,
      ar.reason,
      ar.workflow_case_id,
      ar.candidate_id,
      ar.assignment_id,
      ar.alert_event_id,
      coalesce(ar.payload, '{}'::jsonb) as payload,
      ar.approved_by,
      ar.approved_at,
      ar.created_at,
      ar.updated_at,
      dr.id as dry_run_id,
      dr.dry_run_status,
      dr.dry_run_finished_at,
      coalesce(dr.preview_result, '{}'::jsonb) as dry_run_preview_result,
      coalesce(dr.validation_errors, '[]'::jsonb) as dry_run_validation_errors,
      coalesce(dr.warnings, '[]'::jsonb) as dry_run_warnings,
      coalesce(dr.can_proceed_to_final_confirmation, false) as can_proceed_to_final_confirmation,
      coalesce(dr.execution_allowed_now, false) as dry_run_execution_allowed_now,
      fc.id as final_confirmation_id,
      fc.confirmation_status,
      fc.confirmed_by,
      fc.confirmed_at,
      fc.confirmation_note,
      coalesce(fc.execution_allowed_now, false) as final_confirmation_execution_allowed_now
    from public.agent_action_requests ar
    left join lateral (
      select dr1.*
      from public.agent_action_dry_runs dr1
      where dr1.action_request_id = ar.id
      order by coalesce(dr1.dry_run_finished_at, dr1.created_at) desc, dr1.created_at desc
      limit 1
    ) dr on true
    left join lateral (
      select fc1.*
      from public.agent_action_final_confirmations fc1
      where fc1.action_request_id = ar.id
      order by coalesce(fc1.confirmed_at, fc1.created_at) desc, fc1.created_at desc
      limit 1
    ) fc on true
    where ar.status = 'approved'
  ), classified as (
    select
      b.*,
      case
        when lower(coalesce(b.request_type, '')) = 'case_assistant_recommended_action'
          then 'manual_or_future_case_agent'::text
        when left(lower(coalesce(b.request_type, '')), 3) = 'eh_'
          or lower(coalesce(b.payload->>'executor_route', '')) = 'enterhungary'
          then 'future_enterhungary_local_agent'::text
        when left(lower(coalesce(b.request_type, '')), 4) = 'oif_'
          or lower(coalesce(b.payload->>'executor_route', '')) = 'oif'
          then 'future_oif_local_agent'::text
        when left(lower(coalesce(b.request_type, '')), 9) = 'document_'
          then 'future_document_agent'::text
        else 'manual_review_required'::text
      end as mapped_executor_type,
      case
        when lower(coalesce(b.request_type, '')) = 'case_assistant_recommended_action'
          then 'case_assistant'::text
        when left(lower(coalesce(b.request_type, '')), 3) = 'eh_'
          or lower(coalesce(b.payload->>'executor_route', '')) = 'enterhungary'
          then 'enterhungary'::text
        when left(lower(coalesce(b.request_type, '')), 4) = 'oif_'
          or lower(coalesce(b.payload->>'executor_route', '')) = 'oif'
          then 'oif'::text
        when left(lower(coalesce(b.request_type, '')), 9) = 'document_'
          then 'documents'::text
        else 'manual_review'::text
      end as mapped_executor_route,
      (
        b.dry_run_id is not null
        and b.dry_run_status = 'passed'
        and b.can_proceed_to_final_confirmation is true
        and b.dry_run_execution_allowed_now is false
      ) as has_passed_dry_run,
      (
        b.final_confirmation_id is not null
        and b.confirmation_status = 'confirmed'
        and b.final_confirmation_execution_allowed_now is false
      ) as has_confirmed_final_confirmation
    from base_rows b
  ), blocked as (
    select
      c.*,
      array_remove(array[
        case when c.action_status <> 'approved' then 'action_request_not_approved'::text end,
        case when c.has_passed_dry_run is not true then 'missing_passed_dry_run'::text end,
        case when c.has_confirmed_final_confirmation is not true then 'missing_final_confirmation'::text end,
        case when c.dry_run_execution_allowed_now is true then 'dry_run_execution_allowed_now_true'::text end,
        case when c.final_confirmation_execution_allowed_now is true then 'final_confirmation_execution_allowed_now_true'::text end,
        case
          when c.action_status = 'approved'
            and c.has_passed_dry_run is true
            and c.has_confirmed_final_confirmation is true
            and (c.dry_run_execution_allowed_now is true or c.final_confirmation_execution_allowed_now is true)
            then 'unknown_guardrail_issue'::text
        end
      ], null::text) as blocker_codes
    from classified c
  ), statused as (
    select
      bl.*,
      case
        when bl.dry_run_execution_allowed_now is true
          or bl.final_confirmation_execution_allowed_now is true
          then 'blocked_guardrail_violation'::text
        when bl.has_passed_dry_run is not true
          then 'blocked_missing_passed_dry_run'::text
        when bl.has_confirmed_final_confirmation is not true
          then 'blocked_missing_final_confirmation'::text
        when bl.action_status = 'approved'
          and bl.has_passed_dry_run is true
          and bl.has_confirmed_final_confirmation is true
          then 'ready'::text
        else 'blocked_unknown'::text
      end as computed_handoff_status,
      to_jsonb(bl.blocker_codes) as computed_handoff_blockers
    from blocked bl
  )
  select
    s.action_request_id,
    s.request_key,
    s.request_type,
    s.severity,
    s.title,
    s.summary,
    s.recommended_action,
    s.reason,
    s.workflow_case_id,
    s.candidate_id,
    s.assignment_id,
    s.alert_event_id,
    s.payload,
    s.approved_by,
    s.approved_at,
    s.dry_run_id,
    s.dry_run_status,
    s.dry_run_finished_at,
    s.dry_run_preview_result,
    s.dry_run_validation_errors,
    s.dry_run_warnings,
    s.can_proceed_to_final_confirmation,
    s.final_confirmation_id,
    s.confirmation_status,
    s.confirmed_by,
    s.confirmed_at,
    s.confirmation_note,
    s.computed_handoff_status as handoff_status,
    s.computed_handoff_blockers as handoff_blockers,
    s.mapped_executor_type as executor_type,
    s.mapped_executor_route as executor_route,
    false as execution_allowed_now,
    true as dry_run_required,
    true as manual_final_confirmation_required,
    jsonb_build_object(
      'schema', 'robot_barat_execution_handoff_v1',
      'handoff_status', s.computed_handoff_status,
      'execution_allowed_now', false,
      'dry_run_required', true,
      'manual_final_confirmation_required', true,
      'executor_type', s.mapped_executor_type,
      'executor_route', s.mapped_executor_route,
      'action_request_id', s.action_request_id,
      'dry_run_id', s.dry_run_id,
      'final_confirmation_id', s.final_confirmation_id,
      'payload', s.payload,
      'dry_run_preview_result', s.dry_run_preview_result,
      'handoff_blockers', s.computed_handoff_blockers,
      'future_executor_must_still_require', jsonb_build_array(
        'explicit_runtime_enable_flag',
        'fresh_guardrail_check',
        'operator_session_identity',
        'execution_dry_run_revalidation',
        'audit_log_destination'
      ),
      'current_task_allows_execution', false
    ) as future_executor_contract,
    'Ez csak execution handoff readiness nézet. Nem hajt végre local agentet, EH/OIF műveletet vagy értesítést.'::text as safety_note,
    s.created_at,
    s.updated_at
  from statused s
  order by
    case s.computed_handoff_status
      when 'ready' then 1
      when 'blocked_guardrail_violation' then 2
      when 'blocked_missing_passed_dry_run' then 3
      when 'blocked_missing_final_confirmation' then 4
      else 5
    end,
    case lower(coalesce(s.severity, 'info'))
      when 'critical' then 1
      when 'warning' then 2
      when 'info' then 3
      when 'ok' then 4
      else 5
    end,
    coalesce(s.approved_at, s.created_at) asc,
    s.title asc
  limit v_limit;
end;
$function$;

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant execute on function public.agent_v2_get_execution_handoff_readiness(integer) to %I', v_role);
    end if;
  end loop;
end $$;
