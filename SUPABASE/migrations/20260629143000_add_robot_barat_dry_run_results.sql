create table if not exists public.agent_action_dry_runs (
  id uuid primary key default gen_random_uuid(),
  action_request_id uuid not null references public.agent_action_requests(id) on delete cascade,
  dry_run_key text unique,
  dry_run_status text not null default 'created',
  executor_type text,
  executor_route text,
  input_payload jsonb not null default '{}'::jsonb,
  validated_payload jsonb not null default '{}'::jsonb,
  preview_result jsonb not null default '{}'::jsonb,
  validation_errors jsonb not null default '[]'::jsonb,
  warnings jsonb not null default '[]'::jsonb,
  missing_fields jsonb not null default '[]'::jsonb,
  safety_checks jsonb not null default '{}'::jsonb,
  can_proceed_to_final_confirmation boolean not null default false,
  execution_allowed_now boolean not null default false,
  dry_run_by text,
  dry_run_started_at timestamptz,
  dry_run_finished_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint agent_action_dry_runs_status_check
    check (dry_run_status in ('created', 'running', 'passed', 'failed', 'blocked', 'cancelled')),
  constraint agent_action_dry_runs_execution_allowed_check
    check (execution_allowed_now is false),
  constraint agent_action_dry_runs_final_confirmation_check
    check (
      can_proceed_to_final_confirmation is false
      or (
        dry_run_status = 'passed'
        and case
          when jsonb_typeof(validation_errors) = 'array'
            then jsonb_array_length(validation_errors) = 0
          else false
        end
      )
    )
);

create index if not exists idx_agent_action_dry_runs_action_request_id
  on public.agent_action_dry_runs (action_request_id);

create index if not exists idx_agent_action_dry_runs_status
  on public.agent_action_dry_runs (dry_run_status);

create index if not exists idx_agent_action_dry_runs_executor_type
  on public.agent_action_dry_runs (executor_type);

create index if not exists idx_agent_action_dry_runs_executor_route
  on public.agent_action_dry_runs (executor_route);

create index if not exists idx_agent_action_dry_runs_created_at_desc
  on public.agent_action_dry_runs (created_at desc);

create index if not exists idx_agent_action_dry_runs_finished_at_desc
  on public.agent_action_dry_runs (dry_run_finished_at desc);

create or replace function public.fn_agent_action_dry_runs_set_updated_at()
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
    where tgrelid = 'public.agent_action_dry_runs'::regclass
      and tgname = 'trg_agent_action_dry_runs_set_updated_at'
  ) then
    execute 'create trigger trg_agent_action_dry_runs_set_updated_at before update on public.agent_action_dry_runs for each row execute function public.fn_agent_action_dry_runs_set_updated_at()';
  end if;
end $$;

create or replace function public.agent_v2_get_dry_run_results(
  p_action_request_id uuid default null,
  p_limit integer default 100
)
returns table (
  id uuid,
  action_request_id uuid,
  dry_run_key text,
  dry_run_status text,
  executor_type text,
  executor_route text,
  input_payload jsonb,
  validated_payload jsonb,
  preview_result jsonb,
  validation_errors jsonb,
  warnings jsonb,
  missing_fields jsonb,
  safety_checks jsonb,
  can_proceed_to_final_confirmation boolean,
  execution_allowed_now boolean,
  dry_run_by text,
  dry_run_started_at timestamptz,
  dry_run_finished_at timestamptz,
  notes text,
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
  select
    dr.id,
    dr.action_request_id,
    dr.dry_run_key,
    dr.dry_run_status,
    dr.executor_type,
    dr.executor_route,
    dr.input_payload,
    dr.validated_payload,
    dr.preview_result,
    dr.validation_errors,
    dr.warnings,
    dr.missing_fields,
    dr.safety_checks,
    dr.can_proceed_to_final_confirmation,
    dr.execution_allowed_now,
    dr.dry_run_by,
    dr.dry_run_started_at,
    dr.dry_run_finished_at,
    dr.notes,
    dr.created_at,
    dr.updated_at
  from public.agent_action_dry_runs dr
  where p_action_request_id is null
     or dr.action_request_id = p_action_request_id
  order by dr.created_at desc
  limit v_limit;
end;
$function$;

create or replace function public.agent_v2_record_dry_run_result(
  p_action_request_id uuid,
  p_dry_run_status text,
  p_executor_type text default null,
  p_executor_route text default null,
  p_input_payload jsonb default '{}'::jsonb,
  p_validated_payload jsonb default '{}'::jsonb,
  p_preview_result jsonb default '{}'::jsonb,
  p_validation_errors jsonb default '[]'::jsonb,
  p_warnings jsonb default '[]'::jsonb,
  p_missing_fields jsonb default '[]'::jsonb,
  p_safety_checks jsonb default '{}'::jsonb,
  p_can_proceed_to_final_confirmation boolean default false,
  p_dry_run_by text default null,
  p_notes text default null
)
returns table (
  id uuid,
  action_request_id uuid,
  dry_run_key text,
  dry_run_status text,
  executor_type text,
  executor_route text,
  input_payload jsonb,
  validated_payload jsonb,
  preview_result jsonb,
  validation_errors jsonb,
  warnings jsonb,
  missing_fields jsonb,
  safety_checks jsonb,
  can_proceed_to_final_confirmation boolean,
  execution_allowed_now boolean,
  dry_run_by text,
  dry_run_started_at timestamptz,
  dry_run_finished_at timestamptz,
  notes text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
volatile
set search_path = public
as $function$
declare
  v_action_status text;
  v_dry_run_status text := lower(nullif(btrim(p_dry_run_status), ''));
  v_validation_errors jsonb := coalesce(p_validation_errors, '[]'::jsonb);
  v_warnings jsonb := coalesce(p_warnings, '[]'::jsonb);
  v_missing_fields jsonb := coalesce(p_missing_fields, '[]'::jsonb);
  v_safety_checks jsonb := coalesce(p_safety_checks, '{}'::jsonb);
  v_can_proceed boolean := false;
  v_dry_run_key text;
  v_id uuid;
begin
  select ar.status
  into v_action_status
  from public.agent_action_requests ar
  where ar.id = p_action_request_id;

  if v_action_status is null then
    raise exception 'Action request % was not found.', p_action_request_id using errcode = 'P0002';
  end if;

  if v_action_status <> 'approved' then
    raise exception 'Dry-run result can only be recorded for approved action requests. Action request % has status %.', p_action_request_id, v_action_status using errcode = '22023';
  end if;

  if v_dry_run_status not in ('created', 'running', 'passed', 'failed', 'blocked', 'cancelled') then
    raise exception 'Invalid dry-run status: %. Allowed statuses: created, running, passed, failed, blocked, cancelled.', p_dry_run_status using errcode = '22023';
  end if;

  if jsonb_typeof(v_validation_errors) <> 'array' then
    raise exception 'p_validation_errors must be a JSON array.' using errcode = '22023';
  end if;

  if jsonb_typeof(v_warnings) <> 'array' then
    raise exception 'p_warnings must be a JSON array.' using errcode = '22023';
  end if;

  if jsonb_typeof(v_missing_fields) <> 'array' then
    raise exception 'p_missing_fields must be a JSON array.' using errcode = '22023';
  end if;

  if jsonb_typeof(v_safety_checks) <> 'object' then
    raise exception 'p_safety_checks must be a JSON object.' using errcode = '22023';
  end if;

  v_safety_checks := v_safety_checks || jsonb_build_object(
    'no_local_agent_execution', true,
    'no_eh_oif_execution', true,
    'no_notifications', true,
    'no_business_data_mutation', true,
    'execution_allowed_now', false,
    'dry_run_only', true
  );

  v_can_proceed := coalesce(p_can_proceed_to_final_confirmation, false)
    and v_dry_run_status = 'passed'
    and jsonb_array_length(v_validation_errors) = 0;

  v_dry_run_key := 'agent_action_dry_run:'
    || p_action_request_id::text
    || ':'
    || md5(concat_ws('|',
      v_dry_run_status,
      coalesce(p_executor_type, ''),
      coalesce(p_executor_route, ''),
      coalesce(p_input_payload, '{}'::jsonb)::text,
      coalesce(p_validated_payload, '{}'::jsonb)::text,
      coalesce(p_preview_result, '{}'::jsonb)::text,
      clock_timestamp()::text,
      gen_random_uuid()::text
    ));

  insert into public.agent_action_dry_runs as dr (
    action_request_id,
    dry_run_key,
    dry_run_status,
    executor_type,
    executor_route,
    input_payload,
    validated_payload,
    preview_result,
    validation_errors,
    warnings,
    missing_fields,
    safety_checks,
    can_proceed_to_final_confirmation,
    execution_allowed_now,
    dry_run_by,
    dry_run_started_at,
    dry_run_finished_at,
    notes
  ) values (
    p_action_request_id,
    v_dry_run_key,
    v_dry_run_status,
    nullif(btrim(p_executor_type), ''),
    nullif(btrim(p_executor_route), ''),
    coalesce(p_input_payload, '{}'::jsonb),
    coalesce(p_validated_payload, '{}'::jsonb),
    coalesce(p_preview_result, '{}'::jsonb),
    v_validation_errors,
    v_warnings,
    v_missing_fields,
    v_safety_checks,
    v_can_proceed,
    false,
    nullif(btrim(p_dry_run_by), ''),
    case when v_dry_run_status in ('running', 'passed', 'failed', 'blocked', 'cancelled') then now() else null end,
    case when v_dry_run_status in ('passed', 'failed', 'blocked', 'cancelled') then now() else null end,
    nullif(btrim(p_notes), '')
  )
  returning dr.id into v_id;

  return query
  select *
  from public.agent_v2_get_dry_run_results(p_action_request_id, 200) gdr
  where gdr.id = v_id;
end;
$function$;

create or replace function public.agent_v2_get_latest_dry_run_for_action_request(
  p_action_request_id uuid
)
returns table (
  id uuid,
  action_request_id uuid,
  dry_run_key text,
  dry_run_status text,
  executor_type text,
  executor_route text,
  input_payload jsonb,
  validated_payload jsonb,
  preview_result jsonb,
  validation_errors jsonb,
  warnings jsonb,
  missing_fields jsonb,
  safety_checks jsonb,
  can_proceed_to_final_confirmation boolean,
  execution_allowed_now boolean,
  dry_run_by text,
  dry_run_started_at timestamptz,
  dry_run_finished_at timestamptz,
  notes text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
begin
  return query
  select *
  from public.agent_v2_get_dry_run_results(p_action_request_id, 1);
end;
$function$;

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant select, insert, update on table public.agent_action_dry_runs to %I', v_role);
      execute format('grant execute on function public.agent_v2_get_dry_run_results(uuid, integer) to %I', v_role);
      execute format('grant execute on function public.agent_v2_record_dry_run_result(uuid, text, text, text, jsonb, jsonb, jsonb, jsonb, jsonb, jsonb, jsonb, boolean, text, text) to %I', v_role);
      execute format('grant execute on function public.agent_v2_get_latest_dry_run_for_action_request(uuid) to %I', v_role);
    end if;
  end loop;
end $$;
