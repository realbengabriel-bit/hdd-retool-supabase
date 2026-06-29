# EH Agent Gateway v11 P02-first package

## Cél

Ez a csomag a hiányzó EH Agent Gateway v11 P02-first package repo-beli, verziókövethető rekonstrukciója.

Service name: eh_agent_gateway_v11_p02
Version: 11.0.0-p02-first-rebuild
Target host: 127.0.0.1
Target port: 8788

A csomag később másolható az irodai Windows hostra:

    C:\EH_AGENT\eh_agent_gateway_v11_p02_pkg

## Safety status

Ez a gateway pre-execution és dry-run célú. Nem kapcsolódik Robot Baráthoz, nem futtat EnterHungary/OIF submitot, nem indít browser fillt, és nem végez business-data mutationt.

Hard safety állapot:

    execution_allowed_now = false
    live_fill_allowed = false
    submit_allowed = false
    robot_barat_integration = false

A rebuild kódban az EH_AGENT_ALLOW_LIVE_FILL és EH_AGENT_ALLOW_SUBMIT env flag akkor sem engedélyez executiont, ha valaki true-ra állítja őket. Ezeket a v11 rebuild tudatosan ignored/blocked állapotban kezeli.

## Mi van blokkolva

- Live EnterHungary/OIF submit
- Browser fill
- Selenium vagy Playwright automatizálás
- Local Python executor indítása más folyamatként
- Külső script futtatása
- Robot Barát integráció
- Email/Slack/Teams/webhook notification
- Business táblák executoron keresztüli módosítása

## Kapcsolat a legacy v1.2 csomaggal

Az irodai hoston lehet legacy EH local agent v1.2 vagy PDF generator a C:\EH_AGENT alatt. Ez a v11 P02-first gateway nem cseréli le automatikusan a legacy csomagot.

A legacy PDF generator bridge opcionális és alapból tiltott:

    ALLOW_PDF_GENERATOR_BRIDGE=false
    OIF_EH_PDF_GENERATOR_URL=http://127.0.0.1:8787

Ha később külön jóváhagyással true-ra állítják az ALLOW_PDF_GENERATOR_BRIDGE értéket, a /agent/pdf/generate endpoint csak dry-run/package-generation kompatibilitási bridge-ként használható. EH/OIF submit továbbra sem történhet.

## Kapcsolat Robot Baráttal

Robot Barát: NOT CONNECTED.

Ezt a csomagot nem szabad Robot Baráthoz kötni külön jövőbeli architecture review, migration, smoke test, audit log design, runtime enable flag design és project owner explicit jóváhagyás nélkül.

A Retool JS fájlok csak példák. Nem Retool app exportok, és nem szabad őket hidden/background executor queryként bekötni.

## Másolás az irodai hostra

A repo-ból később másold a teljes mappát ide:

    C:\EH_AGENT\eh_agent_gateway_v11_p02_pkg

Példa PowerShell parancs a repo rootból, az irodai hoston futtatva:

    New-Item -ItemType Directory -Force C:\EH_AGENT\eh_agent_gateway_v11_p02_pkg
    Copy-Item -Recurse -Force .\LOCAL_AGENTS\eh_agent_gateway_v11_p02_pkg\* C:\EH_AGENT\eh_agent_gateway_v11_p02_pkg\

## Telepítés

Az irodai hoston:

    cd C:\EH_AGENT\eh_agent_gateway_v11_p02_pkg
    .\install_requirements.ps1

Ez létrehozza a .venv környezetet, frissíti a pipet, és telepíti a requirements.txt csomagokat.

## Környezeti változók

Másold a .env.example fájlt .env néven, és töltsd ki a szükséges értékeket:

    Copy-Item .env.example .env

Ne tegyél valódi secretet a repo-ba.

Fontos env változók:

- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- EH_AGENT_PACKAGE_RPC
- EH_AGENT_PACKAGE_VIEW
- OIF_EH_PDF_GENERATOR_URL
- EH_AGENT_LEGACY_MODE
- EH_AGENT_ALLOW_LIVE_FILL
- EH_AGENT_ALLOW_SUBMIT
- EH_AGENT_RUN_DIR
- EH_AGENT_TOKEN
- ALLOW_PDF_GENERATOR_BRIDGE

## Indítás

Az irodai hoston:

    cd C:\EH_AGENT\eh_agent_gateway_v11_p02_pkg
    .\start_agent_8788.ps1

A start script safety bannert ír ki:

    LIVE FILL DISABLED
    SUBMIT DISABLED
    ROBOT BARAT NOT CONNECTED

## Health teszt

Az irodai hoston, külön PowerShell ablakban:

    cd C:\EH_AGENT\eh_agent_gateway_v11_p02_pkg
    .\test_health.ps1

A test_health.ps1 csak ezeket hívja:

- GET /health
- GET /version

Nem hív mutáló vagy dry-run POST endpointot.


## Supabase wrapper RPC

A v11 P02-first gateway Supabase package RPC beállítása:

    EH_AGENT_PACKAGE_RPC=get_oif_eh_agent_package_v11

A wrapper source-control migrationje:

    SUPABASE/migrations/20260630013000_add_eh_agent_gateway_v11_package_wrapper.sql

A wrapper csak package-preview/dry-run célú. A public.get_oif_eh_agent_package_v11(...) feloldja a workflow_case_id értéket, majd az eredeti public.get_oif_eh_agent_package(uuid) függvényre delegál. A válaszban az execution mezők továbbra is tiltottak:

    execution_allowed_now = false
    live_fill_allowed = false
    submit_allowed = false

Manuális irodai host teszt eredmény:

- /health PASS
- /capabilities PASS
- /agent/package/prepare PASS
- /agent/run-full-dry PASS

Execution a teszt alatt is disabled maradt. Nem történt EnterHungary/OIF submit, live browser fill, Robot Barát kapcsolat vagy notification küldés.

## Endpoint lista

- GET /health
- GET /version
- GET /capabilities
- POST /agent/package/prepare
- POST /agent/eh/fill-dry-run
- POST /agent/run-full-dry
- POST /agent/pdf/generate
- POST /run-eh-package

## Endpoint safety összefoglaló

### GET /health

Publikus health check. Visszaadja a service, version, mode, legacy_mode, pdf_generator_url, Supabase konfiguráció és run_dir állapotot. Execution itt is disabledként látszik.

### GET /version

Publikus verzió metadata.

### GET /capabilities

Ha EH_AGENT_TOKEN be van állítva, bearer tokent igényel. A capabilities válaszban live_fill=false, submit=false, notifications=false, robot_barat_integration=false és execution_allowed_now=false.

### POST /agent/package/prepare

P02-first package előkészítés. Supabase konfiguráció esetén megpróbálja az EH_AGENT_PACKAGE_RPC RPC-t hívni, alapértelmezett névvel: get_oif_eh_agent_package.

Ha nincs Supabase config, safe not_configured választ ad.

### POST /agent/eh/fill-dry-run

Csak dry-run checklistet ad. Nem nyit böngészőt, nem használ Selenium/Playwright eszközt, nem submitol.

### POST /agent/run-full-dry

Package prepare és fill dry-run kombinált ellenőrzés. Execution disabled.

### POST /agent/pdf/generate

Alapból blocked_bridge_disabled választ ad, mert ALLOW_PDF_GENERATOR_BRIDGE=false. Ha külön engedélyezik, csak PDF generator kompatibilitási bridge lehet, EH/OIF submit nélkül.

### POST /run-eh-package

Legacy v1.2 kompatibilitási endpoint. Régi payloadot elfogad, de csak dry-run viselkedésre tereli. Nem execute-ol.

## Future integration stages

1. Stage 0 - Host inventory and freeze
2. Stage 1 - Local health check only
3. Stage 2 - Payload and dry-run validation only
4. Stage 3 - Manual operator local execution outside Robot Barát
5. Stage 4 - Retool controlled handoff
6. Stage 5 - Future Robot Barát integration after explicit approval

A jelen csomag csak a Stage 0/Stage 1 előkészítéshez ad biztonságos, local-only alapot.
