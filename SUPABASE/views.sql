-- HDD / UAHUN central documents layer
-- Retool-facing views only.

drop view if exists public.v_document_review_queue cascade;
drop view if exists public.v_document_intake_pipeline cascade;
drop view if exists public.v_retool_workflow_documents_central cascade;
drop view if exists public.v_retool_document_files cascade;

create view public.v_retool_document_files as
select
  d.id as document_file_id,
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
  where l.document_file_id = d.id
    and l.archived_at is null
) link_stats on true
where d.archived_at is null;

do $$
begin
  if to_regclass('public.v_retool_workflow_detail_core') is not null then
    execute $view$
      create view public.v_retool_workflow_documents_central as
      select
        d.id as document_id,
        d.id as document_file_id,
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
        on d.id = l.document_file_id
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
        d.id as document_id,
        d.id as document_file_id,
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
        on d.id = l.document_file_id
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
  on d.id = ij.document_file_id
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
  on d.id = rq.document_file_id
left join public.document_types sdt
  on lower(sdt.document_type_code) = lower(rq.suggested_document_type)
left join public.document_types fdt
  on lower(fdt.document_type_code) = lower(rq.final_document_type);
