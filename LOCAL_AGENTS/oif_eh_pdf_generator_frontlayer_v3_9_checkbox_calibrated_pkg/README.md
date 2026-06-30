# OIF/EH PDF generator v3.9 - 9.6 / 9.7 checkbox calibrated

Ez a csomag a v3.8 FEOR-binding folytatása.

Változás:
- a 9.6 Foglalkoztatás és 9.7 Vendégmunkás betétlap checkboxai már nem betű-baseline X-szel, hanem a hivatalos PDF checkbox-rect koordinátáira rajzolt, középre igazított X-stroke-kal készülnek;
- emiatt nem gond, ha az adott sorban az igen/nem checkboxok vagy oszlopok nincsenek tökéletesen egymás alatt;
- FEOR override továbbra is támogatott (`effective_feor_code`, `effective_feor_name`).

Indítás:

```powershell
cd C:\EH_AGENT\oif_eh_pdf_generator_frontlayer_v3_9_checkbox_calibrated_pkg

$env:SUPABASE_URL="https://qyteyqhtatuuiqcwdtvf.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY="IDE_A_VALODI_SUPABASE_SERVICE_ROLE_KEY"
$env:OIF_EH_GENERATED_BUCKET="oif-eh-generated"
$env:EH_AGENT_UPSTREAM_URL="http://127.0.0.1:8788"

py -m uvicorn eh_oif_pdf_generator_gateway_v2:app --host 127.0.0.1 --port 8787
```

Health:

```powershell
Invoke-RestMethod -Uri "https://eh-agent.hddirekt.com/health" -Method GET
```

Elvárt template_mode:

```text
v3.9-official-template-checkbox-calibrated
```

<!-- ROBOT_BARAT_REPO_PACKAGING_NOTES_2026_06_30 -->

## Repo packaging / demo safety notes - 2026-06-30

Ez a mappa a v3.9 official-template checkbox-calibrated PDF generator izolált repo-másolata.

Nem írja felül automatikusan a stabil office-host v3.5 PDF generátort. A 8787-es porton csak explicit demó deploy után induljon.

### Expected health metadata

```text
template_mode = v3.9-official-template-checkbox-calibrated
supported_application_types includes vendeg, vendeg_9_7, nemzeti, foglalkoztatasi_9_6
unsupported_yet = []
```

### Templates

A PDF sablonok a `templates/` mappában vannak. A forrásból megmaradt `templates_pdf/` mappa is jelen lehet.

- `9_tartozkodasi_engedely_kerelem_hu.pdf`
- `9_6_foglalkoztatas_hu.pdf`
- `9_7_vendegmunkas_hu.pdf`
- `9_12_nemzeti_kartya_hu.pdf`

### Office-host copy

```powershell
New-Item -ItemType Directory -Force "C:\EH_AGENT\oif_eh_pdf_generator_frontlayer_v3_9_checkbox_calibrated_pkg"
Copy-Item -Recurse -Force ".\LOCAL_AGENTS\oif_eh_pdf_generator_frontlayer_v3_9_checkbox_calibrated_pkg\*" "C:\EH_AGENT\oif_eh_pdf_generator_frontlayer_v3_9_checkbox_calibrated_pkg\"
```

### Install

```powershell
cd C:\EH_AGENT\oif_eh_pdf_generator_frontlayer_v3_9_checkbox_calibrated_pkg
py -m pip install -r requirements.txt
```

### Safe start on 8787

Állítsd le a régi 8787 processzt, majd:

```powershell
cd C:\EH_AGENT\oif_eh_pdf_generator_frontlayer_v3_9_checkbox_calibrated_pkg
py -m uvicorn eh_oif_pdf_generator_gateway_v2:app --host 127.0.0.1 --port 8787
```

### Health check

```powershell
Invoke-RestMethod -Method Get -Uri http://127.0.0.1:8787/health
```

### v11 bridge .env

```text
OIF_EH_PDF_GENERATOR_URL=http://127.0.0.1:8787/generate-oif-package-pdfs
ALLOW_PDF_GENERATOR_BRIDGE=true
EH_AGENT_ALLOW_SUBMIT=false
EH_AGENT_ALLOW_LIVE_FILL=false
```

### Safety

- PDF generálás megengedett demóra.
- EnterHungary/OIF submit nincs.
- Robot Barát nincs direkt executionre kötve.
- Hidden Retool execution nincs.
