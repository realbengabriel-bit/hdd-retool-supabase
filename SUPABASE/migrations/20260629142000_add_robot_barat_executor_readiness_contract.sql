create or replace function public.agent_v2_get_executor_readiness_queue(
  p_limit integer default 100
)
returns table (
  id uuid,
  request_key text,
  request_type text,
  status text,
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
  approval_note text,
  created_at timestamptz,
  updated_at timestamptz,
  executor_status text,
  executor_type text,
  executor_route text,
  executor_readiness text,
  missing_executor_fields jsonb,
  available_executor_fields jsonb,
  guardrails jsonb,
  payload_contract jsonb,
  dry_run_required boolean,
  manual_final_confirmation_required boolean,
  execution_allowed_now boolean,
  safety_note text
)
language sql
security invoker
stable
set search_path = public
as $function$
with base as (
  select
    ar.*,
    case
      when ar.request_type = 'case_assistant_recommended_action' then 'case_assistant'
      when left(coalesce(ar.request_type, ''), 3) = 'eh_' or ar.payload->>'executor_route' = 'enterhungary' then 'enterhungary'
      when left(coalesce(ar.request_type, ''), 4) = 'oif_' or ar.payload->>'executor_route' = 'oif' then 'oif'
      when left(coalesce(ar.request_type, ''), 9) = 'document_' then 'documents'
      else 'manual_review'
    end as computed_executor_route,
    case
      when ar.request_type = 'case_assistant_recommended_action' then 'manual_or_future_case_agent'
      when left(coalesce(ar.request_type, ''), 3) = 'eh_' or ar.payload->>'executor_route' = 'enterhungary' then 'future_enterhungary_local_agent'
      when left(coalesce(ar.request_type, ''), 4) = 'oif_' or ar.payload->>'executor_route' = 'oif' then 'future_oif_local_agent'
      when left(coalesce(ar.request_type, ''), 9) = 'document_' then 'future_document_agent'
      else 'manual_review_required'
    end as computed_executor_type
  from public.agent_action_requests ar
  where ar.status = 'approved'
), missing as (
  select
    b.*,
    array_remove(array[
      case when b.computed_executor_route = 'case_assistant' and b.workflow_case_id is null then 'workflow_case_id'::text end,
      case when b.computed_executor_route = 'case_assistant' and nullif(btrim(coalesce(b.title, '')), '') is null then 'title'::text end,
      case when b.computed_executor_route = 'case_assistant' and nullif(btrim(coalesce(b.recommended_action, b.summary, '')), '') is null then 'recommended_action_or_summary'::text end,
      case when b.computed_executor_route in ('enterhungary', 'oif') and b.workflow_case_id is null then 'workflow_case_id'::text end,
      case when b.computed_executor_route in ('enterhungary', 'oif') and coalesce(b.payload, '{}'::jsonb) = '{}'::jsonb then 'payload'::text end,
      case when b.computed_executor_route in ('enterhungary', 'oif') and nullif(btrim(coalesce(b.requested_by, b.approved_by, '')), '') is null then 'requested_by_or_approved_by'::text end,
      case when b.computed_executor_route = 'documents' and b.workflow_case_id is null and b.candidate_id is null and b.assignment_id is null then 'workflow_case_id_or_candidate_id_or_assignment_id'::text end,
      case when b.computed_executor_route = 'documents' and nullif(btrim(coalesce(b.recommended_action, b.summary, '')), '') is null then 'recommended_action_or_summary'::text end
    ], null) as missing_fields
  from base b
), contracted as (
  select
    m.*,
    jsonb_build_object(
      'has_workflow_case_id', m.workflow_case_id is not null,
      'has_candidate_id', m.candidate_id is not null,
      'has_assignment_id', m.assignment_id is not null,
      'has_alert_event_id', m.alert_event_id is not null,
      'has_payload', coalesce(m.payload, '{}'::jsonb) <> '{}'::jsonb,
      'has_title', nullif(btrim(coalesce(m.title, '')), '') is not null,
      'has_summary', nullif(btrim(coalesce(m.summary, '')), '') is not null,
      'has_recommended_action', nullif(btrim(coalesce(m.recommended_action, '')), '') is not null,
      'has_reason', nullif(btrim(coalesce(m.reason, '')), '') is not null,
      'has_approved_by', nullif(btrim(coalesce(m.approved_by, '')), '') is not null,
      'has_approval_note', nullif(btrim(coalesce(m.approval_note, '')), '') is not null
    ) as computed_available_executor_fields,
    jsonb_build_object(
      'read_only_contract', true,
      'execution_allowed_now', false,
      'dry_run_required', true,
      'manual_final_confirmation_required', true,
      'no_local_agent_execution', true,
      'no_eh_oif_execution', true,
      'no_notifications', true,
      'no_business_data_mutation', true,
      'allowed_current_use', 'review_and_contract_validation_only'
    ) as computed_guardrails
  from missing m
)
select
  c.id,
  c.request_key,
  c.request_type,
  c.status,
  c.severity,
  c.title,
  c.summary,
  c.recommended_action,
  c.reason,
  c.workflow_case_id,
  c.candidate_id,
  c.assignment_id,
  c.alert_event_id,
  c.payload,
  c.approved_by,
  c.approved_at,
  c.approval_note,
  c.created_at,
  c.updated_at,
  'waiting_for_future_executor'::text as executor_status,
  c.computed_executor_type::text as executor_type,
  c.computed_executor_route::text as executor_route,
  case
    when c.computed_executor_route = 'manual_review' then 'manual_review_required'
    when c.workflow_case_id is null and c.candidate_id is null and c.assignment_id is null then 'not_ready_missing_context'
    when cardinality(c.missing_fields) = 0 then 'ready_for_future_dry_run'
    else 'not_ready_missing_context'
  end::text as executor_readiness,
  to_jsonb(c.missing_fields) as missing_executor_fields,
  c.computed_available_executor_fields as available_executor_fields,
  c.computed_guardrails as guardrails,
  jsonb_build_object(
    'schema_version', 'robot_barat_executor_contract_v1',
    'expected_executor_type', c.computed_executor_type,
    'expected_executor_route', c.computed_executor_route,
    'source_request_type', c.request_type,
    'payload', c.payload,
    'required_before_execution', to_jsonb(c.missing_fields),
    'future_executor_must_write_back', jsonb_build_array(
      'dry_run_result',
      'operator_final_confirmation',
      'execution_started_at',
      'execution_finished_at',
      'execution_status',
      'execution_log_reference'
    )
  ) as payload_contract,
  true as dry_run_required,
  true as manual_final_confirmation_required,
  false as execution_allowed_now,
  'Ez csak executor readiness contract. Nem hajt végre local agentet, EH/OIF műveletet vagy értesítést.'::text as safety_note
from contracted c
order by
  case lower(coalesce(c.severity, 'info'))
    when 'critical' then 1
    when 'warning' then 2
    when 'info' then 3
    when 'ok' then 4
    else 5
  end,
  c.approved_at asc nulls last,
  c.created_at asc
limit least(greatest(coalesce(p_limit, 100), 1), 200);
$function$;

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant execute on function public.agent_v2_get_executor_readiness_queue(integer) to %I', v_role);
    end if;
  end loop;
end $$;
