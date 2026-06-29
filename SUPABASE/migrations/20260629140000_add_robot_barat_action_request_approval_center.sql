-- HDD / UAHUN Robot Barat Action Request Approval Center
-- Human approval layer only. No executor and no external side effects.

create extension if not exists pgcrypto;

create table if not exists public.agent_action_requests (
  id uuid primary key default gen_random_uuid(),
  request_key text unique,
  request_type text not null,
  status text not null default 'draft',
  severity text not null default 'info',
  title text not null,
  summary text,
  recommended_action text,
  reason text,
  source_kind text,
  source_id text,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  alert_event_id uuid,
  payload jsonb not null default '{}'::jsonb,
  proposed_by text,
  requested_by text,
  approved_by text,
  rejected_by text,
  needs_clarification_by text,
  approved_at timestamptz,
  rejected_at timestamptz,
  needs_clarification_at timestamptz,
  approval_note text,
  rejection_reason text,
  clarification_question text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Legacy compatibility: older approval tables may already exist with a required kind column.
alter table public.agent_action_requests
  add column if not exists kind text;

alter table public.agent_action_requests
  alter column kind set default 'action_request';

update public.agent_action_requests
set kind = 'action_request'
where kind is null
   or btrim(kind) = '';

alter table public.agent_action_requests
  alter column kind set not null;

-- Legacy compatibility: replace older status constraints that did not allow pending_approval.
alter table public.agent_action_requests
  drop constraint if exists agent_action_requests_status_check;

update public.agent_action_requests
set status = case
  when status is null or btrim(status) = '' then 'draft'
  when lower(status) in (
    'draft',
    'pending_approval',
    'approved',
    'rejected',
    'needs_clarification',
    'cancelled',
    'executed',
    'failed'
  ) then lower(status)
  when lower(status) in ('pending', 'pending_approval_required', 'waiting_for_approval') then 'pending_approval'
  when lower(status) in ('clarification', 'clarification_needed', 'needs_info') then 'needs_clarification'
  when lower(status) in ('declined', 'denied') then 'rejected'
  else 'draft'
end;

alter table public.agent_action_requests
  add constraint agent_action_requests_status_check
  check (
    status in (
      'draft',
      'pending_approval',
      'approved',
      'rejected',
      'needs_clarification',
      'cancelled',
      'executed',
      'failed'
    )
  );

create index if not exists idx_agent_action_requests_status
  on public.agent_action_requests (status);

create index if not exists idx_agent_action_requests_severity
  on public.agent_action_requests (severity);

create index if not exists idx_agent_action_requests_request_type
  on public.agent_action_requests (request_type);

create index if not exists idx_agent_action_requests_workflow_case_id
  on public.agent_action_requests (workflow_case_id);

create index if not exists idx_agent_action_requests_candidate_id
  on public.agent_action_requests (candidate_id);

create index if not exists idx_agent_action_requests_assignment_id
  on public.agent_action_requests (assignment_id);

create index if not exists idx_agent_action_requests_alert_event_id
  on public.agent_action_requests (alert_event_id);

create index if not exists idx_agent_action_requests_created_at_desc
  on public.agent_action_requests (created_at desc);

create or replace function public.fn_agent_action_requests_set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.agent_action_requests'::regclass
      and tgname = 'trg_agent_action_requests_set_updated_at'
  ) then
    execute 'create trigger trg_agent_action_requests_set_updated_at before update on public.agent_action_requests for each row execute function public.fn_agent_action_requests_set_updated_at()';
  end if;
end $$;

create or replace function public.agent_v2_get_action_requests(
  p_status text default null,
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
  source_kind text,
  source_id text,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  alert_event_id uuid,
  payload jsonb,
  proposed_by text,
  requested_by text,
  approved_by text,
  rejected_by text,
  needs_clarification_by text,
  approved_at timestamptz,
  rejected_at timestamptz,
  needs_clarification_at timestamptz,
  approval_note text,
  rejection_reason text,
  clarification_question text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
declare
  v_status text := nullif(lower(btrim(p_status)), '');
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
    ar.source_kind,
    ar.source_id,
    ar.workflow_case_id,
    ar.candidate_id,
    ar.assignment_id,
    ar.alert_event_id,
    ar.payload,
    ar.proposed_by,
    ar.requested_by,
    ar.approved_by,
    ar.rejected_by,
    ar.needs_clarification_by,
    ar.approved_at,
    ar.rejected_at,
    ar.needs_clarification_at,
    ar.approval_note,
    ar.rejection_reason,
    ar.clarification_question,
    ar.created_at,
    ar.updated_at
  from public.agent_action_requests ar
  where v_status is null
     or v_status = 'all'
     or lower(ar.status) = v_status
  order by
    case lower(ar.severity)
      when 'critical' then 1
      when 'blocker' then 1
      when 'urgent' then 2
      when 'warning' then 3
      when 'info' then 4
      else 5
    end,
    case lower(ar.status)
      when 'pending_approval' then 1
      when 'needs_clarification' then 2
      when 'draft' then 3
      when 'approved' then 4
      when 'rejected' then 5
      when 'cancelled' then 6
      when 'failed' then 7
      when 'executed' then 8
      else 9
    end,
    ar.created_at desc
  limit v_limit;
end;
$function$;

create or replace function public.agent_v2_create_action_request(
  p_request_type text,
  p_title text,
  p_summary text default null,
  p_recommended_action text default null,
  p_reason text default null,
  p_severity text default 'info',
  p_source_kind text default null,
  p_source_id text default null,
  p_workflow_case_id uuid default null,
  p_candidate_id uuid default null,
  p_assignment_id uuid default null,
  p_alert_event_id uuid default null,
  p_payload jsonb default '{}'::jsonb,
  p_requested_by text default null
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
  source_kind text,
  source_id text,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  alert_event_id uuid,
  payload jsonb,
  proposed_by text,
  requested_by text,
  approved_by text,
  rejected_by text,
  needs_clarification_by text,
  approved_at timestamptz,
  rejected_at timestamptz,
  needs_clarification_at timestamptz,
  approval_note text,
  rejection_reason text,
  clarification_question text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
volatile
set search_path = public
as $function$
declare
  v_request_type text := nullif(btrim(p_request_type), '');
  v_title text := nullif(btrim(p_title), '');
  v_severity text := lower(coalesce(nullif(btrim(p_severity), ''), 'info'));
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_request_key text;
  v_existing_id uuid;
  v_id uuid;
begin
  if v_request_type is null then
    raise exception 'Action request type is required.' using errcode = '22023';
  end if;

  if v_title is null then
    raise exception 'Action request title is required.' using errcode = '22023';
  end if;

  v_request_key := 'agent_action_request:'
    || regexp_replace(lower(v_request_type), '[^a-z0-9]+', '_', 'g')
    || ':'
    || md5(concat_ws('|',
      v_request_type,
      coalesce(p_source_kind, ''),
      coalesce(p_source_id, ''),
      coalesce(p_workflow_case_id::text, ''),
      coalesce(p_candidate_id::text, ''),
      coalesce(p_assignment_id::text, ''),
      coalesce(p_alert_event_id::text, ''),
      v_payload::text
    ));

  select ar.id
  into v_existing_id
  from public.agent_action_requests ar
  where ar.request_key = v_request_key
  limit 1;

  if v_existing_id is not null then
    return query
    select *
    from public.agent_v2_get_action_requests('all', 200) gar
    where gar.id = v_existing_id;
    return;
  end if;

  insert into public.agent_action_requests as ar (
    kind,
    request_key,
    request_type,
    status,
    severity,
    title,
    summary,
    recommended_action,
    reason,
    source_kind,
    source_id,
    workflow_case_id,
    candidate_id,
    assignment_id,
    alert_event_id,
    payload,
    proposed_by,
    requested_by
  ) values (
    'action_request',
    v_request_key,
    v_request_type,
    'pending_approval',
    v_severity,
    v_title,
    nullif(btrim(p_summary), ''),
    nullif(btrim(p_recommended_action), ''),
    nullif(btrim(p_reason), ''),
    nullif(btrim(p_source_kind), ''),
    nullif(btrim(p_source_id), ''),
    p_workflow_case_id,
    p_candidate_id,
    p_assignment_id,
    p_alert_event_id,
    v_payload,
    p_requested_by,
    p_requested_by
  )
  returning ar.id into v_id;

  return query
  select *
  from public.agent_v2_get_action_requests('all', 200) gar
  where gar.id = v_id;
end;
$function$;

create or replace function public.agent_v2_approve_action_request(
  p_action_request_id uuid,
  p_approved_by text default null,
  p_note text default null
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
  source_kind text,
  source_id text,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  alert_event_id uuid,
  payload jsonb,
  proposed_by text,
  requested_by text,
  approved_by text,
  rejected_by text,
  needs_clarification_by text,
  approved_at timestamptz,
  rejected_at timestamptz,
  needs_clarification_at timestamptz,
  approval_note text,
  rejection_reason text,
  clarification_question text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
volatile
set search_path = public
as $function$
declare
  v_status text;
begin
  select ar.status
  into v_status
  from public.agent_action_requests ar
  where ar.id = p_action_request_id
  for update;

  if v_status is null then
    raise exception 'Action request % was not found.', p_action_request_id using errcode = 'P0002';
  end if;

  if v_status not in ('pending_approval', 'needs_clarification') then
    raise exception 'Cannot approve action request % from status %.', p_action_request_id, v_status using errcode = '22023';
  end if;

  update public.agent_action_requests ar
  set status = 'approved',
      approved_by = nullif(btrim(p_approved_by), ''),
      approved_at = now(),
      approval_note = nullif(btrim(p_note), '')
  where ar.id = p_action_request_id;

  return query
  select *
  from public.agent_v2_get_action_requests('all', 200) gar
  where gar.id = p_action_request_id;
end;
$function$;

create or replace function public.agent_v2_reject_action_request(
  p_action_request_id uuid,
  p_rejected_by text default null,
  p_reason text default null
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
  source_kind text,
  source_id text,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  alert_event_id uuid,
  payload jsonb,
  proposed_by text,
  requested_by text,
  approved_by text,
  rejected_by text,
  needs_clarification_by text,
  approved_at timestamptz,
  rejected_at timestamptz,
  needs_clarification_at timestamptz,
  approval_note text,
  rejection_reason text,
  clarification_question text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
volatile
set search_path = public
as $function$
declare
  v_status text;
begin
  select ar.status
  into v_status
  from public.agent_action_requests ar
  where ar.id = p_action_request_id
  for update;

  if v_status is null then
    raise exception 'Action request % was not found.', p_action_request_id using errcode = 'P0002';
  end if;

  if v_status not in ('pending_approval', 'needs_clarification') then
    raise exception 'Cannot reject action request % from status %.', p_action_request_id, v_status using errcode = '22023';
  end if;

  update public.agent_action_requests ar
  set status = 'rejected',
      rejected_by = nullif(btrim(p_rejected_by), ''),
      rejected_at = now(),
      rejection_reason = nullif(btrim(p_reason), '')
  where ar.id = p_action_request_id;

  return query
  select *
  from public.agent_v2_get_action_requests('all', 200) gar
  where gar.id = p_action_request_id;
end;
$function$;

create or replace function public.agent_v2_request_action_clarification(
  p_action_request_id uuid,
  p_requested_by text default null,
  p_question text default null
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
  source_kind text,
  source_id text,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  alert_event_id uuid,
  payload jsonb,
  proposed_by text,
  requested_by text,
  approved_by text,
  rejected_by text,
  needs_clarification_by text,
  approved_at timestamptz,
  rejected_at timestamptz,
  needs_clarification_at timestamptz,
  approval_note text,
  rejection_reason text,
  clarification_question text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
volatile
set search_path = public
as $function$
declare
  v_status text;
begin
  select ar.status
  into v_status
  from public.agent_action_requests ar
  where ar.id = p_action_request_id
  for update;

  if v_status is null then
    raise exception 'Action request % was not found.', p_action_request_id using errcode = 'P0002';
  end if;

  if v_status <> 'pending_approval' then
    raise exception 'Cannot request clarification for action request % from status %.', p_action_request_id, v_status using errcode = '22023';
  end if;

  update public.agent_action_requests ar
  set status = 'needs_clarification',
      needs_clarification_by = nullif(btrim(p_requested_by), ''),
      needs_clarification_at = now(),
      clarification_question = nullif(btrim(p_question), '')
  where ar.id = p_action_request_id;

  return query
  select *
  from public.agent_v2_get_action_requests('all', 200) gar
  where gar.id = p_action_request_id;
end;
$function$;

create or replace function public.agent_v2_create_action_request_from_alert(
  p_alert_event_id uuid,
  p_requested_by text default null
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
  source_kind text,
  source_id text,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  alert_event_id uuid,
  payload jsonb,
  proposed_by text,
  requested_by text,
  approved_by text,
  rejected_by text,
  needs_clarification_by text,
  approved_at timestamptz,
  rejected_at timestamptz,
  needs_clarification_at timestamptz,
  approval_note text,
  rejection_reason text,
  clarification_question text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
volatile
set search_path = public
as $function$
declare
  v_alert jsonb;
  v_payload jsonb;
  v_title text;
  v_summary text;
  v_action text;
  v_reason text;
  v_severity text;
begin
  select to_jsonb(a)
  into v_alert
  from public.agent_alert_events a
  where a.id = p_alert_event_id;

  if v_alert is null then
    raise exception 'Alert event % was not found.', p_alert_event_id using errcode = 'P0002';
  end if;

  v_payload := jsonb_build_object(
    'source', 'agent_alert_events',
    'alert_event', v_alert
  );

  v_title := coalesce(v_alert->>'title', v_alert->>'alert_title', v_alert->>'alert_key', 'Robot Barát jelzés');
  v_summary := coalesce(v_alert->>'message', v_alert->>'summary', v_alert->'payload'->>'summary');
  v_action := coalesce(
    v_alert->'payload'->>'recommended_action',
    v_alert->'payload'->>'action',
    v_alert->>'recommended_action',
    'Emberi jóváhagyás után döntsd el a következő lépést.'
  );
  v_reason := concat_ws(' ', 'Robot Barát jelzés alapján.', v_alert->>'category', v_alert->>'severity');
  v_severity := coalesce(v_alert->>'severity', 'info');

  return query
  select *
  from public.agent_v2_create_action_request(
    'alert_event_recommended_action',
    v_title,
    v_summary,
    v_action,
    v_reason,
    v_severity,
    'agent_alert_event',
    p_alert_event_id::text,
    null,
    null,
    null,
    p_alert_event_id,
    v_payload,
    p_requested_by
  );
end;
$function$;

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant select, insert, update on table public.agent_action_requests to %I', v_role);
      execute format('grant execute on function public.agent_v2_get_action_requests(text, integer) to %I', v_role);
      execute format('grant execute on function public.agent_v2_create_action_request(text, text, text, text, text, text, text, text, uuid, uuid, uuid, uuid, jsonb, text) to %I', v_role);
      execute format('grant execute on function public.agent_v2_approve_action_request(uuid, text, text) to %I', v_role);
      execute format('grant execute on function public.agent_v2_reject_action_request(uuid, text, text) to %I', v_role);
      execute format('grant execute on function public.agent_v2_request_action_clarification(uuid, text, text) to %I', v_role);
      execute format('grant execute on function public.agent_v2_create_action_request_from_alert(uuid, text) to %I', v_role);
    end if;
  end loop;
end $$;
