-- HDD / UAHUN central documents layer
-- Schema and index DDL only.

create extension if not exists pgcrypto;

create table if not exists public.document_types (
  document_type_id uuid primary key default gen_random_uuid(),
  document_type_code text not null,
  label text not null,
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

insert into public.document_types (
  document_type_code,
  label,
  category,
  description,
  requires_expiry,
  sort_order
)
select seed.document_type_code, seed.label, seed.category, seed.description, seed.requires_expiry, seed.sort_order
from (
  values
    ('passport', 'Passport', 'identity', 'Passport or travel document.', true, 10),
    ('residence_permit', 'Residence permit', 'immigration', 'Residence permit card or decision.', true, 20),
    ('employment_contract', 'Employment contract', 'employment', 'Employment contract and amendments.', false, 30),
    ('oif_form', 'OIF form', 'immigration', 'OIF / immigration form.', false, 40),
    ('eh_document', 'EH document', 'immigration', 'Employment office document.', false, 50),
    ('taj_card', 'TAJ card', 'oep', 'Hungarian TAJ card or TAJ related proof.', false, 60),
    ('tax_card', 'Tax card', 'nav', 'Hungarian tax card or tax number proof.', false, 70),
    ('address_card', 'Address card', 'housing', 'Address card or accommodation proof.', false, 80),
    ('medical_clearance', 'Medical clearance', 'medical', 'Medical fitness or clearance document.', true, 90),
    ('housing_document', 'Housing document', 'housing', 'Housing, lease, or accommodation document.', false, 100),
    ('nav_document', 'NAV document', 'nav', 'NAV registration or tax document.', false, 110),
    ('bmh_document', 'BMH document', 'bmh', 'BMH workflow document.', false, 120),
    ('oep_document', 'OEP document', 'oep', 'OEP workflow document.', false, 130),
    ('other', 'Other document', 'other', 'Fallback document type.', false, 999)
) as seed(document_type_code, label, category, description, requires_expiry, sort_order)
where not exists (
  select 1
  from public.document_types dt
  where lower(dt.document_type_code) = lower(seed.document_type_code)
);
