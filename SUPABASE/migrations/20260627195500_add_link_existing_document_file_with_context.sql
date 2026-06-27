-- HDD / UAHUN central documents layer
-- Adds helper for linking an existing master document file to an operational context.

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
