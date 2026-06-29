create or replace function public.agent_v2_get_approved_action_queue(
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
  requested_by text,
  created_at timestamptz,
  updated_at timestamptz,
  queue_age_minutes integer,
  executor_status text,
  executor_hint text,
  safety_note text
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
  select
    ar.id,
    ar.request_key,
    ar.request_type,
    ar.status,
    ar.severity,
    ar.title,
    ar.summary,
    ar.recommended_action,
    ar.reason,
    ar.workflow_case_id,
    ar.candidate_id,
    ar.assignment_id,
    ar.alert_event_id,
    ar.payload,
    ar.approved_by,
    ar.approved_at,
    ar.approval_note,
    ar.requested_by,
    ar.created_at,
    ar.updated_at,
    floor(extract(epoch from (now() - coalesce(ar.approved_at, ar.created_at))) / 60)::integer as queue_age_minutes,
    'waiting_for_future_executor'::text as executor_status,
    case
      when ar.request_type = 'case_assistant_recommended_action'
        or ar.source_kind = 'case_assistant'
        or ar.payload->>'source' = 'case_assistant'
        then 'manual_review_or_future_case_agent'
      else 'manual_review_required'
    end::text as executor_hint,
    'Ez a queue csak olvasható. Nem hajt végre local agentet, EH/OIF műveletet vagy értesítést.'::text as safety_note
  from public.agent_action_requests ar
  where ar.status = 'approved'
  order by
    case lower(coalesce(ar.severity, 'info'))
      when 'critical' then 1
      when 'warning' then 2
      when 'info' then 3
      when 'ok' then 4
      else 5
    end,
    ar.approved_at asc nulls last,
    ar.created_at asc
  limit v_limit;
end;
$function$;

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant execute on function public.agent_v2_get_approved_action_queue(integer) to %I', v_role);
    end if;
  end loop;
end $$;
