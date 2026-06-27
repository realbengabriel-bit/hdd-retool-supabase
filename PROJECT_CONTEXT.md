# PROJECT_CONTEXT.md

## Project

HDD / UAHUN Retool + Supabase internal operations system.

Stack:
- Retool Classic
- Supabase PostgreSQL
- SQL
- JavaScript
- Git / Codex workflow

## Current Focus

The main active focus is the new P01 → P02 flow:

P01 Planned Personnel
→ P02 Actual Started Working
→ UAHUN workflow/case handling
→ documents
→ package / NAV / BMH / OEP / housing / notifications / audit

Legacy UAHUN Excel is not the operational source of truth for new work.

Legacy is allowed only for:
- migration
- audit
- comparison
- control
- old-data reconciliation

## Documents Module Decision

The documents module is central and generic.

There are two upload/view surfaces:

### Master document hub

Retool:
- segAppModule = documents
- cntDocuments

Purpose:
- bulk upload
- master search
- review queue
- OCR/intake pipeline later
- cross-person and cross-case document management

### Workflow/case document tab

Retool:
- segAppModule = pipelines
- segMainListMode = actual_started
- segP02ViewMode = uahun_new
- tabs1 = dokumentumok
- cntDokumentumok

Purpose:
- upload/view documents while working on one selected P01/P02 workflow case
- user should not need to leave the case view to attach a document

Both surfaces write to:
- public.document_files
- public.document_links

## Central Document Tables

Expected tables:
- public.document_types
- public.document_files
- public.document_links
- public.document_intake_jobs
- public.document_review_queue

Expected function:
- public.fn_create_document_with_context(...)

Expected views:
- public.v_retool_document_files
- public.v_retool_workflow_documents_central
- public.v_document_intake_pipeline
- public.v_document_review_queue

## Correct Document Flow

Upload from master hub:
1. insert into document_files
2. if context selected, insert into document_links
3. if no context, create document_review_queue item

Upload from workflow/case tab:
1. insert into document_files
2. link selectedWorkflowCaseId
3. link candidate_id / assignment_id / person_id if available
4. show the document in workflow documents and master document hub

## Important Retool Export

Latest generated replace JSON:

RETOOL/current/UAHUN20v1.9.6_documents_context_full_replace.json

This export was based on:
UAHUN20v1.9.5_doksis.json

## Important Rule

Do not show legacy UAHUN fields in the new P01/P02 operational document tab.

Allowed in operational document UI:
- document_name
- document_type_label
- status_label
- file_url
- uploaded_at
- uploaded_by
- expiry_date
- expiry_status_label
- source_context

Hide technical fields by default:
- document_id
- document_file_id
- document_link_id
- workflow_case_id
- candidate_id
- assignment_id
- person_id
- application_id
- task_id
- document_requirement_id
- storage_bucket
- storage_path
- storage_ref

Legacy/control views may include:
- legacy_uahun_id
- source_sheet_name
- source_row_number
- source_column

## Future Direction

Prepare documents module for:
- OCR
- QR recognition
- AI document classification
- automatic person/case matching
- confidence score
- review queue if uncertain
- notifications
- audit log
- Supabase Storage signed URLs
