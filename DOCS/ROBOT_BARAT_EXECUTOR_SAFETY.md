# Robot Barát Executor Safety

## Rövid összefoglaló

A Robot Barát jelenlegi állapota pre-execution rendszer. Támogatja az ügyadatok elemzését, ajánlások készítését, action request létrehozását, emberi jóváhagyását, approved queue nézetét, executor readiness contract előkészítését, dry-run eredmények tárolását, final confirmation rögzítését és execution handoff readiness megjelenítését.

A rendszer jelenleg nem hajt végre semmit. Nincs local Python futtatás, nincs EnterHungary/OIF művelet, nincs email/Slack/Teams/webhook értesítés, nincs executor-alapú business-data mutation, és nincs olyan folyamat, amely action request státuszt `executed` értékre állítana.

## Current hard guardrail

A jelenlegi runtime guardrail állapot szándékosan tiltó:

```text
execution_allowed_now = false
runtime_enable_flag = false
local_agent_execution_enabled = false
eh_oif_execution_enabled = false
notifications_enabled = false
business_data_mutation_enabled = false
assertion_status = runtime_disabled_ok
```

Ez azt jelenti, hogy a jövőbeli executor integrációk sem tekinthetik futtathatónak a queue-ban lévő tételeket. A runtime guardrail registry explicit deny-all alapállapotban van.

## Pipeline overview

A Robot Barát pre-execution pipeline jelenlegi logikai folyamata:

```text
Case Assistant
→ Action Request
→ Human Approval
→ Approved Action Queue
→ Executor Readiness Contract
→ Dry Run Results
→ Final Confirmation Gate
→ Execution Handoff Readiness
→ Runtime Guardrails
→ future executor, currently disabled
```

A pipeline vége jelenleg nem executor, hanem egy biztonsági stop pont. Az Execution Handoff Readiness és Runtime Guardrails nézetek célja az, hogy a jövőbeli executor előfeltételei átláthatók legyenek, miközben a tényleges futtatás továbbra is tiltva marad.

## Supabase objects

### Case Assistant

- `public.agent_v2_get_case_assistant(...)`

### Action Request Approval

- `public.agent_action_requests`
- `public.agent_v2_get_action_requests(...)`
- `public.agent_v2_create_action_request(...)`
- `public.agent_v2_approve_action_request(...)`
- `public.agent_v2_reject_action_request(...)`
- `public.agent_v2_request_action_clarification(...)`

### Approved Queue

- `public.agent_v2_get_approved_action_queue(...)`

### Executor Readiness

- `public.agent_v2_get_executor_readiness_queue(...)`

### Dry Run

- `public.agent_action_dry_runs`
- `public.agent_v2_get_dry_run_results(...)`
- `public.agent_v2_record_dry_run_result(...)`
- `public.agent_v2_get_latest_dry_run_for_action_request(...)`

### Final Confirmation

- `public.agent_action_final_confirmations`
- `public.agent_v2_get_final_confirmation_gate(...)`
- `public.agent_v2_confirm_final_action_request(...)`
- `public.agent_v2_revoke_final_confirmation(...)`

### Execution Handoff

- `public.agent_v2_get_execution_handoff_readiness(...)`

### Runtime Guardrails

- `public.agent_executor_runtime_guardrails`
- `public.agent_v2_get_executor_runtime_guardrails()`
- `public.agent_v2_assert_executor_runtime_disabled()`

### Daily Briefing / Alert Center / Prioritized Queue

Kapcsolódó, nem executor jellegű Robot Barát objektumok:

- `public.agent_alert_rules`
- `public.agent_alert_events`
- `public.agent_alert_state`
- `public.agent_v2_alerts_preview(...)`
- `public.agent_v2_materialize_alert_events(...)`
- `public.agent_v2_get_alert_center_summary()`
- `public.agent_v2_acknowledge_alert_event(...)`
- `public.agent_v2_resolve_alert_event(...)`
- `public.agent_v2_suppress_alert_event(...)`
- `public.agent_v2_generate_daily_briefing(...)`
- `public.agent_v2_get_latest_daily_briefing()`
- `public.agent_v2_get_prioritized_work_queue(...)`

Ezek a komponensek megfigyelésre, összefoglalásra, priorizálásra és kontroll workflow-ra szolgálnak. Nem executor runtime-ok.

## Retool exports

A jelenlegi fázisban létrehozott vagy használt Retool exportok:

- `RETOOL/current/UAHUN20v2_case_assistant.json`
- `RETOOL/current/UAHUN20v2_action_request_approval_center_fixed.json`
- `RETOOL/current/UAHUN20v2_case_assistant_to_action_request.json`
- `RETOOL/current/UAHUN20v2_approved_action_queue.json`
- `RETOOL/current/UAHUN20v2_executor_readiness_contract.json`
- `RETOOL/current/UAHUN20v2_dry_run_results.json`
- `RETOOL/current/UAHUN20v2_final_confirmation_gate.json`
- `RETOOL/current/UAHUN20v2_execution_handoff_readiness.json`
- `RETOOL/current/UAHUN20v2_executor_runtime_guardrails.json`

## Retool safety rules

- Nincs execute button.
- Nincs local agent button.
- Nincs EH/OIF execution button.
- Nincs notification send button.
- Approval és final confirmation gombok csak Robot Barát kontroll táblákba írhatnak.
- Mutáló kontroll query-knek confirmation modalt kell kérniük.
- User-facing listákhoz előnyben kell részesíteni a HTML/list nézeteket, ha a `TableWidget2` renderelés megbízhatatlan.
- Nem lehet rejtett Retool query, amely executor műveletet indít.
- Nem lehet olyan UI esemény, amely jóváhagyás, dry-run és final confirmation után automatikusan végrehajt.

## What future executor work must NOT do without new explicit task

Jövőbeli executor munka új, explicit task nélkül nem teheti meg az alábbiakat:

- Nem olvashatja az approved queue-t automatikus végrehajtás céljából.
- Nem hagyhatja figyelmen kívül a runtime guardrails állapotát.
- Nem állíthatja `execution_allowed_now` értékét `true`-ra.
- Nem állíthat action request státuszt `executed` értékre.
- Nem hívhat local Python futtatást.
- Nem hívhat EnterHungary/OIF műveletet.
- Nem küldhet email/Slack/Teams/webhook vagy más külső értesítést.
- Nem módosíthat business táblákat executoron keresztül.
- Nem kerülheti meg a dry run lépést.
- Nem kerülheti meg a final confirmation lépést.
- Nem adhat hozzá rejtett executor query-t Retoolban.

## Future enablement requirements

Bármilyen jövőbeli executor tényleges futtatás előtt legalább ezek szükségesek:

- Új Supabase migration.
- Új smoke test.
- Explicit runtime enable flag design.
- Dry run revalidation közvetlen végrehajtás előtt.
- Audit log tábla és audit log írási szabályok.
- Operator identity/session modell.
- Rollback/failure strategy.
- Külön Retool review.
- Explicit emberi jóváhagyás a project ownertől.
- Runtime guardrail assertion közvetlenül a futtatási pont előtt.
- Bizonyítás, hogy az executor nem fut rejtetten page load, tab open vagy background refresh során.

## Smoke tests

A pipeline-hoz tartozó smoke tesztek:

- `SUPABASE/smoke_tests/robot_barat_case_assistant.sql`
- `SUPABASE/smoke_tests/robot_barat_action_request_approval_center.sql`
- `SUPABASE/smoke_tests/robot_barat_approved_action_queue.sql`
- `SUPABASE/smoke_tests/robot_barat_executor_readiness_contract.sql`
- `SUPABASE/smoke_tests/robot_barat_dry_run_results.sql`
- `SUPABASE/smoke_tests/robot_barat_final_confirmation_gate.sql`
- `SUPABASE/smoke_tests/robot_barat_execution_handoff_readiness.sql`
- `SUPABASE/smoke_tests/robot_barat_executor_runtime_guardrails.sql`

## Current status

As of this documentation, Robot Barát is pre-execution only.

The system can recommend, approve, validate, dry-run-record, confirm, and prepare handoff.

The system must not execute.
