-- HDD / UAHUN central documents layer
-- Schema and index DDL only.

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
