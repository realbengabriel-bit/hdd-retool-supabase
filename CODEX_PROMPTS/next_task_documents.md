# Next Codex Task - UAHUN Documents Module

Read first:
- AGENTS.md
- PROJECT_CONTEXT.md

Current goal:
Continue the HDD / UAHUN Retool + Supabase documents module work.

Main requirements:
- focus on the new P01 → P02 workflow system
- master documents hub and workflow/case document tab must use the same central document DB
- do not make legacy UAHUN Excel part of the operational document UI
- keep legacy only for migration/control/audit
- provide full replacement SQL / JSON / JS, not tiny patches

Inspect:
- RETOOL/current/UAHUN20v1.9.6_documents_context_full_replace.json
- SUPABASE/migrations
- SUPABASE/schema.sql
- SUPABASE/views.sql
- SUPABASE/functions.sql

Expected database objects:
- public.document_types
- public.document_files
- public.document_links
- public.document_intake_jobs
- public.document_review_queue
- public.fn_try_uuid(p_text text)
- public.fn_create_document_with_context(...)
- public.v_retool_document_files
- public.v_retool_workflow_documents_central
- public.v_document_intake_pipeline
- public.v_document_review_queue

Tasks:
1. Verify the Retool JSON uses public.fn_create_document_with_context for document creation.
2. Verify qWorkflowDocuments reads from public.v_retool_workflow_documents_central.
3. Verify qDocumentFiles reads from public.v_retool_document_files.
4. Verify review queue reads from public.v_document_review_queue.
5. Verify the P01/P02 workflow document table does not expose legacy_uahun_id as an operational column.
6. Prepare a full Supabase migration file if missing.
7. Provide full replacement files, not tiny patches.
