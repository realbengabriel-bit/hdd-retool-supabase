create table if not exists public.agent_action_final_confirmations (
  id uuid primary key default gen_random_uuid(),
  action_request_id uuid not null references public.agent_action_requests(id) on delete cascade,
  dry_run_id uuid not null references public.agent_action_dry_runs(id) on delete cascade,
  confirmation_key text unique,
  confirmation_status text not null default 'confirmed',
  confirmed_by text,
  confirmed_at timestamptz not null default now(),
  confirmation_note text,
  operator_acknowledged_risks boolean not null default false,
  operator_acknowledged_dry_run boolean not null default false,
  operator_acknowledged_no_auto_execution boolean not null default true,
  execution_allowed_now boolean not null default false,
  safety_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint agent_action_final_confirmations_status_check
    check (confirmation_status in ('confirmed', 'revoked', 'expired')),
  constraint agent_action_final_confirmations_execution_allowed_check
    check (execution_allowed_now is false)
);

create index if not exists idx_agent_action_final_confirmations_action_request_id
  on public.agent_action_final_confirmations (action_request_id);

create index if not exists idx_agent_action_final_confirmations_dry_run_id
  on public.agent_action_final_confirmations (dry_run_id);

create index if not exists idx_agent_action_final_confirmations_status
  on public.agent_action_final_confirmations (confirmation_status);

create index if not exists idx_agent_action_final_confirmations_confirmed_at_desc
  on public.agent_action_final_confirmations (confirmed_at desc);

create index if not exists idx_agent_action_final_confirmations_created_at_desc
  on public.agent_action_final_confirmations (created_at desc);

create unique index if not exists idx_agent_action_final_confirmations_active_unique
  on public.agent_action_final_confirmations (action_request_id, dry_run_id)
  where confirmation_status = 'confirmed';

create or replace function public.fn_agent_action_final_confirmations_set_updated_at()
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
    where tgrelid = 'public.agent_action_final_confirmations'::regclass
      and tgname = 'trg_agent_action_final_confirmations_set_updated_at'
  ) then
    execute 'create trigger trg_agent_action_final_confirmations_set_updated_at before update on public.agent_action_final_confirmations for each row execute function public.fn_agent_action_final_confirmations_set_updated_at()';
  end if;
end $$;

create or replace function public.agent_v2_get_final_confirmation_gate(
  p_limit integer default 100
)
returns table (
  action_request_id uuid,
  dry_run_id uuid,
  action_title text,
  request_type text,
  severity text,
  approved_by text,
  approved_at timestamptz,
  dry_run_status text,
  can_proceed_to_final_confirmation boolean,
  dry_run_execution_allowed_now boolean,
  latest_confirmation_id uuid,
  confirmation_status text,
  confirmed_by text,
  confirmed_at timestamptz,
  confirmation_note text,
  operator_acknowledged_risks boolean,
  operator_acknowledged_dry_run boolean,
  operator_acknowledged_no_auto_execution boolean,
  execution_allowed_now boolean,
  final_gate_status text,
  missing_final_gate_requirements jsonb,
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
  with gate as (
    select
      ar.id as action_request_id,
      dr.id as dry_run_id,
      ar.title as action_title,
      ar.request_type,
      ar.severity,
      ar.approved_by,
      ar.approved_at,
      dr.dry_run_status,
      coalesce(dr.can_proceed_to_final_confirmation, false) as can_proceed_to_final_confirmation,
      coalesce(dr.execution_allowed_now, false) as dry_run_execution_allowed_now,
      fc.id as latest_confirmation_id,
      fc.confirmation_status,
      fc.confirmed_by,
      fc.confirmed_at,
      fc.confirmation_note,
      coalesce(fc.operator_acknowledged_risks, false) as operator_acknowledged_risks,
      coalesce(fc.operator_acknowledged_dry_run, false) as operator_acknowledged_dry_run,
      coalesce(fc.operator_acknowledged_no_auto_execution, false) as operator_acknowledged_no_auto_execution,
      false as execution_allowed_now,
      array_remove(array[
        case when dr.id is null then 'passed_dry_run'::text end,
        case when dr.id is not null and dr.dry_run_status <> 'passed' then 'dry_run_status_passed'::text end,
        case when dr.id is not null and coalesce(dr.can_proceed_to_final_confirmation, false) is not true then 'can_proceed_to_final_confirmation'::text end,
        case when dr.id is not null and coalesce(dr.execution_allowed_now, false) is not false then 'dry_run_execution_allowed_now_false'::text end,
        case when fc.id is not null then 'no_active_final_confirmation'::text end
      ], null) as missing_requirements
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
        and fc1.confirmation_status = 'confirmed'
      order by fc1.confirmed_at desc, fc1.created_at desc
      limit 1
    ) fc on true
    where ar.status = 'approved'
  )
  select
    g.action_request_id,
    g.dry_run_id,
    g.action_title,
    g.request_type,
    g.severity,
    g.approved_by,
    g.approved_at,
    g.dry_run_status,
    g.can_proceed_to_final_confirmation,
    g.dry_run_execution_allowed_now,
    g.latest_confirmation_id,
    g.confirmation_status,
    g.confirmed_by,
    g.confirmed_at,
    g.confirmation_note,
    g.operator_acknowledged_risks,
    g.operator_acknowledged_dry_run,
    g.operator_acknowledged_no_auto_execution,
    false as execution_allowed_now,
    case
      when g.latest_confirmation_id is not null then 'final_confirmation_recorded'
      when g.dry_run_id is null then 'not_ready_missing_passed_dry_run'
      when g.dry_run_execution_allowed_now is true then 'not_ready_execution_guardrail_violation'
      when g.dry_run_status in ('failed', 'blocked', 'cancelled') then 'not_ready_dry_run_blocked_or_failed'
      when g.dry_run_status = 'passed'
        and g.can_proceed_to_final_confirmation is true
        and g.dry_run_execution_allowed_now is false
        then 'ready_for_final_confirmation'
      when g.dry_run_status <> 'passed'
        or g.can_proceed_to_final_confirmation is not true
        then 'not_ready_missing_passed_dry_run'
      else 'not_ready_unknown'
    end::text as final_gate_status,
    case when g.latest_confirmation_id is not null then '[]'::jsonb else to_jsonb(g.missing_requirements) end as missing_final_gate_requirements,
    'Ez csak végső emberi megerősítési kapu. Nem hajt végre local agentet, EH/OIF műveletet vagy értesítést.'::text as safety_note
  from gate g
  order by
    case lower(coalesce(g.severity, 'info'))
      when 'critical' then 1
      when 'warning' then 2
      when 'info' then 3
      when 'ok' then 4
      else 5
    end,
    coalesce(g.approved_at, now()) asc,
    g.action_title asc
  limit v_limit;
end;
$function$;

create or replace function public.agent_v2_confirm_final_action_request(
  p_action_request_id uuid,
  p_dry_run_id uuid,
  p_confirmed_by text default null,
  p_confirmation_note text default null,
  p_operator_acknowledged_risks boolean default false,
  p_operator_acknowledged_dry_run boolean default false,
  p_operator_acknowledged_no_auto_execution boolean default true
)
returns table (
  id uuid,
  action_request_id uuid,
  dry_run_id uuid,
  confirmation_key text,
  confirmation_status text,
  confirmed_by text,
  confirmed_at timestamptz,
  confirmation_note text,
  operator_acknowledged_risks boolean,
  operator_acknowledged_dry_run boolean,
  operator_acknowledged_no_auto_execution boolean,
  execution_allowed_now boolean,
  safety_snapshot jsonb,
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
  v_dry_run record;
  v_existing_id uuid;
  v_id uuid;
  v_confirmation_key text;
  v_safety_snapshot jsonb;
begin
  select ar.status
  into v_action_status
  from public.agent_action_requests ar
  where ar.id = p_action_request_id;

  if v_action_status is null then
    raise exception 'Action request % was not found.', p_action_request_id using errcode = 'P0002';
  end if;

  if v_action_status <> 'approved' then
    raise exception 'Final confirmation can only be recorded for approved action requests. Action request % has status %.', p_action_request_id, v_action_status using errcode = '22023';
  end if;

  select dr.*
  into v_dry_run
  from public.agent_action_dry_runs dr
  where dr.id = p_dry_run_id;

  if v_dry_run.id is null then
    raise exception 'Dry run % was not found.', p_dry_run_id using errcode = 'P0002';
  end if;

  if v_dry_run.action_request_id <> p_action_request_id then
    raise exception 'Dry run % does not belong to action request %.', p_dry_run_id, p_action_request_id using errcode = '22023';
  end if;

  if v_dry_run.dry_run_status <> 'passed' then
    raise exception 'Final confirmation requires a passed dry run. Dry run % has status %.', p_dry_run_id, v_dry_run.dry_run_status using errcode = '22023';
  end if;

  if v_dry_run.can_proceed_to_final_confirmation is not true then
    raise exception 'Dry run % is not eligible for final confirmation.', p_dry_run_id using errcode = '22023';
  end if;

  if v_dry_run.execution_allowed_now is not false then
    raise exception 'Dry run % violates execution_allowed_now guardrail.', p_dry_run_id using errcode = '22023';
  end if;

  if p_operator_acknowledged_risks is not true then
    raise exception 'Operator must acknowledge final confirmation risks.' using errcode = '22023';
  end if;

  if p_operator_acknowledged_dry_run is not true then
    raise exception 'Operator must acknowledge that the dry run result was reviewed.' using errcode = '22023';
  end if;

  if p_operator_acknowledged_no_auto_execution is not true then
    raise exception 'Operator must acknowledge that this final confirmation does not execute anything.' using errcode = '22023';
  end if;

  select fc.id
  into v_existing_id
  from public.agent_action_final_confirmations fc
  where fc.action_request_id = p_action_request_id
    and fc.dry_run_id = p_dry_run_id
    and fc.confirmation_status = 'confirmed'
  order by fc.confirmed_at desc, fc.created_at desc
  limit 1;

  if v_existing_id is not null then
    return query
    select
      fc.id,
      fc.action_request_id,
      fc.dry_run_id,
      fc.confirmation_key,
      fc.confirmation_status,
      fc.confirmed_by,
      fc.confirmed_at,
      fc.confirmation_note,
      fc.operator_acknowledged_risks,
      fc.operator_acknowledged_dry_run,
      fc.operator_acknowledged_no_auto_execution,
      fc.execution_allowed_now,
      fc.safety_snapshot,
      fc.created_at,
      fc.updated_at
    from public.agent_action_final_confirmations fc
    where fc.id = v_existing_id;
    return;
  end if;

  v_confirmation_key := 'agent_action_final_confirmation:'
    || p_action_request_id::text
    || ':'
    || p_dry_run_id::text
    || ':'
    || md5(concat_ws('|', coalesce(p_confirmed_by, ''), clock_timestamp()::text, gen_random_uuid()::text));

  v_safety_snapshot := jsonb_build_object(
    'no_local_agent_execution', true,
    'no_eh_oif_execution', true,
    'no_notifications', true,
    'no_business_data_mutation', true,
    'execution_allowed_now', false,
    'final_confirmation_only', true,
    'dry_run_id', p_dry_run_id,
    'action_request_id', p_action_request_id
  );

  insert into public.agent_action_final_confirmations as fc (
    action_request_id,
    dry_run_id,
    confirmation_key,
    confirmation_status,
    confirmed_by,
    confirmed_at,
    confirmation_note,
    operator_acknowledged_risks,
    operator_acknowledged_dry_run,
    operator_acknowledged_no_auto_execution,
    execution_allowed_now,
    safety_snapshot
  ) values (
    p_action_request_id,
    p_dry_run_id,
    v_confirmation_key,
    'confirmed',
    nullif(btrim(p_confirmed_by), ''),
    now(),
    nullif(btrim(p_confirmation_note), ''),
    true,
    true,
    true,
    false,
    v_safety_snapshot
  )
  returning fc.id into v_id;

  return query
  select
    fc.id,
    fc.action_request_id,
    fc.dry_run_id,
    fc.confirmation_key,
    fc.confirmation_status,
    fc.confirmed_by,
    fc.confirmed_at,
    fc.confirmation_note,
    fc.operator_acknowledged_risks,
    fc.operator_acknowledged_dry_run,
    fc.operator_acknowledged_no_auto_execution,
    fc.execution_allowed_now,
    fc.safety_snapshot,
    fc.created_at,
    fc.updated_at
  from public.agent_action_final_confirmations fc
  where fc.id = v_id;
end;
$function$;

create or replace function public.agent_v2_revoke_final_confirmation(
  p_confirmation_id uuid,
  p_revoked_by text default null,
  p_revoke_note text default null
)
returns table (
  id uuid,
  action_request_id uuid,
  dry_run_id uuid,
  confirmation_key text,
  confirmation_status text,
  confirmed_by text,
  confirmed_at timestamptz,
  confirmation_note text,
  operator_acknowledged_risks boolean,
  operator_acknowledged_dry_run boolean,
  operator_acknowledged_no_auto_execution boolean,
  execution_allowed_now boolean,
  safety_snapshot jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security invoker
volatile
set search_path = public
as $function$
declare
  v_id uuid;
begin
  select fc.id
  into v_id
  from public.agent_action_final_confirmations fc
  where fc.id = p_confirmation_id;

  if v_id is null then
    raise exception 'Final confirmation % was not found.', p_confirmation_id using errcode = 'P0002';
  end if;

  update public.agent_action_final_confirmations fc
  set confirmation_status = 'revoked',
      confirmation_note = concat_ws(E'
', nullif(fc.confirmation_note, ''), nullif(btrim(p_revoke_note), '')),
      execution_allowed_now = false,
      safety_snapshot = coalesce(fc.safety_snapshot, '{}'::jsonb) || jsonb_build_object(
        'revoked_by', nullif(btrim(p_revoked_by), ''),
        'revoked_at', now(),
        'revoke_note', nullif(btrim(p_revoke_note), ''),
        'execution_allowed_now', false,
        'final_confirmation_revoked_only', true
      )
  where fc.id = p_confirmation_id;

  return query
  select
    fc.id,
    fc.action_request_id,
    fc.dry_run_id,
    fc.confirmation_key,
    fc.confirmation_status,
    fc.confirmed_by,
    fc.confirmed_at,
    fc.confirmation_note,
    fc.operator_acknowledged_risks,
    fc.operator_acknowledged_dry_run,
    fc.operator_acknowledged_no_auto_execution,
    fc.execution_allowed_now,
    fc.safety_snapshot,
    fc.created_at,
    fc.updated_at
  from public.agent_action_final_confirmations fc
  where fc.id = p_confirmation_id;
end;
$function$;

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant select, insert, update on table public.agent_action_final_confirmations to %I', v_role);
      execute format('grant execute on function public.agent_v2_get_final_confirmation_gate(integer) to %I', v_role);
      execute format('grant execute on function public.agent_v2_confirm_final_action_request(uuid, uuid, text, text, boolean, boolean, boolean) to %I', v_role);
      execute format('grant execute on function public.agent_v2_revoke_final_confirmation(uuid, text, text) to %I', v_role);
    end if;
  end loop;
end $$;
