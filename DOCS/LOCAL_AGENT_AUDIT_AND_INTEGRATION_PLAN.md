# Local Agent Audit and Integration Plan

## Rövid összefoglaló

Ez az audit a repo jelenlegi állapota alapján dokumentálja, hogy Robot Barát körül milyen local agent, local gateway, EnterHungary/OIF, dry-run, handoff és runtime guardrail jellegű elemek látszanak.

Az audit eredménye: a repo-ban jelenleg teljes pre-execution safety pipeline látszik, de nem találtam tényleges local gateway klienset, localhost/127.0.0.1:8788 hívást, Python agent futtatót, Playwright/Selenium böngésző-automatizálást vagy EH/OIF submit implementációt.

Robot Barát jelenlegi állapota továbbra is execution-disabled:

    execution_allowed_now = false
    runtime_enable_flag = false
    local_agent_execution_enabled = false
    eh_oif_execution_enabled = false
    notifications_enabled = false
    business_data_mutation_enabled = false

Ez a dokumentum nem engedélyez executiont, nem kapcsol Robot Barátot local agenthez, nem módosít production Supabase viselkedést, nem ad Retool execute gombot, és nem hoz létre EH/OIF submit flow-t.

## Current discovered assets

| Path | Purpose | Mode | Risk | Notes |
| --- | --- | --- | --- | --- |
| DOCS/ROBOT_BARAT_EXECUTOR_SAFETY.md | Executor safety és pre-execution pipeline dokumentáció | read-only/documentation | low | Rögzíti, hogy Robot Barát nem execute-ol. |
| DOCS/ROBOT_BARAT_AGENT_REGRESSION_TESTS.md | Manuális agent regressziós checklist | read-only/documentation | low | Tartalmaz execution refusal teszteket, local agent/EH/OIF tiltással. |
| DOCS/ROBOT_BARAT_AGENT_TEST_RESULTS_2026-06-29.md | Első Retool AI Agent playground tesztkör eredménye | read-only/documentation | low | PASS státuszt dokumentál pre-execution pilot használathoz. |
| RETOOL/agents/Robot_Barat_current.json | Robot Barát agent export és tool lista | preview/control; legacy execute-like artifact present but disabled | high | Tartalmaz disabled legacy agent_v2_execute_confirmed_action toolt és régi subflow szövegeket; a jelenlegi instrukciók szerint ezeket disabledként kell kezelni. |
| SUPABASE/migrations/20260629140000_add_robot_barat_action_request_approval_center.sql | Action Request Approval Center lifecycle table/RPC-k | control-table writes only | medium | public.agent_action_requests kontrolltáblába ír; nem futtat local agentet, nem submitol EH/OIF felé. |
| SUPABASE/migrations/20260629141000_add_robot_barat_approved_action_queue.sql | Approved Action Queue read model | read-only/preview | low | Jóváhagyott action requesteket listáz, execution nélkül. |
| SUPABASE/migrations/20260629142000_add_robot_barat_executor_readiness_contract.sql | Executor Readiness Contract | read-only/preview | medium | Future executor contract mezőket mutat, de execution_allowed_now = false. |
| SUPABASE/migrations/20260629143000_add_robot_barat_dry_run_results.sql | Dry-run result storage | control-table writes only | medium | Dry-run eredményt tárol public.agent_action_dry_runs táblában; nem futtat tényleges executor runtime-ot. |
| SUPABASE/migrations/20260629144000_add_robot_barat_final_confirmation_gate.sql | Final Confirmation Gate | control-table writes only | medium | Emberi final confirmation kontrollréteg; execution_allowed_now hard false. |
| SUPABASE/migrations/20260629145000_add_robot_barat_execution_handoff_readiness.sql | Execution Handoff Readiness | read-only/preview | high | A legközelebbi future executor handoff réteghez, de jelenleg csak readiness; execution_allowed_now = false. |
| SUPABASE/migrations/20260629150000_add_robot_barat_executor_runtime_guardrails.sql | Executor Runtime Guardrails | safety registry/assertion | medium | Safety-kritikus guardrail objektum; disabled alapállapotot és assertion RPC-t ad. |
| SUPABASE/smoke_tests/robot_barat_action_request_approval_center.sql | Action request smoke test | test/control only | low | Ellenőrzi, hogy nem lesz executed státusz. |
| SUPABASE/smoke_tests/robot_barat_approved_action_queue.sql | Approved queue smoke test | test/read-only | low | Queue behavior ellenőrzés execution nélkül. |
| SUPABASE/smoke_tests/robot_barat_executor_readiness_contract.sql | Readiness contract smoke test | test/read-only | low | Ellenőrzi, hogy execution_allowed_now false. |
| SUPABASE/smoke_tests/robot_barat_dry_run_results.sql | Dry-run storage smoke test | test/control only | low | Dry-run record ellenőrzés, execution nélkül. |
| SUPABASE/smoke_tests/robot_barat_final_confirmation_gate.sql | Final confirmation smoke test | test/control only | low | Final gate ellenőrzés, execution nélkül. |
| SUPABASE/smoke_tests/robot_barat_execution_handoff_readiness.sql | Handoff readiness smoke test | test/read-only | medium | Handoff-ready állapotot tesztel, de execution továbbra is false. |
| SUPABASE/smoke_tests/robot_barat_executor_runtime_guardrails.sql | Runtime guardrail smoke test | test/safety assertion | low | Disabled runtime assertiont ellenőriz. |
| RETOOL/current/UAHUN20v2_action_request_approval_center_fixed.json | Retool Action Request Approval Center export | control UI | medium | Approval/reject/clarification gombok csak control táblákhoz tartozó RPC-ket hívhatnak. |
| RETOOL/current/UAHUN20v2_approved_action_queue.json | Retool Approved Action Queue export | read-only/preview | low | Queue nézet; nem executor. |
| RETOOL/current/UAHUN20v2_executor_readiness_contract.json | Retool Executor Readiness Contract export | read-only/preview | medium | Future executor readiness UI, execution nélkül. |
| RETOOL/current/UAHUN20v2_dry_run_results.json | Retool Dry Run Results export | control UI | medium | Dry-run eredményrögzítés kontrollréteg; nem futtat agentet. |
| RETOOL/current/UAHUN20v2_final_confirmation_gate.json | Retool Final Confirmation Gate export | control UI | medium | Final confirmation UI; nem execute gomb. |
| RETOOL/current/UAHUN20v2_execution_handoff_readiness.json | Retool Execution Handoff Readiness export | read-only/preview | high | Handoff readiness nézet; nem kapcsolható executorhoz új safety design nélkül. |
| RETOOL/current/UAHUN20v2_executor_runtime_guardrails.json | Legfrissebb canonical Retool export | safety/status UI | medium | Runtime guardrail állapotot jelenít meg; execution disabled. |
| RETOOL/workflows/robot_barat_daily_briefing_scheduler.md | Daily Briefing Retool Workflow setup dokumentáció | scheduled backend refresh documentation | low | Daily briefing record generálás/frissítés, nem local agent és nem notification. |
| PROJECT_CONTEXT.md | Projekt kontextus | documentation/context | low | QR recognition említés kontextusban; nem találtam execution implementációt. |

### Local gateway / localhost inventory

| Category | Result |
| --- | --- |
| Local EH Gateway v11 source or config | Nem találtam repo alapján. |
| localhost, 127.0.0.1, port 8788 gateway client | Nem találtam repo alapján. |
| Tunnel, relay, Retool resource, proxy, or gateway auth config | Nem találtam repo alapján. |
| Python local agent runner | Nem találtam repo alapján. |
| Playwright/Selenium/browser-fill automation script | Nem találtam repo alapján. |
| EH/OIF live submit flow implementation | Nem találtam repo alapján. |
| Attachment manifest generator connected to local execution | Nem találtam repo alapján. |
| QR/back-side label local print/generation runner | Nem találtam repo alapján. |

### Current interpretation

A repo alapján a jelenlegi rendszer nem local execution rendszer. A meglévő komponensek pre-execution, approval, dry-run-recording, final-confirmation, handoff-readiness és runtime-disabled guardrail szerepűek.

A legfontosabb kockázat nem egy tényleges futtató kód, hanem a future executorhoz közeli nevek és régi agent subflow/tool referenciák félreértelmezése. Ezeket minden további munkában disabled legacy vagy future-only elemként kell kezelni.

## Known local gateway assumption

Feltételezésként létezhet a Windows hoston egy külön telepített Local EH Gateway v11, amely tipikusan 127.0.0.1:8788 címen adhatna health/version/capabilities jellegű endpointokat.

Ezt az audit nem hívta meg, nem validálta, és nem feltételezi, hogy Robot Barát vagy Retool Cloud számára elérhető.

Fontos architektúra-következmény:

- Retool Cloud és Robot Barát nem kezelheti adottnak a felhasználó gépén lévő localhost elérést.
- 127.0.0.1:8788 Retool Cloudból nem ugyanazt jelenti, mint a Windows hoston.
- Bármilyen jövőbeli integrációhoz külön tunnel/resource/proxy/auth design kell.
- A gatewayhez először csak explicit read-only health/capability check kapcsolódhat.
- EH/OIF submit vagy local browser fill nem engedélyezhető a jelenlegi guardrail állapot mellett.

## Required architecture before integration

### Stage 0 - Inventory and freeze

- Rögzíteni kell, pontosan milyen local gateway vagy local agent létezik a Windows hoston.
- Rögzíteni kell a gateway verzióját, endpoint listáját, auth modelljét, logolását és failure behaviorját.
- A jelenlegi Robot Barát runtime disabled állapotot freeze-elni kell.
- Nem szabad hidden Retool queryt, background executor queryt vagy automatikus queue consumer logikát hozzáadni.

### Stage 1 - Local health check only

Engedélyezhető legkorábban egy külön, explicit, read-only health check terv:

- /health
- /version
- /capabilities

Tiltott ebben a stage-ben:

- EH/OIF submit
- browser fill
- local Python execution
- file upload
- business data mutation
- notification send
- action request executed státuszra állítása

### Stage 2 - Payload and dry-run validation only

Ebben a stage-ben legfeljebb payload/dry-run validáció tervezhető:

- input payload schema validation
- attachment manifest validation
- missing file detection
- capability compatibility check
- dry-run result recording control table-be

Tiltott:

- EH/OIF submit
- EnterHungary live session vezérlés
- local browser automation
- production adatmutáció executoron keresztül

### Stage 3 - Manual operator local execution outside Robot Barát

Ha van validált local gateway, a tényleges futtatás először csak Robot Baráton kívüli, manuális operator folyamat lehet:

- human operator látja a dry-run eredményt
- human operator látja a final confirmation állapotot
- human operator külön, lokális környezetben dönt
- Robot Barát nem indít futtatást
- Robot Barát nem állít executed státuszt

### Stage 4 - Retool controlled handoff

Retoolban később csak kontrollált handoff felület jelenhet meg:

- explicit selected action request
- runtime guardrail assertion
- dry-run recency check
- final confirmation check
- audit identity
- no hidden execution query
- no auto-run on page load

Ebben a stage-ben sem szabad Robot Barátnak közvetlen executor runtime-ot hívnia.

### Stage 5 - Future Robot Barát integration

Robot Barát integráció csak külön jövőbeli feladatban lehetséges, legalább ezek után:

- új migration
- új smoke test
- audit log table
- explicit runtime enable flag design
- gateway auth/tunnel design
- failure/rollback stratégia
- Retool UI review
- project owner explicit approval

Addig Robot Barát execution irányban csak a safety pipeline állapotáról beszélhet.

## Safety requirements

- Robot Barát nem hívhat local Python agentet.
- Robot Barát nem hívhat Local EH Gateway endpointot.
- Robot Barát nem indíthat EnterHungary/OIF műveletet.
- Robot Barát nem küldhet email/Slack/Teams/webhook értesítést.
- Robot Barát nem módosíthat business táblákat executoron keresztül.
- Robot Barát nem állíthat action requestet executed státuszra.
- Robot Barát nem javasolhat hidden/background executor query-t Retoolban.
- Retool app nem tartalmazhat execute gombot új explicit approval nélkül.
- Semmilyen queue nem olvasható automatikus execution célból.
- execution_allowed_now és runtime_enable_flag nem állítható true-ra külön új design nélkül.
- Minden jövőbeli mutáló control querynek confirmation-required beállítás kell.
- Minden jövőbeli local gateway kapcsolatnak auditált auth, timeout, rate limit és failure-mode leírás kell.

## Future Supabase objects

Ezek future-only javaslatok. A jelen dokumentum nem hozza létre őket.

| Future object | Purpose | Notes |
| --- | --- | --- |
| public.agent_local_gateway_registry | Gateway instance metadata, version, capabilities, disabled/enabled state | Runtime flag default must remain disabled. |
| public.agent_local_gateway_health_checks | Health check audit history | Read-only health check result storage only. |
| public.agent_executor_audit_log | Executor handoff/execution audit | Required before any real executor path. |
| public.agent_executor_payload_validations | Payload and manifest validation results | Dry-run validation, no submit. |
| public.agent_executor_runtime_sessions | Future operator/runtime session metadata | Must include operator identity and explicit confirmation references. |
| public.agent_v2_get_local_gateway_capabilities(...) | Future read-only capability RPC | Must not call localhost directly from Supabase. |
| public.agent_v2_record_gateway_health_check(...) | Future control-table health record RPC | Must not imply execution readiness. |
| public.agent_v2_assert_execution_enablement(...) | Future hard gate assertion | Must fail closed unless all flags and approvals are valid. |

## Future Retool surfaces

Ezek future-only felületek. A jelen dokumentum nem ad hozzá Retool exportot vagy gombot.

| Future surface | Purpose | Safety expectation |
| --- | --- | --- |
| Local Gateway Health panel | Gateway version/capabilities/last health check megjelenítése | Read-only, no execute button. |
| Payload Validation panel | Manifest/payload dry-run validation eredmények | No EH/OIF submit. |
| Operator Handoff panel | Human operator handoff checklist | Confirmation required, no hidden query. |
| Executor Audit panel | Audit log megjelenítés | Read-only. |
| Runtime Enablement Review panel | Guardrail állapot és owner approval követése | Nem kapcsolhat flaget automatikusan. |

## Open questions

- Létezik-e tényleges Local EH Gateway v11 a Windows hoston, és ha igen, hol van dokumentálva?
- Mi a pontos gateway endpoint lista: /health, /version, /capabilities, más endpointok?
- Van-e auth token, mTLS, local-only allowlist vagy más gateway authentication?
- Hol keletkezik vagy keletkezne attachment manifest?
- Van-e QR/back-side label generálás a local gatewayben, vagy ez külön eszköz?
- Mi a Retool Cloud és Windows host közti jövőbeli kapcsolat terve: tunnel, self-hosted Retool, relay service vagy manuális operator export/import?
- Ki a project owner, aki explicit approvalt adhat execution enablementhez?
- Mi legyen az audit log retention és operator identity modell?
- Mi a failure/rollback stratégia, ha egy future executor félúton megáll?

## Immediate next step recommendation

A következő biztonságos lépés nem integration és nem execution.

Javasolt következő lépés:

1. Készíts külön, host-oldali inventory dokumentumot a tényleges Local EH Gateway v11 telepítésről.
2. Írd össze a gateway read-only endpointjait, auth modelljét és verzióját.
3. Ne kösd Robot Baráthoz és ne kösd Retoolhoz, amíg nincs jóváhagyott Stage 1 health-check design.
4. Ha a Stage 1 terv elkészült, külön migration/smoke/Retool review feladatban lehet read-only health állapotot modellezni.

Jelen státusz:

    Robot Barát local executor integration status: NOT CONNECTED
    Local gateway audit status: REPO-ONLY AUDIT COMPLETE
    Runtime execution status: DISABLED
    Recommended next step: Stage 0 host inventory
