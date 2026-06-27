-- HDD / UAHUN central documents layer
-- Source of truth migration. Safe to run repeatedly in Supabase SQL editor.

create extension if not exists pgcrypto;

create table if not exists public.document_types (
  document_type_id uuid primary key default gen_random_uuid(),
  document_type_code text not null,
  document_type_label text not null,
  document_category text not null default 'other',
  is_sensitive boolean not null default false,
  is_expiry_required boolean not null default false,
  label text,
  category text,
  description text,
  is_active boolean not null default true,
  requires_expiry boolean not null default false,
  default_storage_bucket text,
  sort_order integer not null default 100,
  metadata jsonb not null default '{}'::jsonb,
  created_by text,
  created_at timestamptz not null default now(),
  updated_by text,
  updated_at timestamptz not null default now()
);

alter table public.document_types add column if not exists document_type_id uuid default gen_random_uuid();
alter table public.document_types add column if not exists document_type_code text;
alter table public.document_types add column if not exists document_type_label text;
alter table public.document_types add column if not exists document_category text;
alter table public.document_types add column if not exists is_sensitive boolean default false;
alter table public.document_types add column if not exists is_expiry_required boolean default false;
alter table public.document_types add column if not exists label text;
alter table public.document_types add column if not exists category text;
alter table public.document_types add column if not exists description text;
alter table public.document_types add column if not exists is_active boolean not null default true;
alter table public.document_types add column if not exists requires_expiry boolean not null default false;
alter table public.document_types add column if not exists default_storage_bucket text;
alter table public.document_types add column if not exists sort_order integer not null default 100;
alter table public.document_types add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table public.document_types add column if not exists created_by text;
alter table public.document_types add column if not exists created_at timestamptz not null default now();
alter table public.document_types add column if not exists updated_by text;
alter table public.document_types add column if not exists updated_at timestamptz not null default now();

alter table public.document_types alter column document_type_label set default 'Other document';
alter table public.document_types alter column document_category set default 'other';
alter table public.document_types alter column document_type_id set default gen_random_uuid();
alter table public.document_types alter column is_sensitive set default false;
alter table public.document_types alter column is_expiry_required set default false;
alter table public.document_types alter column is_active set default true;
alter table public.document_types alter column sort_order set default 100;

create table if not exists public.document_files (
  document_file_id uuid primary key default gen_random_uuid(),
  document_name text not null,
  document_type_id uuid,
  document_type_code text,
  document_category text,
  status text not null default 'active',
  storage_provider text not null default 'supabase',
  storage_mode text not null default 'supabase_storage',
  storage_bucket text,
  storage_path text,
  storage_ref text,
  file_url text,
  external_url text,
  original_filename text,
  mime_type text,
  file_size_bytes bigint,
  file_hash_sha256 text,
  issue_date date,
  expiry_date date,
  source_module text,
  source_system text,
  source_context text,
  source_sheet_name text,
  source_row_number integer,
  source_column text,
  notes text,
  uploaded_by text,
  uploaded_at timestamptz not null default now(),
  created_by text,
  created_at timestamptz not null default now(),
  updated_by text,
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

alter table public.document_files add column if not exists document_file_id uuid default gen_random_uuid();
alter table public.document_files add column if not exists document_name text;
alter table public.document_files add column if not exists document_type_id uuid;
alter table public.document_files add column if not exists document_type_code text;
alter table public.document_files add column if not exists document_category text;
alter table public.document_files add column if not exists status text not null default 'active';
alter table public.document_files add column if not exists storage_provider text not null default 'supabase';
alter table public.document_files add column if not exists storage_mode text not null default 'supabase_storage';
alter table public.document_files add column if not exists storage_bucket text;
alter table public.document_files add column if not exists storage_path text;
alter table public.document_files add column if not exists storage_ref text;
alter table public.document_files add column if not exists file_url text;
alter table public.document_files add column if not exists external_url text;
alter table public.document_files add column if not exists original_filename text;
alter table public.document_files add column if not exists mime_type text;
alter table public.document_files add column if not exists file_size_bytes bigint;
alter table public.document_files add column if not exists file_hash_sha256 text;
alter table public.document_files add column if not exists issue_date date;
alter table public.document_files add column if not exists expiry_date date;
alter table public.document_files add column if not exists source_module text;
alter table public.document_files add column if not exists source_system text;
alter table public.document_files add column if not exists source_context text;
alter table public.document_files add column if not exists source_sheet_name text;
alter table public.document_files add column if not exists source_row_number integer;
alter table public.document_files add column if not exists source_column text;
alter table public.document_files add column if not exists notes text;
alter table public.document_files add column if not exists uploaded_by text;
alter table public.document_files add column if not exists uploaded_at timestamptz not null default now();
alter table public.document_files add column if not exists created_by text;
alter table public.document_files add column if not exists created_at timestamptz not null default now();
alter table public.document_files add column if not exists updated_by text;
alter table public.document_files add column if not exists updated_at timestamptz not null default now();
alter table public.document_files add column if not exists archived_at timestamptz;
alter table public.document_files add column if not exists metadata jsonb not null default '{}'::jsonb;

create table if not exists public.document_links (
  document_link_id uuid primary key default gen_random_uuid(),
  document_file_id uuid not null,
  entity_type text,
  entity_id uuid,
  workflow_case_id uuid,
  candidate_id uuid,
  assignment_id uuid,
  person_id uuid,
  application_id uuid,
  task_id uuid,
  document_requirement_id uuid,
  status text not null default 'active',
  is_primary boolean not null default false,
  confidence numeric(6,5),
  source_module text,
  source_context text,
  link_note text,
  created_by text,
  created_at timestamptz not null default now(),
  updated_by text,
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

alter table public.document_links add column if not exists document_link_id uuid default gen_random_uuid();
alter table public.document_links add column if not exists document_file_id uuid;
alter table public.document_links add column if not exists entity_type text;
alter table public.document_links add column if not exists entity_id uuid;
alter table public.document_links add column if not exists workflow_case_id uuid;
alter table public.document_links add column if not exists candidate_id uuid;
alter table public.document_links add column if not exists assignment_id uuid;
alter table public.document_links add column if not exists person_id uuid;
alter table public.document_links add column if not exists application_id uuid;
alter table public.document_links add column if not exists task_id uuid;
alter table public.document_links add column if not exists document_requirement_id uuid;
alter table public.document_links add column if not exists status text not null default 'active';
alter table public.document_links add column if not exists is_primary boolean not null default false;
alter table public.document_links add column if not exists confidence numeric(6,5);
alter table public.document_links add column if not exists source_module text;
alter table public.document_links add column if not exists source_context text;
alter table public.document_links add column if not exists link_note text;
alter table public.document_links add column if not exists created_by text;
alter table public.document_links add column if not exists created_at timestamptz not null default now();
alter table public.document_links add column if not exists updated_by text;
alter table public.document_links add column if not exists updated_at timestamptz not null default now();
alter table public.document_links add column if not exists archived_at timestamptz;
alter table public.document_links add column if not exists metadata jsonb not null default '{}'::jsonb;

create table if not exists public.document_intake_jobs (
  intake_job_id uuid primary key default gen_random_uuid(),
  document_file_id uuid,
  job_status text not null default 'queued',
  source_module text,
  source_context text,
  storage_bucket text,
  storage_path text,
  external_url text,
  original_filename text,
  mime_type text,
  file_size_bytes bigint,
  detected_document_type_code text,
  suggested_document_type_code text,
  suggested_workflow_case_id uuid,
  suggested_candidate_id uuid,
  suggested_assignment_id uuid,
  suggested_person_id uuid,
  confidence numeric(6,5),
  ocr_text_preview text,
  extracted_payload jsonb not null default '{}'::jsonb,
  error_message text,
  requested_by text,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

alter table public.document_intake_jobs add column if not exists intake_job_id uuid default gen_random_uuid();
alter table public.document_intake_jobs add column if not exists document_file_id uuid;
alter table public.document_intake_jobs add column if not exists job_status text not null default 'queued';
alter table public.document_intake_jobs add column if not exists source_module text;
alter table public.document_intake_jobs add column if not exists source_context text;
alter table public.document_intake_jobs add column if not exists storage_bucket text;
alter table public.document_intake_jobs add column if not exists storage_path text;
alter table public.document_intake_jobs add column if not exists external_url text;
alter table public.document_intake_jobs add column if not exists original_filename text;
alter table public.document_intake_jobs add column if not exists mime_type text;
alter table public.document_intake_jobs add column if not exists file_size_bytes bigint;
alter table public.document_intake_jobs add column if not exists detected_document_type_code text;
alter table public.document_intake_jobs add column if not exists suggested_document_type_code text;
alter table public.document_intake_jobs add column if not exists suggested_workflow_case_id uuid;
alter table public.document_intake_jobs add column if not exists suggested_candidate_id uuid;
alter table public.document_intake_jobs add column if not exists suggested_assignment_id uuid;
alter table public.document_intake_jobs add column if not exists suggested_person_id uuid;
alter table public.document_intake_jobs add column if not exists confidence numeric(6,5);
alter table public.document_intake_jobs add column if not exists ocr_text_preview text;
alter table public.document_intake_jobs add column if not exists extracted_payload jsonb not null default '{}'::jsonb;
alter table public.document_intake_jobs add column if not exists error_message text;
alter table public.document_intake_jobs add column if not exists requested_by text;
alter table public.document_intake_jobs add column if not exists started_at timestamptz;
alter table public.document_intake_jobs add column if not exists completed_at timestamptz;
alter table public.document_intake_jobs add column if not exists created_at timestamptz not null default now();
alter table public.document_intake_jobs add column if not exists updated_at timestamptz not null default now();
alter table public.document_intake_jobs add column if not exists metadata jsonb not null default '{}'::jsonb;

create table if not exists public.document_review_queue (
  review_queue_id uuid primary key default gen_random_uuid(),
  document_file_id uuid,
  intake_job_id uuid,
  review_status text not null default 'open',
  review_reason text,
  document_name text,
  suggested_document_type text,
  final_document_type text,
  suggested_workflow_case_id uuid,
  final_workflow_case_id uuid,
  suggested_candidate_id uuid,
  final_candidate_id uuid,
  suggested_assignment_id uuid,
  final_assignment_id uuid,
  suggested_person_id uuid,
  final_person_id uuid,
  confidence numeric(6,5),
  assigned_to text,
  reviewed_by text,
  reviewed_at timestamptz,
  source_module text,
  source_context text,
  storage_bucket text,
  storage_path text,
  original_filename text,
  mime_type text,
  file_size_bytes bigint,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

alter table public.document_review_queue add column if not exists review_queue_id uuid default gen_random_uuid();
alter table public.document_review_queue add column if not exists document_file_id uuid;
alter table public.document_review_queue add column if not exists intake_job_id uuid;
alter table public.document_review_queue add column if not exists review_status text not null default 'open';
alter table public.document_review_queue add column if not exists review_reason text;
alter table public.document_review_queue add column if not exists document_name text;
alter table public.document_review_queue add column if not exists suggested_document_type text;
alter table public.document_review_queue add column if not exists final_document_type text;
alter table public.document_review_queue add column if not exists suggested_workflow_case_id uuid;
alter table public.document_review_queue add column if not exists final_workflow_case_id uuid;
alter table public.document_review_queue add column if not exists suggested_candidate_id uuid;
alter table public.document_review_queue add column if not exists final_candidate_id uuid;
alter table public.document_review_queue add column if not exists suggested_assignment_id uuid;
alter table public.document_review_queue add column if not exists final_assignment_id uuid;
alter table public.document_review_queue add column if not exists suggested_person_id uuid;
alter table public.document_review_queue add column if not exists final_person_id uuid;
alter table public.document_review_queue add column if not exists confidence numeric(6,5);
alter table public.document_review_queue add column if not exists assigned_to text;
alter table public.document_review_queue add column if not exists reviewed_by text;
alter table public.document_review_queue add column if not exists reviewed_at timestamptz;
alter table public.document_review_queue add column if not exists source_module text;
alter table public.document_review_queue add column if not exists source_context text;
alter table public.document_review_queue add column if not exists storage_bucket text;
alter table public.document_review_queue add column if not exists storage_path text;
alter table public.document_review_queue add column if not exists original_filename text;
alter table public.document_review_queue add column if not exists mime_type text;
alter table public.document_review_queue add column if not exists file_size_bytes bigint;
alter table public.document_review_queue add column if not exists notes text;
alter table public.document_review_queue add column if not exists created_at timestamptz not null default now();
alter table public.document_review_queue add column if not exists updated_at timestamptz not null default now();
alter table public.document_review_queue add column if not exists metadata jsonb not null default '{}'::jsonb;

do $$
begin
  begin
    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.document_files'::regclass
        and conname = 'document_files_document_type_id_fkey'
    ) then
      alter table public.document_files
        add constraint document_files_document_type_id_fkey
        foreign key (document_type_id)
        references public.document_types(document_type_id)
        on delete set null;
    end if;
  exception when others then
    raise notice 'Skipped document_files_document_type_id_fkey: %', sqlerrm;
  end;

  begin
    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.document_links'::regclass
        and conname = 'document_links_document_file_id_fkey'
    ) then
      alter table public.document_links
        add constraint document_links_document_file_id_fkey
        foreign key (document_file_id)
        references public.document_files(document_file_id)
        on delete cascade;
    end if;
  exception when others then
    raise notice 'Skipped document_links_document_file_id_fkey: %', sqlerrm;
  end;

  begin
    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.document_intake_jobs'::regclass
        and conname = 'document_intake_jobs_document_file_id_fkey'
    ) then
      alter table public.document_intake_jobs
        add constraint document_intake_jobs_document_file_id_fkey
        foreign key (document_file_id)
        references public.document_files(document_file_id)
        on delete set null;
    end if;
  exception when others then
    raise notice 'Skipped document_intake_jobs_document_file_id_fkey: %', sqlerrm;
  end;

  begin
    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.document_review_queue'::regclass
        and conname = 'document_review_queue_document_file_id_fkey'
    ) then
      alter table public.document_review_queue
        add constraint document_review_queue_document_file_id_fkey
        foreign key (document_file_id)
        references public.document_files(document_file_id)
        on delete set null;
    end if;
  exception when others then
    raise notice 'Skipped document_review_queue_document_file_id_fkey: %', sqlerrm;
  end;

  begin
    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.document_review_queue'::regclass
        and conname = 'document_review_queue_intake_job_id_fkey'
    ) then
      alter table public.document_review_queue
        add constraint document_review_queue_intake_job_id_fkey
        foreign key (intake_job_id)
        references public.document_intake_jobs(intake_job_id)
        on delete set null;
    end if;
  exception when others then
    raise notice 'Skipped document_review_queue_intake_job_id_fkey: %', sqlerrm;
  end;
end $$;

create index if not exists idx_document_types_code_lower
  on public.document_types (lower(document_type_code));

create index if not exists idx_document_types_active
  on public.document_types (is_active, sort_order);

create index if not exists idx_document_files_type_code
  on public.document_files (document_type_code);

create index if not exists idx_document_files_status_uploaded
  on public.document_files (status, uploaded_at desc);

create index if not exists idx_document_files_storage_path
  on public.document_files (storage_bucket, storage_path)
  where storage_path is not null;

create index if not exists idx_document_files_file_hash
  on public.document_files (file_hash_sha256)
  where file_hash_sha256 is not null;

create index if not exists idx_document_files_source_context
  on public.document_files (source_module, source_context);

create index if not exists idx_document_links_file
  on public.document_links (document_file_id)
  where archived_at is null;

create index if not exists idx_document_links_entity
  on public.document_links (entity_type, entity_id)
  where archived_at is null;

create index if not exists idx_document_links_workflow_case
  on public.document_links (workflow_case_id)
  where archived_at is null;

create index if not exists idx_document_links_candidate
  on public.document_links (candidate_id)
  where archived_at is null;

create index if not exists idx_document_links_assignment
  on public.document_links (assignment_id)
  where archived_at is null;

create index if not exists idx_document_links_person
  on public.document_links (person_id)
  where archived_at is null;

create index if not exists idx_document_intake_jobs_status_created
  on public.document_intake_jobs (job_status, created_at desc);

create index if not exists idx_document_intake_jobs_document_file
  on public.document_intake_jobs (document_file_id);

create index if not exists idx_document_review_queue_status_created
  on public.document_review_queue (review_status, created_at desc);

create index if not exists idx_document_review_queue_document_file
  on public.document_review_queue (document_file_id);

create index if not exists idx_document_review_queue_intake_job
  on public.document_review_queue (intake_job_id);

create index if not exists idx_document_review_queue_suggested_workflow
  on public.document_review_queue (suggested_workflow_case_id);

create index if not exists idx_document_review_queue_final_workflow
  on public.document_review_queue (final_workflow_case_id);

do $$
declare
  r record;
  v_has_label boolean;
  v_has_category boolean;
  v_has_name boolean;
  v_has_document_type_name boolean;
  v_has_document_group boolean;
  v_has_requires_expiry boolean;
  v_has_metadata boolean;
  v_has_created_by boolean;
  v_has_created_at boolean;
  v_has_updated_by boolean;
  v_has_updated_at boolean;
  v_cols text[];
  v_vals text[];
  v_col_list text;
  v_val_list text;
begin
  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'label'
  ) into v_has_label;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'category'
  ) into v_has_category;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'name'
  ) into v_has_name;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'document_type_name'
  ) into v_has_document_type_name;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'document_group'
  ) into v_has_document_group;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'requires_expiry'
  ) into v_has_requires_expiry;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'metadata'
  ) into v_has_metadata;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'created_by'
  ) into v_has_created_by;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'created_at'
  ) into v_has_created_at;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'updated_by'
  ) into v_has_updated_by;

  select exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'document_types' and column_name = 'updated_at'
  ) into v_has_updated_at;

  update public.document_types
     set document_type_code = coalesce(nullif(btrim(document_type_code), ''), 'other'),
         document_type_label = coalesce(
           nullif(btrim(document_type_label), ''),
           nullif(btrim(label), ''),
           initcap(replace(coalesce(nullif(btrim(document_type_code), ''), 'other'), '_', ' '))
         ),
         document_category = coalesce(nullif(btrim(document_category), ''), nullif(btrim(category), ''), 'other'),
         is_sensitive = coalesce(is_sensitive, false),
         is_expiry_required = coalesce(is_expiry_required, requires_expiry, false),
         is_active = coalesce(is_active, true),
         sort_order = coalesce(sort_order, 100),
         description = coalesce(nullif(btrim(description), ''), nullif(btrim(document_type_label), ''), nullif(btrim(label), ''), 'Document type'),
         label = coalesce(nullif(btrim(label), ''), nullif(btrim(document_type_label), ''), initcap(replace(coalesce(nullif(btrim(document_type_code), ''), 'other'), '_', ' '))),
         category = coalesce(nullif(btrim(category), ''), nullif(btrim(document_category), ''), 'other'),
         requires_expiry = coalesce(requires_expiry, is_expiry_required, false)
   where document_type_code is null
      or nullif(btrim(document_type_code), '') is null
      or document_type_label is null
      or nullif(btrim(document_type_label), '') is null
      or document_category is null
      or nullif(btrim(document_category), '') is null
      or is_sensitive is null
      or is_expiry_required is null
      or is_active is null
      or sort_order is null
      or description is null
      or nullif(btrim(description), '') is null
      or label is null
      or nullif(btrim(label), '') is null
      or category is null
      or nullif(btrim(category), '') is null
      or requires_expiry is null;

  if v_has_name then
    execute 'update public.document_types set name = coalesce(nullif(btrim(name::text), ''''), document_type_label) where name is null or nullif(btrim(name::text), '''') is null';
  end if;

  if v_has_document_type_name then
    execute 'update public.document_types set document_type_name = coalesce(nullif(btrim(document_type_name::text), ''''), document_type_label) where document_type_name is null or nullif(btrim(document_type_name::text), '''') is null';
  end if;

  if v_has_document_group then
    execute 'update public.document_types set document_group = coalesce(nullif(btrim(document_group::text), ''''), document_category) where document_group is null or nullif(btrim(document_group::text), '''') is null';
  end if;

  for r in
    select *
    from (
      values
        ('passport', 'Passport', 'identity', false, true, true, 10, 'Passport or travel document.'),
        ('residence_permit', 'Residence permit', 'immigration', true, true, true, 20, 'Residence permit card or decision.'),
        ('employment_contract', 'Employment contract', 'employment', true, false, true, 30, 'Employment contract and amendments.'),
        ('oif_form', 'OIF form', 'immigration', true, false, true, 40, 'OIF / immigration form.'),
        ('eh_document', 'EH document', 'immigration', true, false, true, 50, 'Employment office document.'),
        ('taj_card', 'TAJ card', 'oep', true, false, true, 60, 'Hungarian TAJ card or TAJ related proof.'),
        ('tax_card', 'Tax card', 'nav', true, false, true, 70, 'Hungarian tax card or tax number proof.'),
        ('address_card', 'Address card', 'housing', true, false, true, 80, 'Address card or accommodation proof.'),
        ('medical_clearance', 'Medical clearance', 'medical', true, true, true, 90, 'Medical fitness or clearance document.'),
        ('housing_document', 'Housing document', 'housing', true, false, true, 100, 'Housing, lease, or accommodation document.'),
        ('nav_document', 'NAV document', 'nav', true, false, true, 110, 'NAV registration or tax document.'),
        ('bmh_document', 'BMH document', 'bmh', true, false, true, 120, 'BMH workflow document.'),
        ('oep_document', 'OEP document', 'oep', true, false, true, 130, 'OEP workflow document.'),
        ('other', 'Other document', 'other', false, false, true, 999, 'Fallback document type.')
    ) as seed(
      document_type_code,
      document_type_label,
      document_category,
      is_sensitive,
      is_expiry_required,
      is_active,
      sort_order,
      description
    )
  loop
    if exists (
      select 1
      from public.document_types dt
      where lower(dt.document_type_code) = lower(r.document_type_code)
    ) then
      update public.document_types
         set document_type_label = r.document_type_label,
             document_category = r.document_category,
             is_sensitive = r.is_sensitive,
             is_expiry_required = r.is_expiry_required,
             is_active = r.is_active,
             sort_order = r.sort_order,
             description = r.description,
             label = r.document_type_label,
             category = r.document_category,
             requires_expiry = r.is_expiry_required,
             updated_at = case when v_has_updated_at then now() else updated_at end
       where lower(document_type_code) = lower(r.document_type_code);

      if v_has_name then
        execute 'update public.document_types set name = $1 where lower(document_type_code) = lower($2)' using r.document_type_label, r.document_type_code;
      end if;

      if v_has_document_type_name then
        execute 'update public.document_types set document_type_name = $1 where lower(document_type_code) = lower($2)' using r.document_type_label, r.document_type_code;
      end if;

      if v_has_document_group then
        execute 'update public.document_types set document_group = $1 where lower(document_type_code) = lower($2)' using r.document_category, r.document_type_code;
      end if;
    else
      v_cols := array[
        'document_type_code',
        'document_type_label',
        'document_category',
        'is_sensitive',
        'is_expiry_required',
        'is_active',
        'sort_order',
        'description'
      ];
      v_vals := array['$1', '$2', '$3', '$4', '$5', '$6', '$7', '$8'];

      if v_has_label then
        v_cols := array_append(v_cols, 'label');
        v_vals := array_append(v_vals, '$2');
      end if;

      if v_has_category then
        v_cols := array_append(v_cols, 'category');
        v_vals := array_append(v_vals, '$3');
      end if;

      if v_has_name then
        v_cols := array_append(v_cols, 'name');
        v_vals := array_append(v_vals, '$2');
      end if;

      if v_has_document_type_name then
        v_cols := array_append(v_cols, 'document_type_name');
        v_vals := array_append(v_vals, '$2');
      end if;

      if v_has_document_group then
        v_cols := array_append(v_cols, 'document_group');
        v_vals := array_append(v_vals, '$3');
      end if;

      if v_has_requires_expiry then
        v_cols := array_append(v_cols, 'requires_expiry');
        v_vals := array_append(v_vals, '$5');
      end if;

      if v_has_metadata then
        v_cols := array_append(v_cols, 'metadata');
        v_vals := array_append(v_vals, '''{}''::jsonb');
      end if;

      if v_has_created_by then
        v_cols := array_append(v_cols, 'created_by');
        v_vals := array_append(v_vals, '''migration''');
      end if;

      if v_has_created_at then
        v_cols := array_append(v_cols, 'created_at');
        v_vals := array_append(v_vals, 'now()');
      end if;

      if v_has_updated_by then
        v_cols := array_append(v_cols, 'updated_by');
        v_vals := array_append(v_vals, '''migration''');
      end if;

      if v_has_updated_at then
        v_cols := array_append(v_cols, 'updated_at');
        v_vals := array_append(v_vals, 'now()');
      end if;

      select string_agg(quote_ident(col_name), ', ')
        into v_col_list
      from unnest(v_cols) as u(col_name);

      v_val_list := array_to_string(v_vals, ', ');

      execute format(
        'insert into public.document_types (%s) values (%s)',
        v_col_list,
        v_val_list
      )
      using
        r.document_type_code,
        r.document_type_label,
        r.document_category,
        r.is_sensitive,
        r.is_expiry_required,
        r.is_active,
        r.sort_order,
        r.description;
    end if;
  end loop;

  update public.document_types
     set document_type_label = coalesce(nullif(btrim(document_type_label), ''), initcap(replace(document_type_code, '_', ' ')), 'Other document'),
         document_category = coalesce(nullif(btrim(document_category), ''), 'other'),
         is_sensitive = coalesce(is_sensitive, false),
         is_expiry_required = coalesce(is_expiry_required, requires_expiry, false),
         is_active = coalesce(is_active, true),
         sort_order = coalesce(sort_order, 100),
         description = coalesce(nullif(btrim(description), ''), document_type_label, 'Document type'),
         label = coalesce(nullif(btrim(label), ''), document_type_label),
         category = coalesce(nullif(btrim(category), ''), document_category),
         requires_expiry = coalesce(requires_expiry, is_expiry_required, false);
end $$;

create or replace function public.fn_try_uuid(p_text text)
returns uuid
language plpgsql
immutable
as $function$
declare
  v_text text;
begin
  v_text := nullif(btrim(p_text), '');

  if v_text is null or lower(v_text) in ('null', 'undefined', 'nan') then
    return null;
  end if;

  return v_text::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$function$;

drop function if exists public.fn_create_document_with_context(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  bigint,
  text,
  text,
  text,
  jsonb,
  text
);

create or replace function public.fn_create_document_with_context(
  p_document_name text,
  p_document_type_code text default 'other',
  p_storage_bucket text default null,
  p_storage_path text default null,
  p_file_url text default null,
  p_original_filename text default null,
  p_mime_type text default null,
  p_file_size_bytes bigint default null,
  p_source_module text default 'documents',
  p_source_context text default 'master_document_hub',
  p_uploaded_by text default null,
  p_context jsonb default '{}'::jsonb,
  p_notes text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_context jsonb;
  v_document_file_id uuid;
  v_document_link_id uuid;
  v_review_queue_id uuid;
  v_document_type_id uuid;
  v_document_type_code text;
  v_document_category text;
  v_document_name text;
  v_storage_provider text;
  v_storage_mode text;
  v_storage_bucket text;
  v_storage_path text;
  v_storage_ref text;
  v_file_url text;
  v_external_url text;
  v_original_filename text;
  v_mime_type text;
  v_file_size_bytes bigint;
  v_file_size_text text;
  v_file_hash_sha256 text;
  v_issue_date date;
  v_issue_date_text text;
  v_expiry_date date;
  v_expiry_date_text text;
  v_source_module text;
  v_source_system text;
  v_source_context text;
  v_source_sheet_name text;
  v_source_row_number integer;
  v_source_row_number_text text;
  v_source_column text;
  v_uploaded_by text;
  v_notes text;
  v_workflow_case_id uuid;
  v_candidate_id uuid;
  v_assignment_id uuid;
  v_person_id uuid;
  v_application_id uuid;
  v_task_id uuid;
  v_document_requirement_id uuid;
  v_entity_type text;
  v_entity_id uuid;
  v_link_note text;
  v_has_context boolean;
  v_created_document_file boolean := false;
  v_created_document_link boolean := false;
  v_created_review_queue boolean := false;
begin
  v_context := coalesce(p_context, '{}'::jsonb);

  v_document_type_code := lower(
    coalesce(
      nullif(btrim(p_document_type_code), ''),
      nullif(btrim(v_context->>'document_type_code'), ''),
      nullif(btrim(v_context->>'documentTypeCode'), ''),
      'other'
    )
  );

  v_document_name := coalesce(
    nullif(btrim(p_document_name), ''),
    nullif(btrim(v_context->>'document_name'), ''),
    nullif(btrim(v_context->>'documentName'), ''),
    nullif(btrim(p_original_filename), ''),
    nullif(btrim(v_context->>'original_filename'), ''),
    nullif(btrim(v_context->>'originalFilename'), ''),
    'Untitled document'
  );

  insert into public.document_types (
    document_type_code,
    document_type_label,
    document_category,
    is_sensitive,
    is_expiry_required,
    is_active,
    sort_order,
    description,
    label,
    category,
    requires_expiry,
    created_by,
    updated_by
  )
  select
    v_document_type_code,
    initcap(replace(v_document_type_code, '_', ' ')),
    'other',
    false,
    false,
    true,
    100,
    'Auto-created by fn_create_document_with_context.',
    initcap(replace(v_document_type_code, '_', ' ')),
    'other',
    false,
    nullif(btrim(p_uploaded_by), ''),
    nullif(btrim(p_uploaded_by), '')
  where not exists (
    select 1
    from public.document_types dt
    where lower(dt.document_type_code) = lower(v_document_type_code)
  )
  returning document_type_id into v_document_type_id;

  if v_document_type_id is null then
    select dt.document_type_id, coalesce(dt.document_category, dt.category, 'other')
      into v_document_type_id, v_document_category
    from public.document_types dt
    where lower(dt.document_type_code) = lower(v_document_type_code)
    order by dt.is_active desc, dt.sort_order asc, dt.created_at asc
    limit 1;
  else
    select coalesce(dt.document_category, dt.category, 'other')
      into v_document_category
    from public.document_types dt
    where dt.document_type_id = v_document_type_id;
  end if;

  v_storage_provider := coalesce(
    nullif(btrim(v_context->>'storage_provider'), ''),
    nullif(btrim(v_context->>'storageProvider'), ''),
    'supabase'
  );

  v_storage_bucket := coalesce(
    nullif(btrim(p_storage_bucket), ''),
    nullif(btrim(v_context->>'storage_bucket'), ''),
    nullif(btrim(v_context->>'storageBucket'), ''),
    'company_documents'
  );

  v_storage_path := coalesce(
    nullif(btrim(p_storage_path), ''),
    nullif(btrim(v_context->>'storage_path'), ''),
    nullif(btrim(v_context->>'storagePath'), '')
  );

  v_file_url := coalesce(
    nullif(btrim(p_file_url), ''),
    nullif(btrim(v_context->>'file_url'), ''),
    nullif(btrim(v_context->>'fileUrl'), '')
  );

  v_external_url := coalesce(
    nullif(btrim(v_context->>'external_url'), ''),
    nullif(btrim(v_context->>'externalUrl'), '')
  );

  if v_file_url is null and v_external_url is not null then
    v_file_url := v_external_url;
  end if;

  v_storage_mode := coalesce(
    nullif(btrim(v_context->>'storage_mode'), ''),
    nullif(btrim(v_context->>'storageMode'), ''),
    case
      when v_storage_path is not null then 'supabase_storage'
      when v_file_url is not null or v_external_url is not null then 'external_url'
      else 'metadata_only'
    end
  );

  v_storage_ref := coalesce(
    nullif(btrim(v_context->>'storage_ref'), ''),
    nullif(btrim(v_context->>'storageRef'), ''),
    case
      when v_storage_bucket is not null and v_storage_path is not null
      then v_storage_bucket || '/' || v_storage_path
      else null
    end
  );

  v_original_filename := coalesce(
    nullif(btrim(p_original_filename), ''),
    nullif(btrim(v_context->>'original_filename'), ''),
    nullif(btrim(v_context->>'originalFilename'), '')
  );

  v_mime_type := coalesce(
    nullif(btrim(p_mime_type), ''),
    nullif(btrim(v_context->>'mime_type'), ''),
    nullif(btrim(v_context->>'mimeType'), '')
  );

  v_file_size_bytes := p_file_size_bytes;
  if v_file_size_bytes is null then
    v_file_size_text := nullif(
      btrim(coalesce(v_context->>'file_size_bytes', v_context->>'fileSizeBytes')),
      ''
    );
    if v_file_size_text ~ '^[0-9]+$' then
      v_file_size_bytes := v_file_size_text::bigint;
    end if;
  end if;

  v_file_hash_sha256 := coalesce(
    nullif(btrim(v_context->>'file_hash_sha256'), ''),
    nullif(btrim(v_context->>'fileHashSha256'), ''),
    nullif(btrim(v_context->>'sha256'), '')
  );

  v_issue_date_text := nullif(
    btrim(coalesce(v_context->>'issue_date', v_context->>'issueDate')),
    ''
  );
  if v_issue_date_text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    begin
      v_issue_date := v_issue_date_text::date;
    exception when others then
      v_issue_date := null;
    end;
  end if;

  v_expiry_date_text := nullif(
    btrim(coalesce(v_context->>'expiry_date', v_context->>'expiryDate', v_context->>'expires_at', v_context->>'expiresAt')),
    ''
  );
  if v_expiry_date_text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    begin
      v_expiry_date := v_expiry_date_text::date;
    exception when others then
      v_expiry_date := null;
    end;
  end if;

  v_source_module := coalesce(
    nullif(btrim(p_source_module), ''),
    nullif(btrim(v_context->>'source_module'), ''),
    nullif(btrim(v_context->>'sourceModule'), ''),
    'documents'
  );

  v_source_system := coalesce(
    nullif(btrim(v_context->>'source_system'), ''),
    nullif(btrim(v_context->>'sourceSystem'), ''),
    'retool'
  );

  v_source_context := coalesce(
    nullif(btrim(p_source_context), ''),
    nullif(btrim(v_context->>'source_context'), ''),
    nullif(btrim(v_context->>'sourceContext'), ''),
    'master_document_hub'
  );

  v_source_sheet_name := coalesce(
    nullif(btrim(v_context->>'source_sheet_name'), ''),
    nullif(btrim(v_context->>'sourceSheetName'), '')
  );

  v_source_row_number_text := nullif(
    btrim(coalesce(v_context->>'source_row_number', v_context->>'sourceRowNumber')),
    ''
  );
  if v_source_row_number_text ~ '^[0-9]+$' then
    v_source_row_number := v_source_row_number_text::integer;
  end if;

  v_source_column := coalesce(
    nullif(btrim(v_context->>'source_column'), ''),
    nullif(btrim(v_context->>'sourceColumn'), '')
  );

  v_uploaded_by := coalesce(
    nullif(btrim(p_uploaded_by), ''),
    nullif(btrim(v_context->>'uploaded_by'), ''),
    nullif(btrim(v_context->>'uploadedBy'), ''),
    'Retool'
  );

  v_notes := coalesce(
    nullif(btrim(p_notes), ''),
    nullif(btrim(v_context->>'notes'), '')
  );

  v_workflow_case_id := public.fn_try_uuid(coalesce(
    v_context->>'workflow_case_id',
    v_context->>'workflowCaseId',
    v_context->>'case_id',
    v_context->>'caseId'
  ));
  v_candidate_id := public.fn_try_uuid(coalesce(v_context->>'candidate_id', v_context->>'candidateId'));
  v_assignment_id := public.fn_try_uuid(coalesce(v_context->>'assignment_id', v_context->>'assignmentId'));
  v_person_id := public.fn_try_uuid(coalesce(v_context->>'person_id', v_context->>'personId'));
  v_application_id := public.fn_try_uuid(coalesce(v_context->>'application_id', v_context->>'applicationId', v_context->>'request_id', v_context->>'requestId'));
  v_task_id := public.fn_try_uuid(coalesce(v_context->>'task_id', v_context->>'taskId'));
  v_document_requirement_id := public.fn_try_uuid(coalesce(v_context->>'document_requirement_id', v_context->>'documentRequirementId'));

  v_entity_type := coalesce(
    nullif(btrim(v_context->>'entity_type'), ''),
    nullif(btrim(v_context->>'entityType'), ''),
    case
      when v_workflow_case_id is not null then 'workflow_case'
      when v_candidate_id is not null then 'candidate'
      when v_assignment_id is not null then 'assignment'
      when v_person_id is not null then 'person'
      when v_application_id is not null then 'application'
      when v_task_id is not null then 'task'
      else null
    end
  );

  v_entity_id := coalesce(
    public.fn_try_uuid(coalesce(v_context->>'entity_id', v_context->>'entityId')),
    v_workflow_case_id,
    v_candidate_id,
    v_assignment_id,
    v_person_id,
    v_application_id,
    v_task_id
  );

  v_link_note := coalesce(
    nullif(btrim(v_context->>'link_note'), ''),
    nullif(btrim(v_context->>'linkNote'), ''),
    v_source_context
  );

  v_has_context :=
    v_entity_id is not null
    or v_workflow_case_id is not null
    or v_candidate_id is not null
    or v_assignment_id is not null
    or v_person_id is not null
    or v_application_id is not null
    or v_task_id is not null
    or v_document_requirement_id is not null;

  select d.document_file_id
    into v_document_file_id
  from public.document_files d
  where d.archived_at is null
    and (
      (v_storage_bucket is not null and v_storage_path is not null and d.storage_bucket = v_storage_bucket and d.storage_path = v_storage_path)
      or (v_file_hash_sha256 is not null and d.file_hash_sha256 = v_file_hash_sha256)
      or (v_file_url is not null and d.file_url = v_file_url)
      or (v_external_url is not null and d.external_url = v_external_url)
    )
  order by d.created_at asc nulls last, d.document_file_id
  limit 1;

  if v_document_file_id is null then
    insert into public.document_files (
      document_name,
      document_type_id,
      document_type_code,
      document_category,
      status,
      storage_provider,
      storage_mode,
      storage_bucket,
      storage_path,
      storage_ref,
      file_url,
      external_url,
      original_filename,
      mime_type,
      file_size_bytes,
      file_hash_sha256,
      issue_date,
      expiry_date,
      source_module,
      source_system,
      source_context,
      source_sheet_name,
      source_row_number,
      source_column,
      notes,
      uploaded_by,
      uploaded_at,
      created_by,
      updated_by,
      metadata
    )
    values (
      v_document_name,
      v_document_type_id,
      v_document_type_code,
      v_document_category,
      'active',
      v_storage_provider,
      v_storage_mode,
      v_storage_bucket,
      v_storage_path,
      v_storage_ref,
      v_file_url,
      v_external_url,
      v_original_filename,
      v_mime_type,
      v_file_size_bytes,
      v_file_hash_sha256,
      v_issue_date,
      v_expiry_date,
      v_source_module,
      v_source_system,
      v_source_context,
      v_source_sheet_name,
      v_source_row_number,
      v_source_column,
      v_notes,
      v_uploaded_by,
      now(),
      v_uploaded_by,
      v_uploaded_by,
      jsonb_build_object('context', v_context)
    )
    returning document_file_id into v_document_file_id;

    v_created_document_file := true;
  else
    update public.document_files
       set document_name = coalesce(nullif(public.document_files.document_name, ''), v_document_name),
           document_type_id = coalesce(public.document_files.document_type_id, v_document_type_id),
           document_type_code = coalesce(nullif(public.document_files.document_type_code, ''), v_document_type_code),
           document_category = coalesce(nullif(public.document_files.document_category, ''), v_document_category),
           storage_provider = coalesce(nullif(public.document_files.storage_provider, ''), v_storage_provider),
           storage_mode = coalesce(nullif(public.document_files.storage_mode, ''), v_storage_mode),
           storage_bucket = coalesce(nullif(public.document_files.storage_bucket, ''), v_storage_bucket),
           storage_path = coalesce(nullif(public.document_files.storage_path, ''), v_storage_path),
           storage_ref = coalesce(nullif(public.document_files.storage_ref, ''), v_storage_ref),
           file_url = coalesce(nullif(public.document_files.file_url, ''), v_file_url),
           external_url = coalesce(nullif(public.document_files.external_url, ''), v_external_url),
           original_filename = coalesce(nullif(public.document_files.original_filename, ''), v_original_filename),
           mime_type = coalesce(nullif(public.document_files.mime_type, ''), v_mime_type),
           file_size_bytes = coalesce(public.document_files.file_size_bytes, v_file_size_bytes),
           file_hash_sha256 = coalesce(nullif(public.document_files.file_hash_sha256, ''), v_file_hash_sha256),
           issue_date = coalesce(public.document_files.issue_date, v_issue_date),
           expiry_date = coalesce(public.document_files.expiry_date, v_expiry_date),
           source_module = coalesce(nullif(public.document_files.source_module, ''), v_source_module),
           source_system = coalesce(nullif(public.document_files.source_system, ''), v_source_system),
           source_context = coalesce(nullif(public.document_files.source_context, ''), v_source_context),
           source_sheet_name = coalesce(nullif(public.document_files.source_sheet_name, ''), v_source_sheet_name),
           source_row_number = coalesce(public.document_files.source_row_number, v_source_row_number),
           source_column = coalesce(nullif(public.document_files.source_column, ''), v_source_column),
           notes = coalesce(nullif(public.document_files.notes, ''), v_notes),
           updated_by = v_uploaded_by,
           updated_at = now()
     where public.document_files.document_file_id = v_document_file_id;
  end if;

  if v_has_context then
    select l.document_link_id
      into v_document_link_id
    from public.document_links l
    where l.archived_at is null
      and l.document_file_id = v_document_file_id
      and coalesce(l.entity_type, '') = coalesce(v_entity_type, '')
      and l.entity_id is not distinct from v_entity_id
      and l.workflow_case_id is not distinct from v_workflow_case_id
      and l.candidate_id is not distinct from v_candidate_id
      and l.assignment_id is not distinct from v_assignment_id
      and l.person_id is not distinct from v_person_id
      and l.application_id is not distinct from v_application_id
      and l.task_id is not distinct from v_task_id
      and l.document_requirement_id is not distinct from v_document_requirement_id
    order by l.created_at asc nulls last, l.document_link_id
    limit 1;

    if v_document_link_id is null then
      insert into public.document_links (
        document_file_id,
        entity_type,
        entity_id,
        workflow_case_id,
        candidate_id,
        assignment_id,
        person_id,
        application_id,
        task_id,
        document_requirement_id,
        status,
        is_primary,
        source_module,
        source_context,
        link_note,
        created_by,
        updated_by,
        metadata
      )
      values (
        v_document_file_id,
        v_entity_type,
        v_entity_id,
        v_workflow_case_id,
        v_candidate_id,
        v_assignment_id,
        v_person_id,
        v_application_id,
        v_task_id,
        v_document_requirement_id,
        'active',
        true,
        v_source_module,
        v_source_context,
        v_link_note,
        v_uploaded_by,
        v_uploaded_by,
        jsonb_build_object('context', v_context)
      )
      returning document_link_id into v_document_link_id;

      v_created_document_link := true;
    end if;
  else
    select rq.review_queue_id
      into v_review_queue_id
    from public.document_review_queue rq
    where rq.document_file_id = v_document_file_id
      and rq.review_status = 'open'
    order by rq.created_at asc nulls last, rq.review_queue_id
    limit 1;

    if v_review_queue_id is null then
      insert into public.document_review_queue (
        document_file_id,
        review_status,
        review_reason,
        document_name,
        suggested_document_type,
        source_module,
        source_context,
        storage_bucket,
        storage_path,
        original_filename,
        mime_type,
        file_size_bytes,
        notes,
        metadata
      )
      values (
        v_document_file_id,
        'open',
        'missing_context',
        v_document_name,
        v_document_type_code,
        v_source_module,
        v_source_context,
        v_storage_bucket,
        v_storage_path,
        v_original_filename,
        v_mime_type,
        v_file_size_bytes,
        v_notes,
        jsonb_build_object('context', v_context)
      )
      returning review_queue_id into v_review_queue_id;

      v_created_review_queue := true;
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'document_file_id', v_document_file_id,
    'document_link_id', v_document_link_id,
    'review_queue_id', v_review_queue_id,
    'created_document_file', v_created_document_file,
    'created_document_link', v_created_document_link,
    'created_review_queue', v_created_review_queue,
    'has_context', v_has_context,
    'document_type_code', v_document_type_code,
    'source_module', v_source_module,
    'source_context', v_source_context
  );
end;
$function$;

drop view if exists public.v_document_review_queue cascade;
drop view if exists public.v_document_intake_pipeline cascade;
drop view if exists public.v_retool_workflow_documents_central cascade;
drop view if exists public.v_retool_document_files cascade;

create view public.v_retool_document_files as
select
  d.document_file_id,
  d.document_name,
  d.document_type_id,
  d.document_type_code,
  coalesce(dt.document_type_label, dt.label, initcap(replace(d.document_type_code, '_', ' ')), 'Other document') as document_type_label,
  coalesce(d.document_category, dt.document_category, dt.category, 'other') as document_category,
  d.status,
  case
    when d.status = 'active' then 'Active'
    when d.status = 'archived' then 'Archived'
    when d.status = 'rejected' then 'Rejected'
    when d.status = 'pending_review' then 'Pending review'
    else coalesce(d.status, 'unknown')
  end as status_label,
  d.storage_provider,
  d.storage_mode,
  case
    when d.storage_mode = 'supabase_storage' then 'Supabase Storage'
    when d.storage_mode = 'external_url' then 'External URL'
    when d.storage_mode = 'metadata_only' then 'Metadata only'
    else coalesce(d.storage_mode, 'unknown')
  end as storage_mode_label,
  d.storage_bucket,
  d.storage_path,
  coalesce(
    d.storage_ref,
    case
      when d.storage_bucket is not null and d.storage_path is not null
      then d.storage_bucket || '/' || d.storage_path
      else null
    end
  ) as storage_ref,
  d.file_url,
  d.external_url,
  d.original_filename,
  d.mime_type,
  d.file_size_bytes,
  d.file_hash_sha256,
  d.issue_date,
  d.expiry_date,
  case
    when d.expiry_date is null then 'No expiry'
    when d.expiry_date < current_date then 'Expired'
    when d.expiry_date <= current_date + 30 then 'Expires soon'
    else 'Valid'
  end as expiry_status_label,
  case
    when d.expiry_date is null then false
    else d.expiry_date < current_date
  end as is_expired,
  coalesce(link_stats.link_count, 0) as link_count,
  coalesce(link_stats.linked_entity_types, array[]::text[]) as linked_entity_types,
  d.source_module,
  d.source_system,
  d.source_context,
  d.source_sheet_name,
  d.source_row_number,
  d.source_column,
  d.notes,
  d.uploaded_by,
  d.uploaded_at,
  d.created_by,
  d.created_at,
  d.updated_by,
  d.updated_at,
  d.archived_at
from public.document_files d
left join public.document_types dt
  on dt.document_type_id = d.document_type_id
  or lower(dt.document_type_code) = lower(d.document_type_code)
left join lateral (
  select
    count(*)::integer as link_count,
    array_remove(array_agg(distinct l.entity_type), null) as linked_entity_types
  from public.document_links l
  where l.document_file_id = d.document_file_id
    and l.archived_at is null
) link_stats on true
where d.archived_at is null;

do $$
begin
  if to_regclass('public.v_retool_workflow_detail_core') is not null then
    execute $view$
      create view public.v_retool_workflow_documents_central as
      select
        d.document_file_id as document_id,
        d.document_file_id,
        l.document_link_id,
        l.document_requirement_id,
        l.workflow_case_id,
        coalesce(l.candidate_id, public.fn_try_uuid(to_jsonb(v)->>'candidate_id')) as candidate_id,
        coalesce(l.application_id, public.fn_try_uuid(coalesce(to_jsonb(v)->>'application_id', to_jsonb(v)->>'request_id'))) as application_id,
        coalesce(l.assignment_id, public.fn_try_uuid(to_jsonb(v)->>'assignment_id')) as assignment_id,
        coalesce(l.person_id, public.fn_try_uuid(to_jsonb(v)->>'person_id')) as person_id,
        l.task_id,
        coalesce(d.document_type_code, dt.document_type_code, 'other') as document_type,
        coalesce(d.document_type_code, dt.document_type_code, 'other') as document_type_code,
        coalesce(dt.document_type_label, dt.label, initcap(replace(coalesce(d.document_type_code, 'other'), '_', ' ')), 'Other document') as document_type_label,
        coalesce(d.document_category, dt.document_category, dt.category, 'other') as document_category,
        d.document_name as title,
        d.document_name,
        d.status,
        case
          when d.status = 'active' then 'Active'
          when d.status = 'archived' then 'Archived'
          when d.status = 'rejected' then 'Rejected'
          when d.status = 'pending_review' then 'Pending review'
          else coalesce(d.status, 'unknown')
        end as status_label,
        (l.document_requirement_id is not null) as is_required,
        d.expiry_date as due_date,
        d.storage_provider,
        d.storage_mode,
        case
          when d.storage_mode = 'supabase_storage' then 'Supabase Storage'
          when d.storage_mode = 'external_url' then 'External URL'
          when d.storage_mode = 'metadata_only' then 'Metadata only'
          else coalesce(d.storage_mode, 'unknown')
        end as storage_mode_label,
        d.storage_bucket,
        d.storage_path,
        coalesce(
          d.storage_ref,
          case
            when d.storage_bucket is not null and d.storage_path is not null
            then d.storage_bucket || '/' || d.storage_path
            else null
          end
        ) as storage_ref,
        d.file_url,
        d.external_url,
        d.original_filename,
        d.mime_type,
        d.file_size_bytes,
        d.file_hash_sha256,
        d.issue_date,
        d.expiry_date,
        case
          when d.expiry_date is null then 'No expiry'
          when d.expiry_date < current_date then 'Expired'
          when d.expiry_date <= current_date + 30 then 'Expires soon'
          else 'Valid'
        end as expiry_status_label,
        case
          when d.expiry_date is null then false
          else d.expiry_date < current_date
        end as is_expired,
        d.source_module,
        d.source_system,
        d.source_context,
        d.source_sheet_name,
        d.source_row_number,
        d.source_column,
        d.uploaded_by,
        d.uploaded_at,
        d.created_by,
        greatest(d.created_at, l.created_at) as created_at,
        d.updated_by,
        greatest(d.updated_at, l.updated_at) as updated_at,
        coalesce(to_jsonb(v)->>'workflow_code', to_jsonb(v)->>'case_code') as workflow_code,
        nullif(
          coalesce(
            to_jsonb(v)->>'full_name',
            to_jsonb(v)->>'candidate_full_name',
            to_jsonb(v)->>'employee_name',
            concat_ws(' ', nullif(to_jsonb(v)->>'last_name', ''), nullif(to_jsonb(v)->>'first_name', ''))
          ),
          ''
        ) as full_name
      from public.document_links l
      join public.document_files d
        on d.document_file_id = l.document_file_id
      left join public.document_types dt
        on dt.document_type_id = d.document_type_id
        or lower(dt.document_type_code) = lower(d.document_type_code)
      left join public.v_retool_workflow_detail_core v
        on public.fn_try_uuid(to_jsonb(v)->>'workflow_case_id') = l.workflow_case_id
      where l.archived_at is null
        and d.archived_at is null
        and l.workflow_case_id is not null
    $view$;
  else
    execute $view$
      create view public.v_retool_workflow_documents_central as
      select
        d.document_file_id as document_id,
        d.document_file_id,
        l.document_link_id,
        l.document_requirement_id,
        l.workflow_case_id,
        l.candidate_id,
        l.application_id,
        l.assignment_id,
        l.person_id,
        l.task_id,
        coalesce(d.document_type_code, dt.document_type_code, 'other') as document_type,
        coalesce(d.document_type_code, dt.document_type_code, 'other') as document_type_code,
        coalesce(dt.document_type_label, dt.label, initcap(replace(coalesce(d.document_type_code, 'other'), '_', ' ')), 'Other document') as document_type_label,
        coalesce(d.document_category, dt.document_category, dt.category, 'other') as document_category,
        d.document_name as title,
        d.document_name,
        d.status,
        case
          when d.status = 'active' then 'Active'
          when d.status = 'archived' then 'Archived'
          when d.status = 'rejected' then 'Rejected'
          when d.status = 'pending_review' then 'Pending review'
          else coalesce(d.status, 'unknown')
        end as status_label,
        (l.document_requirement_id is not null) as is_required,
        d.expiry_date as due_date,
        d.storage_provider,
        d.storage_mode,
        case
          when d.storage_mode = 'supabase_storage' then 'Supabase Storage'
          when d.storage_mode = 'external_url' then 'External URL'
          when d.storage_mode = 'metadata_only' then 'Metadata only'
          else coalesce(d.storage_mode, 'unknown')
        end as storage_mode_label,
        d.storage_bucket,
        d.storage_path,
        coalesce(
          d.storage_ref,
          case
            when d.storage_bucket is not null and d.storage_path is not null
            then d.storage_bucket || '/' || d.storage_path
            else null
          end
        ) as storage_ref,
        d.file_url,
        d.external_url,
        d.original_filename,
        d.mime_type,
        d.file_size_bytes,
        d.file_hash_sha256,
        d.issue_date,
        d.expiry_date,
        case
          when d.expiry_date is null then 'No expiry'
          when d.expiry_date < current_date then 'Expired'
          when d.expiry_date <= current_date + 30 then 'Expires soon'
          else 'Valid'
        end as expiry_status_label,
        case
          when d.expiry_date is null then false
          else d.expiry_date < current_date
        end as is_expired,
        d.source_module,
        d.source_system,
        d.source_context,
        d.source_sheet_name,
        d.source_row_number,
        d.source_column,
        d.uploaded_by,
        d.uploaded_at,
        d.created_by,
        greatest(d.created_at, l.created_at) as created_at,
        d.updated_by,
        greatest(d.updated_at, l.updated_at) as updated_at,
        null::text as workflow_code,
        null::text as full_name
      from public.document_links l
      join public.document_files d
        on d.document_file_id = l.document_file_id
      left join public.document_types dt
        on dt.document_type_id = d.document_type_id
        or lower(dt.document_type_code) = lower(d.document_type_code)
      where l.archived_at is null
        and d.archived_at is null
        and l.workflow_case_id is not null
    $view$;
  end if;
end $$;

create view public.v_document_intake_pipeline as
select
  ij.intake_job_id,
  ij.document_file_id,
  d.document_name,
  coalesce(ij.detected_document_type_code, d.document_type_code) as detected_document_type_code,
  ij.suggested_document_type_code,
  coalesce(sdt.document_type_label, sdt.label, initcap(replace(ij.suggested_document_type_code, '_', ' '))) as suggested_document_type_label,
  ij.job_status,
  case
    when ij.job_status = 'queued' then 'Queued'
    when ij.job_status = 'processing' then 'Processing'
    when ij.job_status = 'needs_review' then 'Needs review'
    when ij.job_status = 'completed' then 'Completed'
    when ij.job_status = 'failed' then 'Failed'
    else coalesce(ij.job_status, 'unknown')
  end as job_status_label,
  ij.source_module,
  ij.source_context,
  coalesce(ij.storage_bucket, d.storage_bucket) as storage_bucket,
  coalesce(ij.storage_path, d.storage_path) as storage_path,
  coalesce(ij.external_url, d.external_url, d.file_url) as external_url,
  coalesce(ij.original_filename, d.original_filename) as original_filename,
  coalesce(ij.mime_type, d.mime_type) as mime_type,
  coalesce(ij.file_size_bytes, d.file_size_bytes) as file_size_bytes,
  ij.suggested_workflow_case_id,
  ij.suggested_candidate_id,
  ij.suggested_assignment_id,
  ij.suggested_person_id,
  ij.confidence,
  ij.ocr_text_preview,
  ij.extracted_payload,
  ij.error_message,
  ij.requested_by,
  ij.started_at,
  ij.completed_at,
  ij.created_at,
  ij.updated_at,
  coalesce(review_stats.open_review_count, 0) as open_review_count,
  ij.metadata
from public.document_intake_jobs ij
left join public.document_files d
  on d.document_file_id = ij.document_file_id
left join public.document_types sdt
  on lower(sdt.document_type_code) = lower(ij.suggested_document_type_code)
left join lateral (
  select count(*)::integer as open_review_count
  from public.document_review_queue rq
  where rq.intake_job_id = ij.intake_job_id
    and rq.review_status in ('open', 'needs_review', 'needs_more_info')
) review_stats on true;

create view public.v_document_review_queue as
select
  rq.review_queue_id,
  rq.document_file_id,
  rq.intake_job_id,
  rq.review_status,
  case
    when rq.review_status = 'open' then 'Open'
    when rq.review_status = 'needs_review' then 'Needs review'
    when rq.review_status = 'needs_more_info' then 'Needs more info'
    when rq.review_status = 'approved' then 'Approved'
    when rq.review_status = 'linked' then 'Linked'
    when rq.review_status = 'closed' then 'Closed'
    when rq.review_status = 'rejected' then 'Rejected'
    when rq.review_status = 'archived' then 'Archived'
    else coalesce(rq.review_status, 'unknown')
  end as review_status_label,
  rq.review_reason,
  coalesce(rq.document_name, d.document_name) as document_name,
  rq.suggested_document_type,
  coalesce(sdt.document_type_label, sdt.label, initcap(replace(rq.suggested_document_type, '_', ' '))) as suggested_document_type_label,
  rq.final_document_type,
  coalesce(fdt.document_type_label, fdt.label, initcap(replace(rq.final_document_type, '_', ' '))) as final_document_type_label,
  rq.suggested_workflow_case_id,
  rq.final_workflow_case_id,
  rq.suggested_candidate_id,
  rq.final_candidate_id,
  rq.suggested_assignment_id,
  rq.final_assignment_id,
  rq.suggested_person_id,
  rq.final_person_id,
  rq.confidence,
  rq.assigned_to,
  rq.reviewed_by,
  rq.reviewed_at,
  coalesce(rq.source_module, d.source_module) as source_module,
  coalesce(rq.source_context, d.source_context) as source_context,
  coalesce(rq.storage_bucket, d.storage_bucket) as storage_bucket,
  coalesce(rq.storage_path, d.storage_path) as storage_path,
  coalesce(rq.original_filename, d.original_filename) as original_filename,
  coalesce(rq.mime_type, d.mime_type) as mime_type,
  coalesce(rq.file_size_bytes, d.file_size_bytes) as file_size_bytes,
  d.file_url,
  d.external_url,
  d.uploaded_by,
  d.uploaded_at,
  rq.notes,
  rq.created_at,
  rq.updated_at,
  rq.metadata
from public.document_review_queue rq
left join public.document_files d
  on d.document_file_id = rq.document_file_id
left join public.document_types sdt
  on lower(sdt.document_type_code) = lower(rq.suggested_document_type)
left join public.document_types fdt
  on lower(fdt.document_type_code) = lower(rq.final_document_type);
