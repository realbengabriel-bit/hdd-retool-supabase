# OIF/EH Demo Existing Surfaces Audit

## Rövid összefoglaló

A repo alapján a demohoz több fontos OIF/EH felület már létezik. Nem érdemes nulláról új Retool gombokat vagy új lokális agent felületet építeni, amíg ezek nincsenek kipróbálva.

Jelen állapot repo alapján:

| Terület | Találtam? | Rövid értékelés |
| --- | --- | --- |
| package builder surfaces | Igen | A legfrissebb exportban is megvan az OIF/EH package builder réteg: package candidates, packages, items, pages, payload preview, manifest, backside labels. |
| PDF/generate surfaces | Igen | btnOifEhGeneratePackagePdfs és jsOifEhGeneratePackagePdfs létezik, régi endpoint-sorral: /generate-oif-package-pdfs, /api/generate-oif-package-pdfs, /oif-eh/generate-oif-package-pdfs, fallback /run-eh-package. |
| generated files table/surface | Igen | tblOifEhGeneratedFiles és qOifEhGeneratedFiles létezik, public.v_retool_oif_eh_generated_files view-t olvas. |
| document upload + OCR surface | Igen | btnOifWorkflowUploadLinkAndOcr és jsOifWorkflowUploadLinkAndOcr_v1 megvan a workflow Dokumentumok tabon. |
| local agent run log surface | Igen | qOifEhAgentRunLog, qOifEhAgentLogRun, tblOifEhAgentRunLog létezik. |
| direct EH fill surface | Igen, kockázatos legacy/demo forma | jsAgentEhFillXlsFree_v12_1 hívja a /agent/eh/fill endpointot live_fill=true, allow_submit=false payload-dal. Ezt új safety gate nélkül nem szabad vakon újrakötni. |
| attachment upload surface | Részben | Attachment manifest és generated files UI van. Direkt /agent/attachments/upload vagy /agent/attachments/scan hivatkozást nem találtam a repo Retool exportjaiban. |
| Robot Barát integration surface | Részben | Robot Barát agent instrukciók és safety pipeline létezik, de local gateway execution továbbra sem connected/allowed. Demohoz explicit handoff/control maradjon, ne hidden executor. |

Fontos: a legfrissebb RETOOL/current/UAHUN20v2_executor_runtime_guardrails.json export is tartalmazza a régi OIF/EH felületeket. Ez a legjobb patch-alap a későbbi demo-fixhez, nem a v1.9.8 külön visszaemelése.

## Retool app/export inventory

### Exportok, amelyekben a releváns OIF/EH surface set megtalálható

A célzott keresés szerint az alábbi exportok tartalmazzák a kulcs OIF/EH komponenseket és queryket: btnOifWorkflowUploadLinkAndOcr, jsOifWorkflowUploadLinkAndOcr_v1, tblOifEhGeneratedFiles, qOifEhGeneratedFiles, qOifEhPayloadPreview, qOifEhAttachmentManifest, qOifEhPythonExport, qOifEhAgentRunLog, jsOifEhAgentHealth, jsOifEhGeneratePackagePdfs, jsOifEhAgentRunPackage, jsAgentEhFillXlsFree_v12_1, /run-eh-package, generate-oif-package-pdfs, fn_retool_oif_eh_create_packages, fn_retool_oif_eh_generate_payload_from_rows, v_retool_oif_eh_generated_files.

| File path | Releváns állapot | Risk | Recommendation |
| --- | --- | --- | --- |
| RETOOL/current/UAHUN20v2_executor_runtime_guardrails.json | Legfrissebb current export, tartalmazza az OIF/EH package buildert és az executor safety panelt is. | medium/high | Demohoz ezt patch-eljük majd, mert ez a canonical current export. |
| RETOOL/current/UAHUN20v1.9.8_legujabb.json | Régebbi export, ugyanazokkal az OIF/EH felületekkel, plusz legacy állapot. | medium | Referencia, nem import cél. |
| RETOOL/current/UAHUN20v2_action_request_approval_center_fixed.json | OIF/EH felületek megvannak, de nem legfrissebb runtime guardrail export. | medium | Csak összehasonlításra. |
| RETOOL/current/UAHUN20v2_alert_center.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_alert_center_actions_fixed.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_alert_center_daily_briefing_fixed.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_approved_action_queue.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_case_assistant.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_case_assistant_to_action_request.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_dry_run_results.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_execution_handoff_readiness.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_executor_readiness_contract.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_final_confirmation_gate.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_prioritized_work_queue_html_lists.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |
| RETOOL/current/UAHUN20v2_prioritized_work_queue_rebuilt_tables.json | OIF/EH felületeket örökli. | medium | Ne erre építsünk. |

### Canonical detailed inventory: RETOOL/current/UAHUN20v2_executor_runtime_guardrails.json

| Component/query id | Type | Location if inferable | What it does | Wired to real endpoint/RPC or UI only | Risk | Keep/reuse/replace recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| btnOifWorkflowUploadLinkAndOcr | button | cntDokumentumok, workflow/case dokumentumok tab | Label: Feltöltés + kapcsolat + OCR; upload, central document link, OCR/QR flow. | Wired to jsOifWorkflowUploadLinkAndOcr_v1. | medium | Reuse first for demo document upload + OCR. Do not duplicate. |
| jsOifWorkflowUploadLinkAndOcr_v1 | JS query | workflow/case document tab | Upload/link/OCR orchestration for selected workflow document. Tooltip says Supabase Storage upload, central document creation/link, OCR/QR analysis. | Wired through button; likely calls existing storage/document/OCR queries. | medium/high | Reuse if working. Audit exact endpoint behavior before changing. |
| fileOifWorkflowDocumentUpload | file input | workflow/case document tab | File picker for workflow document upload flow. | UI input for upload flow. | low/medium | Reuse. |
| selOifWorkflowDocumentType | select | workflow/case document tab | Selects document type for workflow upload. | UI input. | low | Reuse. |
| inpOifWorkflowDocumentName | input | workflow/case document tab | Optional document name. | UI input. | low | Reuse. |
| qOifExtensionPackageCandidates | SQL query | OIF/EH package builder | Calls public.fn_retool_oif_eh_source_candidates(...); lists package candidates. | Real Supabase RPC/function. | medium | Reuse. |
| qOifCreateExtensionPackages | SQL query | OIF/EH package builder | Calls public.fn_retool_oif_eh_create_packages(...); prepares package rows from selected candidates. | Real Supabase RPC/function, mutates OIF/EH package control schema if installed. | medium/high | Reuse only manually; require confirmation if patched. |
| btnOifCreatePackages | button | OIF/EH package builder | Creates/prepares OIF/EH package(s). | Wired to package creation flow. | medium/high | Reuse; do not duplicate. |
| qOifExtensionPackages | SQL query | OIF/EH package builder | Reads public.v_retool_oif_extension_packages. | Real view if installed. | medium | Reuse. |
| qOifExtensionPackageItems | SQL query | OIF/EH package builder | Reads package items. | Real view if installed. | medium | Reuse. |
| qOifExtensionPackagePages | SQL query | OIF/EH package builder | Reads package pages. | Real view if installed. | medium | Reuse. |
| qOifEhGeneratePayload | SQL query | OIF/EH package builder | Calls public.fn_retool_oif_eh_generate_payload_from_rows(...); creates EH/Python payload, attachment manifest, backside labels. | Real Supabase RPC/function if installed. | medium/high | Reuse for payload/manifest; do not duplicate. |
| btnOifEhGeneratePayload | button | OIF/EH package builder | Triggers payload generation and refreshes preview/manifest/backside labels. | Wired to qOifEhGeneratePayload. | medium | Reuse. |
| qOifEhPayloadPreview | SQL query | OIF/EH package builder | Reads public.v_retool_oif_eh_payload_preview. | Real view if installed. | medium | Reuse. |
| tblOifEhPayloadPreview | table | OIF/EH package builder | Displays payload preview. | UI table backed by qOifEhPayloadPreview. | low/medium | Reuse. |
| qOifEhPythonExport | SQL query | OIF/EH package builder | Reads public.v_retool_oif_eh_python_export, adds FEOR override info. | Real view if installed. | medium | Reuse as source payload for gateway. |
| qOifEhAttachmentManifest | SQL query | OIF/EH package builder | Reads public.v_retool_oif_eh_attachment_manifest. | Real view if installed. | medium | Reuse for attachment checklist/upload order. |
| tblOifEhAttachmentManifest | table | OIF/EH package builder | Displays attachment manifest. | UI table. | low/medium | Reuse. |
| qOifEhBacksideLabels | SQL query | OIF/EH package builder | Reads public.v_retool_oif_eh_backside_labels. | Real view if installed. | medium | Reuse for backside QR labels. |
| tblOifEhBacksideLabels | table | OIF/EH package builder | Displays backside labels. | UI table. | low/medium | Reuse. |
| qOifEhQrPayloads | SQL query | OIF/EH package builder | Reads public.v_retool_oif_eh_qr_payloads. | Real view if installed. | medium | Reuse. |
| tblOifEhQrPayloads | table | OIF/EH package builder | Displays QR payloads. | UI table. | low/medium | Reuse. |
| tblOifEhGeneratedFiles | table | pdf_agent area in package builder | Displays generated PDF/files. Empty message says: Nincs generált PDF. Futtasd az EH local agentet, majd frissíts. | Backed by qOifEhGeneratedFiles. | medium | Reuse. Fix data flow if needed; do not create duplicate generated files table. |
| qOifEhGeneratedFiles | SQL query | pdf_agent area | Reads public.v_retool_oif_eh_generated_files, filtered by selected package. | Real view if installed. | medium | Reuse. |
| btnOifEhGeneratePackagePdfs | button | pdf_agent area | Starts package PDF generation. | Wired to jsOifEhGeneratePackagePdfs. | high | Reuse UI, but endpoint mapping must be safety-reviewed. |
| jsOifEhGeneratePackagePdfs | JS query | pdf_agent area | Uses base inpOifEhAgentUrl default https://eh-agent.hddirekt.com; tries /generate-oif-package-pdfs, /api/generate-oif-package-pdfs, /oif-eh/generate-oif-package-pdfs, fallback /run-eh-package with agent_mode generate_pdfs. | Wired to external/gateway endpoint, not current rebuild endpoint shape. | high | Adapt next, do not duplicate. Must enforce final_submit_blocked=true. |
| inpOifEhAgentUrl | input | pdf_agent area | Agent base URL, default seen as https://eh-agent.hddirekt.com. | UI config input. | high | Reuse but for office local demo operator must explicitly set reachable base. |
| inpOifEhAgentToken | input | pdf_agent area | Agent token. | UI config input. | medium/high | Reuse; ensure no secrets in export. |
| btnOifEhAgentHealth | button | pdf_agent area | Health check button. | Wired to jsOifEhAgentHealth. | medium | Reuse. |
| jsOifEhAgentHealth | JS query | pdf_agent area | Calls base /health with optional X-EH-Agent-Token and Authorization bearer. | Real gateway endpoint. | low/medium | Reuse for demo health only. |
| btnOifEhRunAgent | button | pdf_agent area | Label: 5. EH kitöltő/feltöltő agent; tooltip says existing Cloudflare agent /run-eh-package. | Wired to jsAgentEhFillXlsFree_v12_1 in observed event. | high | Reuse shell only after adapting to safe endpoint. |
| jsOifEhAgentRunPackage | JS query | pdf_agent area | Calls base /run-eh-package, sends generated files, mode, token, logs result. | Real gateway endpoint; current rebuild has dry-run compatibility only. | high | Reuse/adapt for dry-run; do not allow hidden live run. |
| jsAgentEhFillXlsFree_v12_1 | JS query | pdf_agent/EH fill test | Calls baseUrl /agent/eh/fill with live_fill=true, allow_submit=false, use_existing_pdfs=true, xlsx_path. | Direct EH fill surface, endpoint absent in rebuild gateway. | high | Do not use until endpoint is restored with explicit demo gate and no final submit. |
| qOifEhAgentLogRun | SQL query | pdf_agent area | Calls public.fn_retool_eh_local_agent_log_run(...), default agent base http://127.0.0.1:8787. | Real Supabase RPC/function if installed; writes local agent run log. | medium/high | Reuse for audit logging only; update default URL later if using v11 port 8788. |
| qOifEhAgentRunLog | SQL query | pdf_agent area | Reads public.v_retool_eh_local_agent_run_log. | Real view if installed. | medium | Reuse. |
| tblOifEhAgentRunLog | table | pdf_agent area | Displays local agent/PDF run history. | UI table. | low/medium | Reuse. |
| qOifEhInstallCoreSchema | SQL query | OIF/EH admin/core install area | Huge idempotent OIF/EH core schema install SQL embedded in Retool. Creates schema, tables, views, functions. | Real DDL if manually run from Retool; not present as repo migration. | high | Do not run casually. Convert to migration later if needed. |
| qOifEhOcrReview | SQL query | OCR review area | Reads public.v_retool_oif_eh_ocr_review. | Real view if installed. | medium | Reuse. |
| qOifEhApproveOcrField | SQL query | OCR review area | Calls public.fn_retool_oif_eh_approve_ocr_field(...). | Real RPC/function if installed. | medium | Reuse after confirming backend. |
| jsOifEhOcrAnalyzeUploadedFile_v1 | JS query | OCR intake area | Calls OCR API base default https://eh-ocr-api.hddirekt.com; analyzes uploaded file. | External OCR API, not local gateway. | high | Reuse only if API is approved/reachable. |
| jsOifEhOcrAnalyzeSelectedStorageObject_v1 | JS query | OCR intake/review area | Calls OCR API simple flow for selected Supabase Storage object; includes selected person/workflow context. | External OCR API. | high | Reuse if working; do not duplicate. |
| jsOifEhOcrReviewDecision_v1 | JS query | OCR review area | Calls OCR review decision endpoint; comments mention backend /review/decision-simple to Supabase RPC public.oif_eh_document_review_decision. | External OCR API/Supabase bridge. | high | Reuse only after confirming endpoint. |
| btnOifEhOcrAnalyzeUploadedFile | button | OCR intake area | Triggers uploaded-file OCR analysis. | Wired to JS OCR query. | medium/high | Reuse. |
| btnOifEhOcrAnalyzeSelectedStorageObject | button | OCR intake/review area | Triggers selected storage object OCR analysis. | Wired to JS OCR query. | medium/high | Reuse. |
| btnOifEhOcrReviewApprove, btnOifEhOcrReviewReject, btnOifEhOcrReviewNeedsMoreInfo | buttons | OCR review area | Review decision actions. | Wired to OCR review decision flow. | medium/high | Reuse after backend check. |
| RETOOL/agents/Robot_Barat_current.json | agent config | Robot Barát | Contains OIF/EH package preparation instructions and disabled execution guardrails. | Agent surface, not Retool app UI. | high | Keep disconnected for demo; do not use as hidden executor. |

### Explicit target checks

| Target | Result |
| --- | --- |
| btnOifWorkflowUploadLinkAndOcr | Found in current/latest and older Retool exports. |
| jsOifWorkflowUploadLinkAndOcr_v1 | Found in current/latest and older Retool exports. |
| tblOifEhGeneratedFiles | Found in current/latest and older Retool exports. |
| generate-oif-package-pdfs | Found in current/latest and older Retool exports through jsOifEhGeneratePackagePdfs. |
| /agent/pdf/generate | Found in rebuilt gateway docs/code, not wired from current Retool export. |
| /agent/eh/fill | Found in current Retool export via jsAgentEhFillXlsFree_v12_1; not present in rebuilt gateway. |
| /agent/attachments/upload | Not found in repo Retool/gateway files. |
| /agent/attachments/scan | Not found in repo Retool/gateway files. |
| /run-eh-package | Found in current Retool export and rebuilt gateway compatibility endpoint. |
| eh-agent-api.hddirekt.com | Found in old v1.9.8 export. |
| eh-agent.hddirekt.com | Found in current/latest Retool export as default agent base URL. |
| 127.0.0.1:8788 | Found in rebuilt gateway package docs/scripts/snippets, not current Retool app export. |
| 127.0.0.1:8787 | Found in old local agent log default and PDF generator bridge docs. |
| fn_retool_oif_eh_generate_payload | Found as public.fn_retool_oif_eh_generate_payload_from_rows(...). |
| fn_retool_oif_eh_create_packages | Found in Retool SQL and embedded core schema. |
| fn_retool_oif_eh_register_generated_file | Found in embedded core schema. |
| v_retool_oif_eh_payload_preview | Found in Retool queries and embedded core schema. |
| v_retool_oif_eh_generated_files | Found in Retool queries and embedded core schema. |
| v_retool_oif_eh_attachment_manifest | Found in Retool queries and embedded core schema. |
| v_retool_oif_eh_python_export | Found in Retool queries and embedded core schema. |

## Supabase/RPC/view inventory

### Source-controlled Supabase files

| File path | Object name | Purpose | Demo relevance |
| --- | --- | --- | --- |
| SUPABASE/migrations/20260630013000_add_eh_agent_gateway_v11_package_wrapper.sql | public.get_oif_eh_agent_package_v11(...) | v11 gateway compatibility wrapper; resolves workflow_case_id and delegates to original public.get_oif_eh_agent_package(uuid). | Current rebuild gateway uses EH_AGENT_PACKAGE_RPC=get_oif_eh_agent_package_v11; good for package prepare/full dry-run. |
| SUPABASE/smoke_tests/eh_agent_gateway_v11_package_wrapper.sql | smoke for public.get_oif_eh_agent_package_v11(...) | Read-only wrapper validation. | Confirms wrapper, not PDF generation. |
| LOCAL_AGENTS/eh_agent_gateway_v11_p02_pkg/sql/01_required_supabase_objects_check.sql | inventory check for get_oif_eh_agent_package, v_oif_eh_agent_package_source, payload/manifest/run-log views | Read-only existence checks. | Useful pre-demo DB inventory. |

Repo search did not find full OIF/EH package builder schema as a normal SUPABASE/migrations/*.sql migration. The full schema appears embedded in Retool as qOifEhInstallCoreSchema.

### Retool-embedded OIF/EH core schema objects

These objects are visible inside qOifEhInstallCoreSchema in the Retool export. They may exist in the live database if that Retool install query was run, but they are not fully represented as source-controlled Supabase migrations in this repo.

Tables:

- oif_eh.packages
- oif_eh.package_items
- oif_eh.package_pages
- oif_eh.payloads
- oif_eh.generated_files
- oif_eh.agent_runs
- oif_eh.package_templates
- oif_eh.template_files
- oif_eh.ocr_runs
- oif_eh.ocr_fields
- oif_eh.ocr_field_rules
- oif_eh.qr_rules
- oif_eh.agent_step_templates

Views:

- public.v_retool_oif_extension_packages
- public.v_retool_oif_extension_package_items
- public.v_retool_oif_extension_package_pages
- public.v_retool_oif_eh_payload_preview
- public.v_retool_oif_eh_python_export
- public.v_retool_oif_eh_attachment_manifest
- public.v_retool_oif_eh_backside_labels
- public.v_retool_oif_eh_qr_payloads
- public.v_retool_oif_eh_ocr_review
- public.v_retool_oif_eh_generated_files
- public.v_retool_eh_local_agent_run_log
- public.v_retool_oif_eh_template_catalog
- public.v_retool_oif_eh_template_files

Functions:

- public.fn_retool_oif_eh_source_candidates(...)
- public.fn_retool_oif_eh_create_packages(...)
- public.fn_retool_oif_eh_generate_payload_from_rows(...)
- public.fn_retool_oif_eh_register_generated_file(...)
- public.fn_retool_eh_local_agent_log_run(...)
- public.fn_retool_oif_update_package_item_status(...)
- public.fn_retool_oif_eh_ingest_ocr_result(...)
- public.fn_retool_oif_eh_approve_ocr_field(...)
- oif_eh.refresh_qr_payloads(...)
- oif_eh.default_items(...)
- helper functions: oif_eh.try_uuid, oif_eh.norm_text, oif_eh.make_lookup_id, oif_eh.safe_numeric

Demo relevance:

- Payload preview: public.v_retool_oif_eh_payload_preview, public.fn_retool_oif_eh_generate_payload_from_rows(...)
- Python export: public.v_retool_oif_eh_python_export
- Attachment manifest: public.v_retool_oif_eh_attachment_manifest
- Generated files: public.v_retool_oif_eh_generated_files, public.fn_retool_oif_eh_register_generated_file(...)
- Local agent run log: public.v_retool_eh_local_agent_run_log, public.fn_retool_eh_local_agent_log_run(...)
- OCR review: public.v_retool_oif_eh_ocr_review, public.fn_retool_oif_eh_ingest_ocr_result(...), public.fn_retool_oif_eh_approve_ocr_field(...)
- Package creation/generation: public.fn_retool_oif_eh_create_packages(...), public.fn_retool_oif_eh_generate_payload_from_rows(...)

Risk:

- High if qOifEhInstallCoreSchema is run from Retool during demo without review, because it contains DDL and schema creation/update logic.
- Medium if package creation/payload generation is used manually on demo data.
- Low/medium for read-only preview tables/views if already installed.

## Local gateway code inventory

### Rebuilt gateway in repo

File: LOCAL_AGENTS/eh_agent_gateway_v11_p02_pkg/eh_agent_gateway_v11_p02.py

Existing endpoints:

- GET /health
- GET /version
- GET /capabilities
- POST /agent/package/prepare
- POST /agent/eh/fill-dry-run
- POST /agent/run-full-dry
- POST /agent/pdf/generate
- POST /run-eh-package

Safety behavior:

- execution_allowed_now=false
- live_fill_allowed=false
- submit_allowed=false
- no Selenium import
- no Playwright import
- no subprocess import
- optional PDF generator bridge is blocked by default through ALLOW_PDF_GENERATOR_BRIDGE=false

Safe reusable code:

- health/version/capabilities
- bearer token auth
- Supabase package prepare via EH_AGENT_PACKAGE_RPC=get_oif_eh_agent_package_v11
- full dry-run orchestration
- dry-run checklist builder
- compatibility /run-eh-package dry-run handler
- audit JSON log writer under EH_AGENT_RUN_DIR

### Older gateway/package files in repo

No older gateway Python/package source was found under LOCAL_AGENTS in this repo. The old v11 endpoint names appear as Retool references and user-provided known evidence, not as old gateway code in source control.

Known old endpoint set from context/Retool references:

- /generate-oif-package-pdfs
- /api/generate-oif-package-pdfs
- /oif-eh/generate-oif-package-pdfs
- /agent/eh/fill
- /run-eh-package

Known old endpoint set from user context but not found in repo code:

- /agent/attachments/scan
- /agent/attachments/upload

### Missing delta needed for demo

| Need | Current Retool surface | Current rebuilt gateway support | Delta |
| --- | --- | --- | --- |
| Health check | jsOifEhAgentHealth calls /health | Exists | Retool base URL/token may need operator config only. |
| Package prepare/full dry-run | Retool has payload/python export and package builder, rebuilt gateway has /agent/package/prepare and /agent/run-full-dry | Exists | Retool currently does not appear wired to /agent/package/prepare; may need light adapter or keep manual host call. |
| PDF generation | jsOifEhGeneratePackagePdfs calls /generate-oif-package-pdfs variants and /run-eh-package fallback | Rebuilt has /agent/pdf/generate; /run-eh-package dry-run compatibility only | Restore/adapt a safe /generate-oif-package-pdfs compatibility endpoint or patch Retool to call /agent/pdf/generate. |
| EH draft fill | jsAgentEhFillXlsFree_v12_1 calls /agent/eh/fill with live_fill=true, allow_submit=false | Rebuilt has /agent/eh/fill-dry-run, not /agent/eh/fill | For demo, add a guarded draft-only /agent/eh/fill endpoint only with demo_operator_confirmed=true and final_submit_blocked=true, or keep dry-run only. |
| Attachment scan/upload | No direct Retool endpoint hit found; attachment manifest UI exists | Rebuilt lacks /agent/attachments/scan and /agent/attachments/upload | If demo needs local attachment upload, add explicit gated endpoints; otherwise use existing workflow upload + OCR UI. |
| Generated files registration | Retool has qOifEhAgentLogRun, qOifEhGeneratedFiles, embedded fn_retool_oif_eh_register_generated_file | Rebuilt PDF endpoint currently does not register generated files to Supabase | Add only if demo requires generated files table update. |

## Recommended no-duplicate demo plan

1. Reuse existing workflow document upload + OCR UI if it works.
   - Start with btnOifWorkflowUploadLinkAndOcr and jsOifWorkflowUploadLinkAndOcr_v1.
   - Do not create a second document upload/OCR button.

2. Reuse existing OIF/EH package builder/generated files UI if present.
   - Use qOifExtensionPackageCandidates, qOifCreateExtensionPackages, qOifEhGeneratePayload, qOifEhPayloadPreview, qOifEhAttachmentManifest, qOifEhPythonExport, qOifEhGeneratedFiles.
   - Do not create duplicate payload/manifest/generated-file tables.

3. Restore/adapt old v11 endpoint logic into rebuilt v11 package only where needed.
   - Preferred minimal compatibility additions for demo: /generate-oif-package-pdfs, /agent/eh/fill, optionally /agent/attachments/scan and /agent/attachments/upload if the demo truly needs them.
   - Every restored endpoint must return execution_allowed_now=false for non-final actions and final_submit_blocked=true for draft/fill paths.

4. Add only missing Retool buttons, not duplicates.
   - The current UI already has buttons for package creation, payload generation, PDF generation, EH agent run, agent health, OCR analyze and OCR review.
   - Most likely only endpoint URL/safety wiring needs adjustment, not new UI.

5. Keep Robot Barát integration as explicit handoff/control, not hidden executor.
   - Robot Barát should not call local gateway endpoints directly for this demo.
   - If referenced, Robot Barát should only explain status/handoff and safety constraints.

## Proposed exact implementation next step

Use this as the next Codex task outline after this audit is reviewed:

    You are working in C:Projectshdd-retool-supabase.

    Goal:
    Patch the existing OIF/EH demo surfaces without duplicating UI.

    Input Retool export:
    RETOOL/current/UAHUN20v2_executor_runtime_guardrails.json

    Output Retool export:
    RETOOL/current/UAHUN20v2_oif_eh_demo_gateway_wiring.json

    Reuse existing components:
    - btnOifWorkflowUploadLinkAndOcr
    - jsOifWorkflowUploadLinkAndOcr_v1
    - btnOifEhAgentHealth
    - jsOifEhAgentHealth
    - btnOifEhGeneratePackagePdfs
    - jsOifEhGeneratePackagePdfs
    - btnOifEhRunAgent
    - jsOifEhAgentRunPackage or jsAgentEhFillXlsFree_v12_1 after safety patch
    - qOifEhGeneratedFiles
    - tblOifEhGeneratedFiles
    - qOifEhAgentRunLog
    - tblOifEhAgentRunLog
    - qOifEhPayloadPreview
    - qOifEhAttachmentManifest
    - qOifEhPythonExport

    Do not add duplicate package builder, generated files table, upload/OCR button, or Robot Barát executor integration.

    Patch gateway only if separately requested:
    LOCAL_AGENTS/eh_agent_gateway_v11_p02_pkg/eh_agent_gateway_v11_p02.py

    Restore/adapt endpoints only as gated demo endpoints:
    - POST /generate-oif-package-pdfs -> demo PDF generation, no final submit
    - POST /agent/eh/fill -> EH draft fill only, requires demo_operator_confirmed=true, allow_submit must remain false, response final_submit_blocked=true
    - POST /agent/attachments/upload -> only if attachment upload demo is required
    - POST /agent/attachments/scan -> only if attachment scan demo is required

    Endpoint choices for demo:
    - PDF generation: prefer existing Retool jsOifEhGeneratePackagePdfs UI, backed by restored /generate-oif-package-pdfs compatibility endpoint or carefully adapted /agent/pdf/generate.
    - EH draft fill: use /agent/eh/fill only if restored with demo_operator_confirmed=true and final_submit_blocked=true; otherwise use /agent/eh/fill-dry-run.
    - Document upload: reuse btnOifWorkflowUploadLinkAndOcr and jsOifWorkflowUploadLinkAndOcr_v1; do not route this through Robot Barát.

    What remains manual:
    - final EH/OIF submit
    - human review of generated PDFs/XLSM
    - operator confirmation before draft fill
    - deletion/cleanup of demo request after demo

    Safety:
    - no final submit
    - no hidden background execution
    - no page-load execution
    - explicit operator click only
    - no Robot_Barat_current.json changes
    - no Retool app JSON import until reviewed

## Safety constraints for demo

- No final EH/OIF submit.
- No hidden background execution.
- No page-load execution.
- Explicit operator click only.
- Any live draft action must require demo_operator_confirmed=true.
- Any draft/fill/generate response must include final_submit_blocked=true.
- allow_submit must remain false.
- execution_allowed_now must remain false unless a future owner-approved runtime design explicitly changes it; this demo should not do that.
- Robot Barát must not call the gateway or execute anything.
- Retool must not add hidden executor queries.
- The request must be deleted after demo.
- If generated files are registered, they must be demo/audit-scoped and traceable.

## Audit validation

- Markdown file exists: DOCS/OIF_EH_DEMO_EXISTING_SURFACES_AUDIT.md.
- No Retool JSON changed by this audit.
- No gateway Python changed by this audit.
- No SQL changed by this audit.
- No Robot_Barat_current.json changed by this audit.
- No local gateway, localhost, EnterHungary, or OIF endpoint was called by this audit.
- No commit was made.
