# EH Agent Gateway v11 P02 demo runbook - 2026-06-30

## Cél

Ez a runbook a demó előtti, kézi operátori OIF/EH gateway próbához készült. A demó scope kizárólag:

- package prepare / payload preview
- PDF generálás, ha a legacy 8787 bridge külön elindult és engedélyezett
- EH draft-fill demó endpoint ellenőrzése
- dry-run és safety flag ellenőrzés

Nem része a demónak végleges EnterHungary/OIF beadás, Robot Barát executor kapcsolat, notification küldés vagy business-data mutation.

## Hard safety baseline

```text
execution_allowed_now = false
final_submit_blocked = true
live_fill_allowed = false
submit_allowed = false
robot_barat_integration = false
```

## 1. Legacy PDF bridge indítása, csak ha kell

Ha a PDF generálás demóhoz a legacy PDF generator bridge szükséges, külön ablakban indítsd a 8787-es szolgáltatást az irodai hoston.

Alapértelmezett bridge URL:

```text
OIF_EH_PDF_GENERATOR_URL=http://127.0.0.1:8787
```

Ha a bridge nem fut vagy nincs engedélyezve, a v11 gateway biztonságosan `blocked_bridge_disabled` választ ad.

## 2. v11 gateway indítása 8788-on

Az irodai hoston:

```powershell
cd C:\EH_AGENT\eh_agent_gateway_v11_p02_pkg
.\start_agent_8788.ps1
```

A gateway cél host/port:

```text
127.0.0.1:8788
```

Cloudflare/demo route esetén a Retool Agent base URL mezőben használható:

```text
https://eh-agent-api.hddirekt.com
```

## 3. .env beállítás

A demóhoz javasolt értékek:

```text
EH_AGENT_PACKAGE_RPC=get_oif_eh_agent_package_v11
OIF_EH_PDF_GENERATOR_URL=http://127.0.0.1:8787
EH_AGENT_ALLOW_SUBMIT=false
EH_AGENT_ALLOW_LIVE_FILL=false
ALLOW_PDF_GENERATOR_BRIDGE=true
```

Az `ALLOW_PDF_GENERATOR_BRIDGE=true` csak a PDF demo idejére kell, és csak akkor, ha a 8787-es legacy PDF generator bridge tényleg fut. Az `EH_AGENT_ALLOW_SUBMIT` és `EH_AGENT_ALLOW_LIVE_FILL` globálisan nem engedélyez executiont: a v11 P02 gateway safety válasza továbbra is tiltott állapotot ad vissza.

## 4. Health teszt

```powershell
Invoke-RestMethod -Method Get -Uri http://127.0.0.1:8788/health
```

Elvárt: `ok=true`, `execution_allowed_now=false`, `submit_allowed=false`.

## 5. Capabilities teszt

```powershell
Invoke-RestMethod -Method Get -Uri http://127.0.0.1:8788/capabilities
```

Elvárt: `live_fill=false`, `submit=false`, `robot_barat_integration=false`.

## 6. Package prepare teszt

```powershell
$body = @{
  workflow_case_id = "<workflow_case_id>"
  requested_by = "demo-operator"
  dry_run = $true
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8788/agent/package/prepare -ContentType "application/json" -Body $body
```

Elvárt: package preview vagy biztonságos, olvasható source warning. Nincs submit.

## 7. PDF generálás demo endpoint

```powershell
$body = @{
  workflow_case_id = "<workflow_case_id>"
  requested_by = "demo-operator"
  demo_operator_confirmed = $true
  dry_run = $true
  allow_submit = $false
  live_fill = $false
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8788/generate-oif-package-pdfs -ContentType "application/json" -Body $body
```

Elvárt safety mezők:

```text
execution_allowed_now = false
final_submit_blocked = true
submit_allowed = false
execution_scope = demo_pdf_generation_only
robot_barat_integration = false
```

Ha `demo_operator_confirmed=true` hiányzik, elvárt válasz: `blocked_confirmation_required` HTTP 400.

## 8. EH draft-fill demo endpoint

```powershell
$body = @{
  workflow_case_id = "<workflow_case_id>"
  requested_by = "demo-operator"
  demo_operator_confirmed = $true
  allow_submit = $false
  live_fill = $true
  use_existing_pdfs = $true
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8788/agent/eh/fill -ContentType "application/json" -Body $body
```

Elvárt: ha nincs tényleges draft-fill adapter ebben a host csomagban, `status=not_implemented_on_this_host_package`, plusz `manual_next_step` és `missing_capability`. Ez demó szempontból elfogadható fallback, nem hiba.

## 9. Amit nem szabad kattintani EnterHungaryben

- Nem szabad végleges submit/beadás gombot kattintani.
- Nem szabad éles feltöltést vagy végleges csomagküldést indítani.
- Nem szabad olyan böngésző automatizmust indítani, amelyet a gateway safety válasza nem tiltottként jelez.
- Nem szabad a demo requestet a bemutató után bent hagyni.

## 10. Demo request törlés / cleanup

A bemutató után az operátor törölje vagy kézzel tisztítsa a demóhoz létrehozott EnterHungary draft/request állapotot. A gateway válaszban is szerepelnie kell:

```text
request_must_be_deleted_after_demo = true
```

## 11. Fallback, ha live draft-fill nincs implementálva

Ha `/agent/eh/fill` `not_implemented_on_this_host_package` választ ad, a demó továbbra is bemutatható ezekkel:

1. `/agent/package/prepare` eredmény.
2. Retool payload preview.
3. Attachment manifest.
4. Generált PDF fájlok táblája.
5. Dry-run checklist.
6. Safety flag-ek: `final_submit_blocked=true`, `execution_allowed_now=false`.

## Retool demó szabályok

- Csak explicit gombnyomás indíthat gateway hívást.
- Nincs page-load futtatás.
- Nincs hidden/background executor query.
- A Retool hívásoknak `demo_operator_confirmed=true` értéket kell küldeniük.
- A válaszban kötelező ellenőrizni: `execution_allowed_now=false`, `final_submit_blocked=true`, `submit_allowed=false`.
- Robot Barát nem hívja a gateway-t, és nem kap executor kapcsolatot ebben a demóban.

## Záró státusz

A v11 P02 demo gateway továbbra is pre-execution/demo-only. PDF generálás és EH draft-fill demó felület használható, végleges beadás tiltva.
