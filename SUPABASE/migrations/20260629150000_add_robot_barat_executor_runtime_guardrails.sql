create table if not exists public.agent_executor_runtime_guardrails (
  id uuid primary key default gen_random_uuid(),
  guardrail_key text not null unique,
  guardrail_name text not null,
  guardrail_status text not null default 'disabled',
  runtime_enable_flag boolean not null default false,
  local_agent_execution_enabled boolean not null default false,
  eh_oif_execution_enabled boolean not null default false,
  notifications_enabled boolean not null default false,
  business_data_mutation_enabled boolean not null default false,
  allowed_executor_routes jsonb not null default '[]'::jsonb,
  blocked_executor_routes jsonb not null default '["enterhungary","oif","documents","case_assistant","manual_review"]'::jsonb,
  required_preconditions jsonb not null default '[]'::jsonb,
  safety_policy jsonb not null default '{}'::jsonb,
  configured_by text,
  configuration_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint agent_executor_runtime_guardrails_status_check
    check (guardrail_status in ('disabled', 'dry_run_only', 'manual_review_only', 'enabled_limited', 'enabled')),
  constraint agent_executor_runtime_guardrails_allowed_routes_array_check
    check (jsonb_typeof(allowed_executor_routes) = 'array'),
  constraint agent_executor_runtime_guardrails_blocked_routes_array_check
    check (jsonb_typeof(blocked_executor_routes) = 'array'),
  constraint agent_executor_runtime_guardrails_required_preconditions_array_check
    check (jsonb_typeof(required_preconditions) = 'array'),
  constraint agent_executor_runtime_guardrails_safety_policy_object_check
    check (jsonb_typeof(safety_policy) = 'object')
);

create index if not exists idx_agent_executor_runtime_guardrails_status
  on public.agent_executor_runtime_guardrails (guardrail_status);

create index if not exists idx_agent_executor_runtime_guardrails_updated_at_desc
  on public.agent_executor_runtime_guardrails (updated_at desc);

create or replace function public.fn_agent_executor_runtime_guardrails_set_updated_at()
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
    where tgrelid = 'public.agent_executor_runtime_guardrails'::regclass
      and tgname = 'trg_agent_executor_runtime_guardrails_set_updated_at'
  ) then
    execute 'create trigger trg_agent_executor_runtime_guardrails_set_updated_at before update on public.agent_executor_runtime_guardrails for each row execute function public.fn_agent_executor_runtime_guardrails_set_updated_at()';
  end if;
end $$;

insert into public.agent_executor_runtime_guardrails as gr (
  guardrail_key,
  guardrail_name,
  guardrail_status,
  runtime_enable_flag,
  local_agent_execution_enabled,
  eh_oif_execution_enabled,
  notifications_enabled,
  business_data_mutation_enabled,
  allowed_executor_routes,
  blocked_executor_routes,
  required_preconditions,
  safety_policy,
  configured_by,
  configuration_note
) values (
  'robot_barat_executor_runtime_v1',
  'Robot Barát Executor Runtime Guardrails',
  'disabled',
  false,
  false,
  false,
  false,
  false,
  '[]'::jsonb,
  '["enterhungary","oif","documents","case_assistant","manual_review"]'::jsonb,
  jsonb_build_array(
    'approved_action_request',
    'passed_dry_run',
    'final_confirmation',
    'execution_handoff_ready',
    'runtime_enable_flag_true',
    'operator_runtime_session',
    'fresh_guardrail_check',
    'audit_log_destination'
  ),
  jsonb_build_object(
    'schema_version', 'robot_barat_runtime_guardrails_v1',
    'execution_allowed_now', false,
    'default_policy', 'deny_all_execution',
    'local_agent_execution', 'disabled',
    'eh_oif_execution', 'disabled',
    'notifications', 'disabled',
    'business_data_mutation', 'disabled',
    'current_task_allows_execution', false,
    'future_enablement_requires_new_migration_and_manual_review', true
  ),
  'migration',
  'Default deny-all runtime guardrail registry row. No executor runtime is enabled by this migration.'
)
on conflict (guardrail_key) do update
set guardrail_name = excluded.guardrail_name,
    guardrail_status = 'disabled',
    runtime_enable_flag = false,
    local_agent_execution_enabled = false,
    eh_oif_execution_enabled = false,
    notifications_enabled = false,
    business_data_mutation_enabled = false,
    allowed_executor_routes = '[]'::jsonb,
    blocked_executor_routes = '["enterhungary","oif","documents","case_assistant","manual_review"]'::jsonb,
    required_preconditions = excluded.required_preconditions,
    safety_policy = excluded.safety_policy,
    configured_by = excluded.configured_by,
    configuration_note = excluded.configuration_note;

create or replace function public.agent_v2_get_executor_runtime_guardrails()
returns table (
  id uuid,
  guardrail_key text,
  guardrail_name text,
  guardrail_status text,
  runtime_enable_flag boolean,
  local_agent_execution_enabled boolean,
  eh_oif_execution_enabled boolean,
  notifications_enabled boolean,
  business_data_mutation_enabled boolean,
  allowed_executor_routes jsonb,
  blocked_executor_routes jsonb,
  required_preconditions jsonb,
  safety_policy jsonb,
  configured_by text,
  configuration_note text,
  created_at timestamptz,
  updated_at timestamptz,
  execution_allowed_now boolean,
  safety_note text
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
begin
  return query
  select
    gr.id,
    gr.guardrail_key,
    gr.guardrail_name,
    gr.guardrail_status,
    gr.runtime_enable_flag,
    gr.local_agent_execution_enabled,
    gr.eh_oif_execution_enabled,
    gr.notifications_enabled,
    gr.business_data_mutation_enabled,
    gr.allowed_executor_routes,
    gr.blocked_executor_routes,
    gr.required_preconditions,
    gr.safety_policy,
    gr.configured_by,
    gr.configuration_note,
    gr.created_at,
    gr.updated_at,
    (
      gr.guardrail_status = 'enabled'
      and gr.runtime_enable_flag is true
      and gr.local_agent_execution_enabled is true
      and gr.eh_oif_execution_enabled is true
      and gr.notifications_enabled is true
      and gr.business_data_mutation_enabled is true
    ) as execution_allowed_now,
    'Executor runtime guardrails are currently disabled. This system must not execute local agent, EH/OIF actions, notifications, or business-data mutations.'::text as safety_note
  from public.agent_executor_runtime_guardrails gr
  where gr.guardrail_key = 'robot_barat_executor_runtime_v1'
  order by gr.created_at asc
  limit 1;
end;
$function$;

create or replace function public.agent_v2_assert_executor_runtime_disabled()
returns table (
  execution_allowed_now boolean,
  runtime_enable_flag boolean,
  local_agent_execution_enabled boolean,
  eh_oif_execution_enabled boolean,
  notifications_enabled boolean,
  business_data_mutation_enabled boolean,
  assertion_status text,
  assertion_note text,
  guardrails jsonb
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
begin
  return query
  select
    false as execution_allowed_now,
    gr.runtime_enable_flag,
    gr.local_agent_execution_enabled,
    gr.eh_oif_execution_enabled,
    gr.notifications_enabled,
    gr.business_data_mutation_enabled,
    case
      when gr.runtime_enable_flag is false
        and gr.local_agent_execution_enabled is false
        and gr.eh_oif_execution_enabled is false
        and gr.notifications_enabled is false
        and gr.business_data_mutation_enabled is false
        then 'runtime_disabled_ok'::text
      else 'runtime_guardrail_violation'::text
    end as assertion_status,
    case
      when gr.runtime_enable_flag is false
        and gr.local_agent_execution_enabled is false
        and gr.eh_oif_execution_enabled is false
        and gr.notifications_enabled is false
        and gr.business_data_mutation_enabled is false
        then 'Executor runtime remains disabled. Future executors must stop before any local agent, EH/OIF, notification, or business-data mutation.'::text
      else 'Executor runtime guardrail violation detected. Future executors must stop and require manual review before any action.'::text
    end as assertion_note,
    jsonb_build_object(
      'id', gr.id,
      'guardrail_key', gr.guardrail_key,
      'guardrail_name', gr.guardrail_name,
      'guardrail_status', gr.guardrail_status,
      'runtime_enable_flag', gr.runtime_enable_flag,
      'local_agent_execution_enabled', gr.local_agent_execution_enabled,
      'eh_oif_execution_enabled', gr.eh_oif_execution_enabled,
      'notifications_enabled', gr.notifications_enabled,
      'business_data_mutation_enabled', gr.business_data_mutation_enabled,
      'allowed_executor_routes', gr.allowed_executor_routes,
      'blocked_executor_routes', gr.blocked_executor_routes,
      'required_preconditions', gr.required_preconditions,
      'safety_policy', gr.safety_policy,
      'execution_allowed_now', false,
      'current_task_allows_execution', false
    ) as guardrails
  from public.agent_executor_runtime_guardrails gr
  where gr.guardrail_key = 'robot_barat_executor_runtime_v1'
  order by gr.created_at asc
  limit 1;
end;
$function$;

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant select on table public.agent_executor_runtime_guardrails to %I', v_role);
      execute format('grant execute on function public.agent_v2_get_executor_runtime_guardrails() to %I', v_role);
      execute format('grant execute on function public.agent_v2_assert_executor_runtime_disabled() to %I', v_role);
    end if;
  end loop;
end $$;
