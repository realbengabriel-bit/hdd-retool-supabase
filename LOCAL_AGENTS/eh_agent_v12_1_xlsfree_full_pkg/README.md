# EH Agent v12.1 — XLS-free / P02 payload-first / 9.6 + 9.7 + 9.12

Ez a csomag az EnterHungary helyi agent XLSM-függetlenített változata.

## Támogatott kérelmek

* Nemzeti Kártya / 9.12 → `/eh/cases/new/tartcelharm-c12`
* Foglalkoztatás / 9.6 hosszabbítás → `/eh/cases/new/tartcelharm-c6`
* Vendégmunkás / 9.7 hosszabbítás → `/eh/cases/new/tartcelharm-c7`

A route-ok és tabok a feltöltött EnterHungary HTML-ek alapján lettek pontosítva.

## Fő változások v12-höz képest

* Nem kell `ENTERHUNGARY.xlsm` adatforrásként.
* P02 / Retool / Supabase JSON payloadból tölt.
* A fő `tartcelharm` oldalt exact EH `name=` mezőkre is újratölti.
* 9.6 / 9.7 / 9.12 betétlapok exact EH `name=` mezőire külön ráemelés van.
* Szálláshely/szálláshelyváltozás bejelentése tabot is tudja tölteni.
* `--allow-submit` nélkül továbbra sem kattint beadásra / rögzítésre.

## Telepítés

```powershell
cd C:\\\\EH\\\_AGENT\\\\eh\\\_agent\\\_v12\\\_1\\\_xlsfree\\\_full\\\_pkg
py -m pip install --upgrade pip
py -m pip install -r requirements.txt
py -m playwright install chromium
```

## Indítás 8788-on

```powershell
cd C:\\\\EH\\\_AGENT\\\\eh\\\_agent\\\_v12\\\_1\\\_xlsfree\\\_full\\\_pkg

$env:SUPABASE\\\_URL="https://qyteyqhtatuuiqcwdtvf.supabase.co"
$env:SUPABASE\\\_SERVICE\\\_ROLE\\\_KEY="IDE\\\_A\\\_VALODI\\\_SERVICE\\\_ROLE\\\_KEY"
$env:EH\\\_AGENT\\\_PACKAGE\\\_RPC="get\\\_oif\\\_eh\\\_agent\\\_package"
$env:EH\\\_AGENT\\\_PACKAGE\\\_VIEW="v\\\_oif\\\_eh\\\_agent\\\_package\\\_source"
$env:OIF\\\_EH\\\_PDF\\\_GENERATOR\\\_URL="http://127.0.0.1:8787"
$env:EH\\\_AGENT\\\_LEGACY\\\_MODE="search\\\_only"
$env:EH\\\_AGENT\\\_ALLOW\\\_LIVE\\\_FILL="true"
$env:EH\\\_AGENT\\\_RUN\\\_DIR="C:\\\\EH\\\_AGENT

gent\\\_runs"
$env:EH\\\_FILL\\\_SCRIPT\\\_PATH="C:\\\\EH\\\_AGENT\\\\eh\\\_agent\\\_v12\\\_1\\\_xlsfree\\\_full\\\_pkg\\\\eh\\\_enterhungary\\\_assistant\\\_v12\\\_1\\\_payload\\\_first.py"
$env:EH\\\_FILL\\\_COMMAND\\\_TEMPLATE='py "$eh\\\_fill\\\_script\\\_path" --json "$json\\\_path" --application-type $application\\\_type'

py -m uvicorn eh\\\_agent\\\_gateway\\\_v12\\\_1\\\_xlsfree:app --host 127.0.0.1 --port 8788
```

## Health

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8788/health" -Method GET
```

Jó jel:

```text
service: eh\\\_agent\\\_gateway\\\_v12\\\_1\\\_xlsfree
version: 12.1.0-xlsfree-full-eh-html-mapped
xls\\\_free: True
accommodation\\\_tab\\\_supported: True
```

## Közvetlen lokális teszt

```powershell
py eh\\\_enterhungary\\\_assistant\\\_v12\\\_1\\\_payload\\\_first.py `
  --json .\\\\examples\\\\example\\\_payload\\\_foglalkoztatasi\\\_96.json `
  --application-type foglalkoztatasi\\\_9\\\_6
```

9.7:

```powershell
py eh\\\_enterhungary\\\_assistant\\\_v12\\\_1\\\_payload\\\_first.py `
  --json .\\\\examples\\\\example\\\_payload\\\_vendeg\\\_97.json `
  --application-type vendeg\\\_9\\\_7
```

Nemzeti:

```powershell
py eh\\\_enterhungary\\\_assistant\\\_v12\\\_1\\\_payload\\\_first.py `
  --json .\\\\examples\\\\example\\\_payload\\\_nemzeti\\\_912.json `
  --application-type nemzeti
```

Ha a szálláshely tabot át akarod ugrani:

```powershell
py eh\\\_enterhungary\\\_assistant\\\_v12\\\_1\\\_payload\\\_first.py `
  --json .\\\\examples\\\\example\\\_payload\\\_vendeg\\\_97.json `
  --application-type vendeg\\\_9\\\_7 `
  --skip-accommodation
```

## Feltöltött HTML-ekből készült segédlet

A csomagban van:

```text
eh\\\_uploaded\\\_form\\\_catalog.json
```

Ebben benne van az új kérelem oldal, a 9.6/9.7/9.12 edit oldalak, a szálláshely tab és a fájlmelléklet tab field-katalógusa.


<!-- ROBOT_BARAT_REPO_PACKAGING_NOTES_2026_06_30 -->

## Repo packaging / demo safety notes - 2026-06-30

Ez a mappa az EH v12.1 XLS-free, P02/Retool/Supabase JSON payload alapú browser/draft-fill csomag izolált repo-másolata.

Nem írja felül a stabil office-host v11 P02 gatewayt:

- `C:\EH_AGENT\eh_agent_gateway_v11_p02_pkg` - port `8788`
- `C:\EH_AGENT\oif_eh_pdf_generator_frontlayer_v3_5_insurancex_pkg` - port `8787` jelenlegi stabil PDF generator

### Safety policy

- Final submit / beadás tilos.
- Robot Barát nincs közvetlen gateway executionre kötve.
- Nincs hidden Retool execution.
- Demo defaultban ne használj `--allow-submit` kapcsolót.
- `.eh_edge_profile/`, `.env`, `agent_runs/`, `__pycache__/` és `*.pyc` nem kerülhet repoba.

### Office-host copy

```powershell
New-Item -ItemType Directory -Force "C:\EH_AGENT\eh_agent_v12_1_xlsfree_full_pkg"
Copy-Item -Recurse -Force ".\LOCAL_AGENTS\eh_agent_v12_1_xlsfree_full_pkg\*" "C:\EH_AGENT\eh_agent_v12_1_xlsfree_full_pkg\"
```

### Install

```powershell
cd C:\EH_AGENT\eh_agent_v12_1_xlsfree_full_pkg
py -m pip install -r requirements.txt
py -m playwright install chromium
```

### Repo syntax checks

```powershell
python -m py_compile LOCAL_AGENTS\eh_agent_v12_1_xlsfree_full_pkg\eh_agent_gateway_v12_1_xlsfree.py
python -m py_compile LOCAL_AGENTS\eh_agent_v12_1_xlsfree_full_pkg\eh_enterhungary_assistant_v12_1_payload_first.py
python -m py_compile LOCAL_AGENTS\eh_agent_v12_1_xlsfree_full_pkg\eh_enterhungary_assistant_v12_payload_first.py
python -m py_compile LOCAL_AGENTS\eh_agent_v12_1_xlsfree_full_pkg\eh_enterhungary_assistant_legacy_v10.py
python -m py_compile LOCAL_AGENTS\eh_agent_v12_1_xlsfree_full_pkg\eh_melleklet_assistant_v9_projectroot_tarteng_fix.py
```

### Manual no-submit example

A pontos CLI kapcsolók a helyi script aktuális help kimenetétől függenek. A projekt default parancsa ne tartalmazzon `--allow-submit` kapcsolót.

```powershell
cd C:\EH_AGENT\eh_agent_v12_1_xlsfree_full_pkg
py .\eh_agent_gateway_v12_1_xlsfree.py --payload .\examples\minimal_payload_foglalkoztatasi_96.json --draft-save --demo-operator-confirmed
```
