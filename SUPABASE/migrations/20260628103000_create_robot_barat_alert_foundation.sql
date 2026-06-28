-- HDD / UAHUN Robot Barat proactive alert foundation
-- Read-first backend foundation only. No cron, no notification sending, no action execution.

create extension if not exists pgcrypto;

create table if not exists public.agent_alert_rules (
  id uuid primary key default gen_random_uuid(),
  rule_key text not null unique,
  rule_name text not null,
  category text not null,
  description text,
  is_enabled boolean not null default true,
  severity text not null default 'info',
  frequency text not null default 'daily',
  condition_json jsonb not null default '{}'::jsonb,
  target_audience jsonb not null default '[]'::jsonb,
  created_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.agent_alert_rules add column if not exists id uuid default gen_random_uuid();
alter table public.agent_alert_rules add column if not exists rule_key text;
alter table public.agent_alert_rules add column if not exists rule_name text;
alter table public.agent_alert_rules add column if not exists category text;
alter table public.agent_alert_rules add column if not exists description text;
alter table public.agent_alert_rules add column if not exists is_enabled boolean not null default true;
alter table public.agent_alert_rules add column if not exists severity text not null default 'info';
alter table public.agent_alert_rules add column if not exists frequency text not null default 'daily';
alter table public.agent_alert_rules add column if not exists condition_json jsonb not null default '{}'::jsonb;
alter table public.agent_alert_rules add column if not exists target_audience jsonb not null default '[]'::jsonb;
alter table public.agent_alert_rules add column if not exists created_by text;
alter table public.agent_alert_rules add column if not exists created_at timestamptz not null default now();
alter table public.agent_alert_rules add column if not exists updated_at timestamptz not null default now();

alter table public.agent_alert_rules alter column id set default gen_random_uuid();
alter table public.agent_alert_rules alter column is_enabled set default true;
alter table public.agent_alert_rules alter column severity set default 'info';
alter table public.agent_alert_rules alter column frequency set default 'daily';
alter table public.agent_alert_rules alter column condition_json set default '{}'::jsonb;
alter table public.agent_alert_rules alter column target_audience set default '[]'::jsonb;
alter table public.agent_alert_rules alter column created_at set default now();
alter table public.agent_alert_rules alter column updated_at set default now();

create table if not exists public.agent_alert_events (
  id uuid primary key default gen_random_uuid(),
  rule_id uuid references public.agent_alert_rules(id) on delete cascade,
  alert_key text not null,
  category text not null,
  severity text not null default 'info',
  entity_type text,
  entity_id text,
  title text not null,
  message text,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'open',
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  resolved_at timestamptz,
  notified_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.agent_alert_events add column if not exists id uuid default gen_random_uuid();
alter table public.agent_alert_events add column if not exists rule_id uuid;
alter table public.agent_alert_events add column if not exists alert_key text;
alter table public.agent_alert_events add column if not exists category text;
alter table public.agent_alert_events add column if not exists severity text not null default 'info';
alter table public.agent_alert_events add column if not exists entity_type text;
alter table public.agent_alert_events add column if not exists entity_id text;
alter table public.agent_alert_events add column if not exists title text;
alter table public.agent_alert_events add column if not exists message text;
alter table public.agent_alert_events add column if not exists payload jsonb not null default '{}'::jsonb;
alter table public.agent_alert_events add column if not exists status text not null default 'open';
alter table public.agent_alert_events add column if not exists first_seen_at timestamptz not null default now();
alter table public.agent_alert_events add column if not exists last_seen_at timestamptz not null default now();
alter table public.agent_alert_events add column if not exists resolved_at timestamptz;
alter table public.agent_alert_events add column if not exists notified_at timestamptz;
alter table public.agent_alert_events add column if not exists created_at timestamptz not null default now();

alter table public.agent_alert_events alter column id set default gen_random_uuid();
alter table public.agent_alert_events alter column severity set default 'info';
alter table public.agent_alert_events alter column payload set default '{}'::jsonb;
alter table public.agent_alert_events alter column status set default 'open';
alter table public.agent_alert_events alter column first_seen_at set default now();
alter table public.agent_alert_events alter column last_seen_at set default now();
alter table public.agent_alert_events alter column created_at set default now();

create table if not exists public.agent_alert_state (
  id uuid primary key default gen_random_uuid(),
  alert_key text not null unique,
  last_seen_hash text,
  last_seen_at timestamptz,
  last_notified_at timestamptz,
  suppress_until timestamptz,
  state_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.agent_alert_state add column if not exists id uuid default gen_random_uuid();
alter table public.agent_alert_state add column if not exists alert_key text;
alter table public.agent_alert_state add column if not exists last_seen_hash text;
alter table public.agent_alert_state add column if not exists last_seen_at timestamptz;
alter table public.agent_alert_state add column if not exists last_notified_at timestamptz;
alter table public.agent_alert_state add column if not exists suppress_until timestamptz;
alter table public.agent_alert_state add column if not exists state_json jsonb not null default '{}'::jsonb;
alter table public.agent_alert_state add column if not exists updated_at timestamptz not null default now();

alter table public.agent_alert_state alter column id set default gen_random_uuid();
alter table public.agent_alert_state alter column state_json set default '{}'::jsonb;
alter table public.agent_alert_state alter column updated_at set default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.agent_alert_rules'::regclass
      and conname = 'agent_alert_rules_category_check'
  ) then
    alter table public.agent_alert_rules
      add constraint agent_alert_rules_category_check
      check (category in (
        'workflow_blocker',
        'missing_document',
        'oif_readiness',
        'action_request',
        'napi_drive',
        'expiry',
        'stage_aging',
        'daily_briefing',
        'system'
      )) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.agent_alert_rules'::regclass
      and conname = 'agent_alert_rules_severity_check'
  ) then
    alter table public.agent_alert_rules
      add constraint agent_alert_rules_severity_check
      check (severity in ('info', 'warning', 'urgent', 'blocker')) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.agent_alert_events'::regclass
      and conname = 'agent_alert_events_category_check'
  ) then
    alter table public.agent_alert_events
      add constraint agent_alert_events_category_check
      check (category in (
        'workflow_blocker',
        'missing_document',
        'oif_readiness',
        'action_request',
        'napi_drive',
        'expiry',
        'stage_aging',
        'daily_briefing',
        'system'
      )) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.agent_alert_events'::regclass
      and conname = 'agent_alert_events_severity_check'
  ) then
    alter table public.agent_alert_events
      add constraint agent_alert_events_severity_check
      check (severity in ('info', 'warning', 'urgent', 'blocker')) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.agent_alert_events'::regclass
      and conname = 'agent_alert_events_status_check'
  ) then
    alter table public.agent_alert_events
      add constraint agent_alert_events_status_check
      check (status in ('open', 'active', 'acknowledged', 'resolved', 'suppressed')) not valid;
  end if;
end $$;

create unique index if not exists agent_alert_rules_rule_key_uidx
  on public.agent_alert_rules (rule_key);

create index if not exists agent_alert_rules_category_enabled_idx
  on public.agent_alert_rules (category, is_enabled);

create index if not exists agent_alert_events_category_status_severity_idx
  on public.agent_alert_events (category, status, severity);

create index if not exists agent_alert_events_entity_idx
  on public.agent_alert_events (entity_type, entity_id);

create index if not exists agent_alert_events_last_seen_desc_idx
  on public.agent_alert_events (last_seen_at desc);

create index if not exists agent_alert_events_alert_key_status_idx
  on public.agent_alert_events (alert_key, status);

create unique index if not exists agent_alert_state_alert_key_uidx
  on public.agent_alert_state (alert_key);

create index if not exists agent_alert_state_last_notified_idx
  on public.agent_alert_state (last_notified_at);

do $$
begin
  if to_regclass('public.agent_alert_events_alert_key_open_active_uidx') is null then
    if not exists (
      select 1
      from (
        select alert_key
        from public.agent_alert_events
        where status in ('open', 'active')
        group by alert_key
        having count(*) > 1
      ) duplicates
    ) then
      execute 'create unique index agent_alert_events_alert_key_open_active_uidx on public.agent_alert_events (alert_key) where status in (''open'', ''active'')';
    else
      raise notice 'Skipping agent_alert_events_alert_key_open_active_uidx because duplicate open/active alert_key rows already exist.';
    end if;
  end if;
end $$;

create or replace function public.fn_agent_alerts_set_updated_at()
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
    where tgrelid = 'public.agent_alert_rules'::regclass
      and tgname = 'trg_agent_alert_rules_set_updated_at'
  ) then
    execute 'create trigger trg_agent_alert_rules_set_updated_at before update on public.agent_alert_rules for each row execute function public.fn_agent_alerts_set_updated_at()';
  end if;

  if not exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.agent_alert_state'::regclass
      and tgname = 'trg_agent_alert_state_set_updated_at'
  ) then
    execute 'create trigger trg_agent_alert_state_set_updated_at before update on public.agent_alert_state for each row execute function public.fn_agent_alerts_set_updated_at()';
  end if;
end $$;

insert into public.agent_alert_rules (
  rule_key,
  rule_name,
  category,
  description,
  is_enabled,
  severity,
  frequency,
  condition_json,
  target_audience,
  created_by
)
values
  (
    'workflow_blockers_daily',
    'Workflow blockers daily scan',
    'workflow_blocker',
    'Daily read-only scan for workflow blockers and hard missing requirements.',
    true,
    'urgent',
    'daily',
    jsonb_build_object(
      'scanner', 'agent_v2_scan_workflow_blocker_alerts',
      'source', 'public.v_retool_workflow_missing_requirements',
      'status_exclusions', jsonb_build_array('resolved', 'closed', 'complete', 'completed', 'ok'),
      'dedupe_key', 'workflow_case_id + group + missing_item'
    ),
    jsonb_build_array('operations'),
    'migration'
  ),
  (
    'missing_documents_daily',
    'Missing required documents daily scan',
    'missing_document',
    'Daily read-only scan for required document gaps surfaced by missing requirements.',
    true,
    'warning',
    'daily',
    jsonb_build_object(
      'scanner', 'agent_v2_scan_workflow_blocker_alerts',
      'source', 'public.v_retool_workflow_missing_requirements',
      'filter_category', 'missing_document',
      'dedupe_key', 'workflow_case_id + suggested_document_type_code + missing_item'
    ),
    jsonb_build_array('operations', 'documents'),
    'migration'
  ),
  (
    'oif_readiness_changes',
    'OIF/EH package readiness changes',
    'oif_readiness',
    'Read-only foundation rule for OIF/EH readiness changes; scanner wiring can be added when a stable readiness source is available in migrations.',
    true,
    'warning',
    'daily',
    jsonb_build_object(
      'scanner', 'future_oif_readiness_scanner',
      'source', 'agent_v2 readiness tools',
      'dedupe_key', 'workflow_case_id + package_code + readiness_status'
    ),
    jsonb_build_array('operations'),
    'migration'
  ),
  (
    'action_requests_waiting',
    'Action requests waiting for approval',
    'action_request',
    'Read-only foundation rule for action requests waiting for human approval.',
    true,
    'warning',
    'hourly',
    jsonb_build_object(
      'scanner', 'agent_v2_scan_action_request_alerts',
      'status_filter', jsonb_build_array('waiting', 'pending', 'requires_approval'),
      'dedupe_key', 'action_request_id + status'
    ),
    jsonb_build_array('operations'),
    'migration'
  ),
  (
    'failed_action_requests',
    'Failed action requests',
    'action_request',
    'Read-only foundation rule for failed action requests.',
    true,
    'urgent',
    'hourly',
    jsonb_build_object(
      'scanner', 'agent_v2_scan_action_request_alerts',
      'status_filter', jsonb_build_array('failed', 'error'),
      'dedupe_key', 'action_request_id + status + error_hash'
    ),
    jsonb_build_array('operations', 'technical'),
    'migration'
  ),
  (
    'napi_drive_incomplete_daily',
    'Napi Drive incomplete cases daily scan',
    'napi_drive',
    'Read-only foundation rule for new, open, or incomplete Napi Drive cases.',
    true,
    'warning',
    'daily',
    jsonb_build_object(
      'scanner', 'future_napi_drive_incomplete_scanner',
      'source', 'Napi Drive summary tools/views',
      'dedupe_key', 'drive_case_id + incomplete_reason'
    ),
    jsonb_build_array('operations'),
    'migration'
  ),
  (
    'document_expiry_30d',
    'Document expiry within 30 days',
    'expiry',
    'Daily read-only scan for central documents that are expired or expire within 30 days.',
    true,
    'warning',
    'daily',
    jsonb_build_object(
      'scanner', 'agent_v2_scan_document_expiry_alerts',
      'days', 30,
      'source_priority', jsonb_build_array('public.v_retool_document_files', 'public.document_files'),
      'dedupe_key', 'document_file_id + expiry_date'
    ),
    jsonb_build_array('operations', 'documents'),
    'migration'
  ),
  (
    'bmh_nav_oep_stage_aging',
    'BMH/NAV/OEP stage aging',
    'stage_aging',
    'Read-only foundation rule for BMH, NAV, and OEP workflow items aging too long in stage.',
    true,
    'warning',
    'daily',
    jsonb_build_object(
      'scanner', 'future_stage_aging_scanner',
      'stages', jsonb_build_array('bmh', 'nav', 'oep'),
      'dedupe_key', 'workflow_case_id + stage + aging_bucket'
    ),
    jsonb_build_array('operations'),
    'migration'
  )
on conflict (rule_key) do update
set
  rule_name = excluded.rule_name,
  category = excluded.category,
  description = excluded.description,
  severity = excluded.severity,
  frequency = excluded.frequency,
  condition_json = excluded.condition_json,
  target_audience = excluded.target_audience,
  updated_at = now();

create or replace function public.agent_v2_scan_action_request_alerts(
  p_limit int default 100
)
returns table (
  alert_key text,
  category text,
  severity text,
  entity_type text,
  entity_id text,
  title text,
  message text,
  payload jsonb,
  dedupe_hash text
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
begin
  -- No action request table is present in the repository migrations yet.
  -- This read-only scanner intentionally returns zero rows until the action-request
  -- storage table/view is migrated and wired as a stable source.
  return;
end;
$function$;

comment on function public.agent_v2_scan_action_request_alerts(int)
is 'Read-only alert scanner. Returns zero rows until an action-request table/view is present in migrations.';

create or replace function public.agent_v2_scan_workflow_blocker_alerts(
  p_limit int default 100
)
returns table (
  alert_key text,
  category text,
  severity text,
  entity_type text,
  entity_id text,
  title text,
  message text,
  payload jsonb,
  dedupe_hash text
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
declare
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 1000);
begin
  if to_regclass('public.v_retool_workflow_missing_requirements') is null then
    -- Missing-requirements view is not present in the repository migrations yet.
    return;
  end if;

  return query execute $sql$
    with source_rows as (
      select to_jsonb(m) as row_json
      from public.v_retool_workflow_missing_requirements m
    ),
    normalized as (
      select
        row_json,
        nullif(btrim(coalesce(
          row_json->>'workflow_case_id',
          row_json->>'workflow_case_uuid',
          row_json->>'case_id',
          row_json->>'workflow_id'
        )), '') as workflow_case_id,
        nullif(btrim(coalesce(
          row_json->>'csoport',
          row_json->>'group',
          row_json->>'requirement_group',
          row_json->>'stage',
          row_json->>'workflow_stage'
        )), '') as csoport,
        nullif(btrim(coalesce(
          row_json->>'hianyzo_tetel',
          row_json->>'missing_item',
          row_json->>'missing_requirement',
          row_json->>'requirement_name',
          row_json->>'title',
          row_json->>'label'
        )), '') as hianyzo_tetel,
        nullif(btrim(coalesce(
          row_json->>'suggested_document_type_code',
          row_json->>'document_type_code',
          row_json->>'required_document_type_code',
          row_json->>'document_code'
        )), '') as suggested_document_type_code,
        nullif(btrim(coalesce(
          row_json->>'potlas_tipus',
          row_json->>'replacement_type',
          row_json->>'remediation_type',
          row_json->>'missing_type',
          row_json->>'type'
        )), '') as potlas_tipus,
        nullif(btrim(coalesce(
          row_json->>'sulyossag',
          row_json->>'severity',
          row_json->>'priority',
          row_json->>'risk_level'
        )), '') as sulyossag,
        nullif(btrim(coalesce(
          row_json->>'statusz',
          row_json->>'status',
          row_json->>'requirement_status',
          row_json->>'state'
        )), '') as statusz,
        nullif(btrim(coalesce(
          row_json->>'reszletek',
          row_json->>'details',
          row_json->>'description',
          row_json->>'message',
          row_json->>'reason'
        )), '') as reszletek,
        nullif(btrim(coalesce(
          row_json->>'raw_requirement',
          row_json->>'requirement',
          row_json->>'requirement_code',
          row_json->>'raw',
          row_json->>'source_requirement'
        )), '') as raw_requirement
      from source_rows
    ),
    candidates as (
      select
        n.*,
        lower(coalesce(n.sulyossag, n.statusz, '')) as severity_text,
        lower(coalesce(n.statusz, '')) as status_text,
        lower(concat_ws(' ', n.potlas_tipus, n.csoport, n.hianyzo_tetel, n.reszletek, n.raw_requirement)) as search_text
      from normalized n
    )
    select
      (
        'workflow_missing:' ||
        coalesce(c.workflow_case_id, 'unknown') || ':' ||
        md5(
          coalesce(c.csoport, '') || '|' ||
          coalesce(c.hianyzo_tetel, '') || '|' ||
          coalesce(c.suggested_document_type_code, '') || '|' ||
          coalesce(c.raw_requirement, '')
        )
      )::text as alert_key,
      case
        when c.suggested_document_type_code is not null
          or c.search_text like '%dokument%'
          or c.search_text like '%document%'
        then 'missing_document'
        else 'workflow_blocker'
      end::text as category,
      case
        when c.severity_text in ('blocker', 'blocking', 'hard_missing', 'critical')
          or c.status_text like '%block%'
        then 'blocker'
        when c.severity_text in ('urgent', 'high')
        then 'urgent'
        when c.severity_text in ('info', 'ok')
        then 'info'
        else 'warning'
      end::text as severity,
      'workflow_case'::text as entity_type,
      c.workflow_case_id::text as entity_id,
      coalesce(c.hianyzo_tetel, c.raw_requirement, 'Missing workflow requirement')::text as title,
      concat_ws(
        ' | ',
        c.csoport,
        c.statusz,
        c.reszletek
      )::text as message,
      (
        c.row_json ||
        jsonb_build_object(
          'scanner', 'agent_v2_scan_workflow_blocker_alerts',
          'source_view', 'public.v_retool_workflow_missing_requirements',
          'normalized', jsonb_build_object(
            'workflow_case_id', c.workflow_case_id,
            'csoport', c.csoport,
            'hianyzo_tetel', c.hianyzo_tetel,
            'suggested_document_type_code', c.suggested_document_type_code,
            'potlas_tipus', c.potlas_tipus,
            'sulyossag', c.sulyossag,
            'statusz', c.statusz,
            'reszletek', c.reszletek,
            'raw_requirement', c.raw_requirement
          )
        )
      )::jsonb as payload,
      md5(
        coalesce(c.workflow_case_id, '') || '|' ||
        coalesce(c.csoport, '') || '|' ||
        coalesce(c.hianyzo_tetel, '') || '|' ||
        coalesce(c.suggested_document_type_code, '') || '|' ||
        coalesce(c.raw_requirement, '')
      )::text as dedupe_hash
    from candidates c
    where c.status_text not in ('resolved', 'closed', 'complete', 'completed', 'ok')
    order by
      case
        when c.severity_text in ('blocker', 'blocking', 'hard_missing', 'critical') then 1
        when c.severity_text in ('urgent', 'high') then 2
        when c.severity_text in ('warning', 'soft_warning') then 3
        else 4
      end,
      c.workflow_case_id nulls last,
      c.csoport nulls last,
      c.hianyzo_tetel nulls last
    limit $1
  $sql$ using v_limit;
end;
$function$;

comment on function public.agent_v2_scan_workflow_blocker_alerts(int)
is 'Read-only alert scanner using public.v_retool_workflow_missing_requirements when that view exists; otherwise returns zero rows.';

create or replace function public.agent_v2_scan_document_expiry_alerts(
  p_days int default 30,
  p_limit int default 100
)
returns table (
  alert_key text,
  category text,
  severity text,
  entity_type text,
  entity_id text,
  title text,
  message text,
  payload jsonb,
  dedupe_hash text
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 0), 365);
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 1000);
begin
  if to_regclass('public.v_retool_document_files') is not null
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'v_retool_document_files'
         and column_name = 'expiry_date'
     )
  then
    return query execute $sql$
      select
        ('document_expiry:' || d.document_file_id::text || ':' || d.expiry_date::text)::text as alert_key,
        'expiry'::text as category,
        case
          when d.expiry_date < current_date then 'blocker'
          when d.expiry_date <= current_date + 7 then 'urgent'
          else 'warning'
        end::text as severity,
        'document_file'::text as entity_type,
        d.document_file_id::text as entity_id,
        case
          when d.expiry_date < current_date then 'Document expired'
          when d.expiry_date <= current_date + 7 then 'Document expires within 7 days'
          else 'Document expires within alert window'
        end::text as title,
        (
          coalesce(nullif(d.document_name::text, ''), nullif(d.original_filename::text, ''), 'Document') ||
          ' expires on ' ||
          d.expiry_date::text
        )::text as message,
        (
          to_jsonb(d) ||
          jsonb_build_object(
            'scanner', 'agent_v2_scan_document_expiry_alerts',
            'source_view', 'public.v_retool_document_files',
            'days_until_expiry', d.expiry_date - current_date,
            'alert_window_days', $1::integer
          )
        )::jsonb as payload,
        md5(d.document_file_id::text || '|' || d.expiry_date::text)::text as dedupe_hash
      from public.v_retool_document_files d
      where d.expiry_date is not null
        and d.expiry_date <= current_date + $1::integer
        and coalesce(d.status::text, 'active') not in ('archived', 'rejected')
      order by d.expiry_date asc nulls last, d.uploaded_at desc nulls last
      limit $2
    $sql$ using v_days, v_limit;

    return;
  end if;

  if to_regclass('public.document_files') is not null
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'document_files'
         and column_name = 'expiry_date'
     )
     and exists (
       select 1
       from information_schema.columns
       where table_schema = 'public'
         and table_name = 'document_files'
         and column_name = 'id'
     )
  then
    return query execute $sql$
      select
        ('document_expiry:' || d.id::text || ':' || d.expiry_date::text)::text as alert_key,
        'expiry'::text as category,
        case
          when d.expiry_date < current_date then 'blocker'
          when d.expiry_date <= current_date + 7 then 'urgent'
          else 'warning'
        end::text as severity,
        'document_file'::text as entity_type,
        d.id::text as entity_id,
        case
          when d.expiry_date < current_date then 'Document expired'
          when d.expiry_date <= current_date + 7 then 'Document expires within 7 days'
          else 'Document expires within alert window'
        end::text as title,
        (
          coalesce(nullif(d.document_name::text, ''), nullif(d.original_filename::text, ''), 'Document') ||
          ' expires on ' ||
          d.expiry_date::text
        )::text as message,
        (
          to_jsonb(d) ||
          jsonb_build_object(
            'scanner', 'agent_v2_scan_document_expiry_alerts',
            'source_table', 'public.document_files',
            'days_until_expiry', d.expiry_date - current_date,
            'alert_window_days', $1::integer
          )
        )::jsonb as payload,
        md5(d.id::text || '|' || d.expiry_date::text)::text as dedupe_hash
      from public.document_files d
      where d.expiry_date is not null
        and d.expiry_date <= current_date + $1::integer
        and coalesce(d.status::text, 'active') not in ('archived', 'rejected')
        and d.archived_at is null
      order by d.expiry_date asc nulls last, d.uploaded_at desc nulls last
      limit $2
    $sql$ using v_days, v_limit;
  end if;
end;
$function$;

comment on function public.agent_v2_scan_document_expiry_alerts(int, int)
is 'Read-only alert scanner for central document expiry using v_retool_document_files when available, otherwise document_files.';

create or replace function public.agent_v2_alerts_preview(
  p_limit int default 100
)
returns table (
  alert_key text,
  category text,
  severity text,
  entity_type text,
  entity_id text,
  title text,
  message text,
  payload jsonb,
  dedupe_hash text
)
language plpgsql
security invoker
stable
set search_path = public
as $function$
declare
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 1000);
begin
  return query
  select candidate.alert_key,
         candidate.category,
         candidate.severity,
         candidate.entity_type,
         candidate.entity_id,
         candidate.title,
         candidate.message,
         candidate.payload,
         candidate.dedupe_hash
  from (
    select *
    from public.agent_v2_scan_action_request_alerts(v_limit)

    union all

    select *
    from public.agent_v2_scan_workflow_blocker_alerts(v_limit)

    union all

    select *
    from public.agent_v2_scan_document_expiry_alerts(30, v_limit)
  ) candidate
  order by
    case candidate.severity
      when 'blocker' then 1
      when 'urgent' then 2
      when 'warning' then 3
      else 4
    end,
    candidate.category,
    candidate.alert_key
  limit v_limit;
end;
$function$;

comment on function public.agent_v2_alerts_preview(int)
is 'Read-only union preview for Robot Barat proactive alert candidates. It does not insert/update alert events.';

do $$
declare
  v_role text;
begin
  foreach v_role in array array['authenticated', 'service_role'] loop
    if exists (select 1 from pg_roles where rolname = v_role) then
      execute format('grant execute on function public.agent_v2_scan_action_request_alerts(integer) to %I', v_role);
      execute format('grant execute on function public.agent_v2_scan_workflow_blocker_alerts(integer) to %I', v_role);
      execute format('grant execute on function public.agent_v2_scan_document_expiry_alerts(integer, integer) to %I', v_role);
      execute format('grant execute on function public.agent_v2_alerts_preview(integer) to %I', v_role);
    end if;
  end loop;
end $$;
