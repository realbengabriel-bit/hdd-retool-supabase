-- HDD / UAHUN central documents layer
-- Functions only.

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

drop function if exists public.fn_link_existing_document_file_with_context(
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  text
);

create or replace function public.fn_link_existing_document_file_with_context(
  p_document_file_id uuid,
  p_workflow_case_id uuid default null,
  p_candidate_id uuid default null,
  p_assignment_id uuid default null,
  p_application_id uuid default null,
  p_person_id uuid default null,
  p_task_id uuid default null,
  p_link_type text default null,
  p_document_type_code text default null,
  p_title text default null,
  p_created_by text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $function$
declare
  v_document_file_id uuid;
  v_document_link_id uuid;
  v_existing_document_link boolean := false;
  v_created_document_link boolean := false;
  v_review_queue_updated_count integer := 0;
  v_entity_type text;
  v_entity_id uuid;
  v_link_type text;
  v_created_by text;
  v_document_name text;
  v_document_type_code text;
begin
  select
    d.id,
    d.document_name,
    d.document_type_code
    into
      v_document_file_id,
      v_document_name,
      v_document_type_code
  from public.document_files d
  where d.id = p_document_file_id
    and d.archived_at is null
  limit 1;

  if v_document_file_id is null then
    raise exception 'Document file not found for id %', p_document_file_id
      using errcode = 'P0002';
  end if;

  if p_workflow_case_id is null
    and p_candidate_id is null
    and p_assignment_id is null
    and p_application_id is null
    and p_person_id is null
    and p_task_id is null
  then
    raise exception 'At least one document link context id is required'
      using errcode = '22023';
  end if;

  v_link_type := lower(nullif(btrim(p_link_type), ''));
  v_created_by := coalesce(nullif(btrim(p_created_by), ''), 'Retool');
  v_document_type_code := coalesce(nullif(btrim(p_document_type_code), ''), v_document_type_code);
  v_document_name := coalesce(nullif(btrim(p_title), ''), v_document_name);

  v_entity_type := case
    when v_link_type = 'assignment' and p_assignment_id is not null then 'assignment'
    when v_link_type in ('candidate', 'person') and p_candidate_id is not null then 'candidate'
    when v_link_type = 'person' and p_person_id is not null then 'person'
    when v_link_type = 'application' and p_application_id is not null then 'application'
    when v_link_type = 'task' and p_task_id is not null then 'task'
    when p_workflow_case_id is not null then 'workflow_case'
    when p_candidate_id is not null then 'candidate'
    when p_assignment_id is not null then 'assignment'
    when p_person_id is not null then 'person'
    when p_application_id is not null then 'application'
    when p_task_id is not null then 'task'
  end;

  v_entity_id := case v_entity_type
    when 'workflow_case' then p_workflow_case_id
    when 'candidate' then p_candidate_id
    when 'assignment' then p_assignment_id
    when 'person' then p_person_id
    when 'application' then p_application_id
    when 'task' then p_task_id
  end;

  select l.document_link_id
    into v_document_link_id
  from public.document_links l
  where l.archived_at is null
    and coalesce(l.status, 'active') = 'active'
    and l.document_file_id = v_document_file_id
    and coalesce(l.entity_type, '') = coalesce(v_entity_type, '')
    and l.entity_id is not distinct from v_entity_id
    and l.workflow_case_id is not distinct from p_workflow_case_id
    and l.candidate_id is not distinct from p_candidate_id
    and l.assignment_id is not distinct from p_assignment_id
    and l.person_id is not distinct from p_person_id
    and l.application_id is not distinct from p_application_id
    and l.task_id is not distinct from p_task_id
  order by l.created_at asc nulls last, l.document_link_id
  limit 1;

  if v_document_link_id is not null then
    v_existing_document_link := true;
  else
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
      p_workflow_case_id,
      p_candidate_id,
      p_assignment_id,
      p_person_id,
      p_application_id,
      p_task_id,
      'active',
      not exists (
        select 1
        from public.document_links existing
        where existing.document_file_id = v_document_file_id
          and existing.archived_at is null
          and coalesce(existing.status, 'active') = 'active'
      ),
      'documents',
      'master_document_hub_manual_link',
      coalesce(nullif(btrim(p_title), ''), 'Manual master document hub link'),
      v_created_by,
      v_created_by,
      jsonb_build_object(
        'requested_link_type', v_link_type,
        'document_type_code', v_document_type_code,
        'title', v_document_name
      )
    )
    returning document_link_id into v_document_link_id;

    v_created_document_link := true;
  end if;

  update public.document_review_queue rq
     set review_status = 'linked',
         final_document_type = coalesce(nullif(btrim(p_document_type_code), ''), rq.final_document_type, rq.suggested_document_type),
         final_workflow_case_id = coalesce(p_workflow_case_id, rq.final_workflow_case_id),
         final_candidate_id = coalesce(p_candidate_id, rq.final_candidate_id),
         final_assignment_id = coalesce(p_assignment_id, rq.final_assignment_id),
         final_person_id = coalesce(p_person_id, rq.final_person_id),
         reviewed_by = coalesce(nullif(btrim(p_created_by), ''), rq.reviewed_by, 'Retool'),
         reviewed_at = coalesce(rq.reviewed_at, now()),
         updated_at = now(),
         metadata = coalesce(rq.metadata, '{}'::jsonb) || jsonb_build_object(
           'linked_by', v_created_by,
           'linked_at', now(),
           'linked_document_link_id', v_document_link_id
         )
   where rq.document_file_id = v_document_file_id
     and rq.review_status in ('open', 'needs_review', 'needs_more_info');

  get diagnostics v_review_queue_updated_count = row_count;

  return jsonb_build_object(
    'ok', true,
    'document_file_id', v_document_file_id,
    'document_link_id', v_document_link_id,
    'created_document_link', v_created_document_link,
    'existing_document_link', v_existing_document_link,
    'review_queue_updated_count', v_review_queue_updated_count,
    'entity_type', v_entity_type,
    'entity_id', v_entity_id,
    'workflow_case_id', p_workflow_case_id,
    'candidate_id', p_candidate_id,
    'assignment_id', p_assignment_id,
    'application_id', p_application_id,
    'person_id', p_person_id,
    'task_id', p_task_id
  );
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

  select d.id
    into v_document_file_id
  from public.document_files d
  where d.archived_at is null
    and (
      (v_storage_bucket is not null and v_storage_path is not null and d.storage_bucket = v_storage_bucket and d.storage_path = v_storage_path)
      or (v_file_hash_sha256 is not null and d.file_hash_sha256 = v_file_hash_sha256)
      or (v_file_url is not null and d.file_url = v_file_url)
      or (v_external_url is not null and d.external_url = v_external_url)
    )
  order by d.created_at asc nulls last, d.id
  limit 1;

  if v_document_file_id is null then
    v_document_file_id := gen_random_uuid();

    insert into public.document_files (
      id,
      document_file_id,
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
      v_document_file_id,
      v_document_file_id,
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
    returning id into v_document_file_id;

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
     where public.document_files.id = v_document_file_id;
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
