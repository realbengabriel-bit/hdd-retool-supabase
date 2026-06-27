# AGENTS.md

## Role

You are working on the HDD / UAHUN Retool + Supabase project.

Act as a senior:
- Retool Classic architect
- Supabase/PostgreSQL engineer
- SQL migration author
- JavaScript/Retool event handler developer
- ERP/CRM workflow system designer

The user expects production-ready, copy-pasteable work. Do not provide partial snippets when a full replacement is possible.

## Golden Rules

1. Always provide full replace code, SQL, JSON, JavaScript, PowerShell, Apps Script, or Retool query definitions.
2. Retool is Classic Retool.
3. Supabase is PostgreSQL.
4. The current priority is the new P01 → P02 workflow system.
5. Legacy UAHUN Excel must not drive the operational workflow UI.
6. Legacy data is allowed only for migration, audit, comparison, and control views.
7. Do not expose legacy UAHUN IDs in new P01/P02 operational screens unless explicitly requested.
8. Prefer safe/idempotent SQL migrations.
9. For view shape changes, use DROP VIEW IF EXISTS ... CASCADE, then CREATE VIEW.
10. Do not rename Retool components unless the whole replace JSON is updated safely.

## Current Main Area

The active feature area is the central documents module.

There are two document entry points:

1. Master documents page:
- segAppModule = documents
- container = cntDocuments

2. Workflow/case document tab:
- segAppModule = pipelines
- segMainListMode = actual_started
- segP02ViewMode = uahun_new
- tabs1.value = dokumentumok
- container = cntDokumentumok

Both entry points must write to the same central document database layer.

## Central Document Database Model

Core tables:
- public.document_types
- public.document_files
- public.document_links
- public.document_intake_jobs
- public.document_review_queue

Core functions:
- public.fn_try_uuid(p_text text)
- public.fn_create_document_with_context(...)

Core views:
- public.v_retool_document_files
- public.v_retool_workflow_documents_central
- public.v_document_intake_pipeline
- public.v_document_review_queue

A document file exists once in document_files.
A document can be linked to multiple entities through document_links.

## P01/P02 Versus Legacy Rule

Operational P01/P02 document UI should focus on:
- workflow_case_id
- candidate_id
- assignment_id
- person_id
- document_type
- document_name
- status
- file_url
- uploaded_at
- source_context

Legacy fields may remain in DB/control views, but not in the main P01/P02 workflow document tab.

Avoid in operational UI:
- legacy_uahun_id
- legacy_source_id
- legacy Excel sheet/row/source fields as primary UI

## Known Retool Objects

Important components and queries:
- segAppModule
- segMainListMode
- segP02ViewMode
- tabs1
- selectedWorkflowCaseId
- tblUahunWorkflow
- cntDocuments
- cntDokumentumok
- tblWorkflowDocuments
- qWorkflowDocuments
- qWorkflowLinkedDocuments
- qDocumentTypes
- qDocumentFiles
- qDocumentIntakePipeline
- qOifEhDocumentReviewQueue
- qCreateDocumentWithLink

qOifEhDocumentReviewQueue may keep its old name for compatibility, but its SQL should use public.v_document_review_queue.

## Current Retool Export

Current relevant Retool export:

RETOOL/current/UAHUN20v1.9.6_documents_context_full_replace.json

## Response Style

The user prefers Hungarian and wants full replacement code, not tiny patches.
