from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from string import Template
from typing import Any, Dict, List, Optional, Tuple

import requests
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

SERVICE_NAME = "eh_agent_gateway_v12_1_xlsfree"
SERVICE_VERSION = "12.1.0-xlsfree-full-eh-html-mapped"
LEGACY_MODE = os.getenv("EH_AGENT_LEGACY_MODE", "search_only")  # disabled/search_only/allow_readonly

DEFAULT_RUN_ROOT = Path(os.getenv("EH_AGENT_RUN_DIR", "./agent_runs")).resolve()
DEFAULT_TIMEOUT_SECONDS = int(os.getenv("EH_AGENT_SUBPROCESS_TIMEOUT_SECONDS", "3600"))

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_PACKAGE_RPC = os.getenv("EH_AGENT_PACKAGE_RPC", "get_oif_eh_agent_package")
SUPABASE_PACKAGE_VIEW = os.getenv("EH_AGENT_PACKAGE_VIEW", "v_oif_eh_agent_package_source")

PDF_GENERATOR_URL = os.getenv("OIF_EH_PDF_GENERATOR_URL", "http://127.0.0.1:8787").rstrip("/")
EH_FILL_SCRIPT_PATH = os.getenv("EH_FILL_SCRIPT_PATH", r"C:\EH_AGENT\eh_agent_v12_1_xlsfree_full_pkg\eh_enterhungary_assistant_v12_1_payload_first.py")
EH_ATTACH_SCRIPT_PATH = os.getenv("EH_ATTACH_SCRIPT_PATH", r"C:\EH_AGENT\eh_melleklet_assistant_v9_projectroot_tarteng_fix.py")

# Safe default: no live browser fill unless explicitly enabled.
EH_AGENT_ALLOW_LIVE_FILL = os.getenv("EH_AGENT_ALLOW_LIVE_FILL", "false").lower() in {"1", "true", "yes", "igen"}
EH_FILL_COMMAND_TEMPLATE = os.getenv("EH_FILL_COMMAND_TEMPLATE", r"py \"$eh_fill_script_path\" --json \"$json_path\" --application-type $application_type")
EH_ATTACH_SCAN_COMMAND_TEMPLATE = os.getenv("EH_ATTACH_SCAN_COMMAND_TEMPLATE", "")
EH_ATTACH_UPLOAD_COMMAND_TEMPLATE = os.getenv("EH_ATTACH_UPLOAD_COMMAND_TEMPLATE", "")

app = FastAPI(
    title="EH Agent Gateway v12.1 XLS-free",
    version=SERVICE_VERSION,
    description="P02-first EnterHungary/OIF XLS-free agent wrapper with 9.6/9.7/9.12 HTML-mapped routes.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class AgentBaseRequest(BaseModel):
    workflow_case_id: str = Field(..., description="P02/UAHUN workflow_case_id")
    force_refresh: bool = False
    additional_payload: Optional[Dict[str, Any]] = None


class PdfGenerateRequest(AgentBaseRequest):
    app_type: Optional[str] = None
    dry_run: bool = False


class EhFillRequest(AgentBaseRequest):
    live_fill: bool = False
    allow_submit: bool = False
    use_existing_pdfs: bool = True
    xlsx_path: Optional[str] = None
    command_template_override: Optional[str] = None


class AttachmentRequest(AgentBaseRequest):
    package_dir: Optional[str] = None
    dry_run: bool = True
    command_template_override: Optional[str] = None


class RunFullDryRequest(AgentBaseRequest):
    generate_pdf: bool = True
    scan_attachments: bool = False


class LegacyRunRequest(BaseModel):
    workflow_case_id: Optional[str] = None
    mode: Optional[str] = "dry_run"
    dry_run: Optional[bool] = True
    payload: Optional[Dict[str, Any]] = None


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def new_run_dir(prefix: str = "run") -> Tuple[str, Path]:
    run_id = f"{prefix}_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:10]}"
    run_dir = DEFAULT_RUN_ROOT / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    return run_id, run_dir


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, default=str)


def read_json_if_exists(path: Path) -> Any:
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def bool_status(value: bool, ok_label: str = "ok", bad_label: str = "missing") -> Dict[str, Any]:
    return {"ok": bool(value), "status": ok_label if value else bad_label}


def get_supabase_headers(prefer: Optional[str] = None) -> Dict[str, str]:
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_URL vagy SUPABASE_SERVICE_ROLE_KEY nincs beállítva az agent hoston.",
        )

    headers = {
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    return headers


def supabase_rpc_package(workflow_case_id: str) -> Optional[Dict[str, Any]]:
    url = f"{SUPABASE_URL}/rest/v1/rpc/{SUPABASE_PACKAGE_RPC}"
    payload = {"p_workflow_case_id": workflow_case_id}
    resp = requests.post(url, headers=get_supabase_headers(), json=payload, timeout=30)

    if resp.status_code in {404, 405}:
        return None

    if not resp.ok:
        raise HTTPException(status_code=502, detail={
            "message": "Supabase RPC hiba",
            "status_code": resp.status_code,
            "body": safe_text(resp),
            "rpc": SUPABASE_PACKAGE_RPC,
        })

    data = resp.json()
    if isinstance(data, dict):
        return data
    return {"ok": True, "data": data}


def supabase_view_package(workflow_case_id: str) -> Dict[str, Any]:
    url = f"{SUPABASE_URL}/rest/v1/{SUPABASE_PACKAGE_VIEW}"
    params = {
        "workflow_case_id": f"eq.{workflow_case_id}",
        "limit": "1",
    }
    resp = requests.get(url, headers=get_supabase_headers(), params=params, timeout=30)

    if not resp.ok:
        raise HTTPException(status_code=502, detail={
            "message": "Supabase view hiba",
            "status_code": resp.status_code,
            "body": safe_text(resp),
            "view": SUPABASE_PACKAGE_VIEW,
        })

    rows = resp.json()
    if not rows:
        return {
            "ok": False,
            "error": "not_found_or_not_p02_new",
            "message": "Nem található P02 új rendszerű workflow_case_id az agent source view-ban.",
            "workflow_case_id": workflow_case_id,
        }

    return {"ok": True, "data": {"workflow": rows[0]}}


def load_agent_package(workflow_case_id: str) -> Dict[str, Any]:
    rpc_data = supabase_rpc_package(workflow_case_id)
    if rpc_data is not None:
        return normalize_package_response(rpc_data, workflow_case_id)
    return normalize_package_response(supabase_view_package(workflow_case_id), workflow_case_id)


def normalize_package_response(raw: Dict[str, Any], workflow_case_id: str) -> Dict[str, Any]:
    # RPC can return {ok:true,data:{...}} or directly package JSON.
    if not isinstance(raw, dict):
        return {"ok": False, "error": "invalid_package_response", "raw": raw}

    if raw.get("ok") is False:
        return raw

    data = raw.get("data", raw)
    if isinstance(data, list):
        if not data:
            return {"ok": False, "error": "not_found", "workflow_case_id": workflow_case_id}
        data = data[0]

    if not isinstance(data, dict):
        return {"ok": False, "error": "invalid_package_data", "data": data}

    return {
        "ok": True,
        "workflow_case_id": workflow_case_id,
        "source_mode": infer_source_mode(data),
        "legacy_mode": LEGACY_MODE,
        "data": data,
    }


def infer_source_mode(data: Dict[str, Any]) -> str:
    workflow = data.get("workflow") if isinstance(data.get("workflow"), dict) else data
    bucket = str(workflow.get("uahun_source_bucket") or "").lower()
    label = str(workflow.get("uahun_source_label") or "").lower()
    legacy_id = str(workflow.get("legacy_uahun_id") or "").strip()
    source_blob = " ".join([bucket, label]).lower()
    if "legacy" in source_blob or "excel" in source_blob:
        return "legacy_search_only"
    if legacy_id and not workflow.get("workflow_case_id"):
        return "legacy_search_only"
    return "p02_new"


def assert_p02_operational(package: Dict[str, Any]) -> None:
    mode = package.get("source_mode")
    if mode != "p02_new":
        raise HTTPException(status_code=409, detail={
            "message": "Az EH agent csak új P02/02 operatív workflow-ra futtatható. Legacy csak kereső/archív réteg.",
            "source_mode": mode,
            "legacy_mode": LEGACY_MODE,
        })


def safe_text(resp: requests.Response, limit: int = 4000) -> str:
    try:
        txt = resp.text
    except Exception:
        return ""
    return txt[:limit]


def request_json_or_empty(request: Request) -> Dict[str, Any]:
    # Not used currently, kept for future compatibility.
    return {}


def check_pdf_generator() -> Dict[str, Any]:
    try:
        resp = requests.get(f"{PDF_GENERATOR_URL}/health", timeout=4)
        return {
            "ok": resp.ok,
            "status_code": resp.status_code,
            "url": PDF_GENERATOR_URL,
            "body": resp.json() if resp.headers.get("content-type", "").startswith("application/json") else safe_text(resp, 500),
        }
    except Exception as e:
        return {"ok": False, "url": PDF_GENERATOR_URL, "error": str(e)}


def check_python_module(module_name: str) -> Dict[str, Any]:
    try:
        __import__(module_name)
        return {"ok": True, "module": module_name}
    except Exception as e:
        return {"ok": False, "module": module_name, "error": str(e)}


def render_command(template_text: str, values: Dict[str, Any]) -> str:
    try:
        return Template(template_text).safe_substitute(values)
    except Exception:
        # Also support {workflow_case_id} style for convenience.
        try:
            return template_text.format(**values)
        except Exception as e:
            raise HTTPException(status_code=500, detail={
                "message": "Command template render hiba",
                "error": str(e),
                "template": template_text,
            })


def run_shell_command(command: str, run_dir: Path, timeout_seconds: int = DEFAULT_TIMEOUT_SECONDS) -> Dict[str, Any]:
    started = time.time()
    log_path = run_dir / "subprocess.log"
    result_path = run_dir / "subprocess_result.json"

    with log_path.open("w", encoding="utf-8") as log:
        log.write(f"[{utc_now_iso()}] COMMAND:\n{command}\n\n")
        log.flush()
        proc = subprocess.run(
            command,
            shell=True,
            cwd=str(run_dir),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout_seconds,
        )
        log.write("\n--- STDOUT ---\n")
        log.write(proc.stdout or "")
        log.write("\n--- STDERR ---\n")
        log.write(proc.stderr or "")

    result = {
        "ok": proc.returncode == 0,
        "returncode": proc.returncode,
        "duration_seconds": round(time.time() - started, 2),
        "command": command,
        "log_path": str(log_path),
        "stdout_tail": (proc.stdout or "")[-4000:],
        "stderr_tail": (proc.stderr or "")[-4000:],
    }
    write_json(result_path, result)
    return result


def get_nested(data: Dict[str, Any], *keys: str) -> Any:
    cur: Any = data
    for key in keys:
        if not isinstance(cur, dict):
            return None
        cur = cur.get(key)
    return cur


def first_non_empty(*values: Any) -> Any:
    for value in values:
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        if isinstance(value, list) and not value:
            continue
        return value
    return None


def infer_application_type_for_agent(data: Dict[str, Any]) -> str:
    workflow = data.get("workflow") if isinstance(data.get("workflow"), dict) else {}
    package_detail = data.get("package") if isinstance(data.get("package"), dict) else {}
    bmh = data.get("bmh") if isinstance(data.get("bmh"), dict) else {}
    blob = " ".join(str(x or "") for x in [
        package_detail.get("application_type"), package_detail.get("application_type_code"), package_detail.get("app_type"),
        workflow.get("application_type"), workflow.get("request_code"), workflow.get("case_type"), bmh.get("application_type"),
        data.get("application_type"), data.get("application_type_code"), data.get("app_type"), data.get("case_type"),
    ]).lower()
    if "9_6" in blob or "9.6" in blob or "foglalkoztatas" in blob or "foglalkoztatás" in blob or "employment" in blob or "extension" == blob.strip():
        return "foglalkoztatasi_9_6"
    if "9_7" in blob or "9.7" in blob or "guest_worker" in blob or "guest worker" in blob or "vendegmunkas" in blob or "vendégmunkás" in blob:
        return "vendeg_9_7"
    if "9_12" in blob or "9.12" in blob or "nemzeti" in blob or "national" in blob:
        return "nemzeti"
    if "vendeg" in blob or "guest" in blob:
        return "vendeg_9_7"
    return "nemzeti"



def validate_agent_payload(package: Dict[str, Any]) -> Dict[str, Any]:
    data = package.get("data") or {}
    workflow = data.get("workflow") if isinstance(data.get("workflow"), dict) else data
    core = data.get("core") if isinstance(data.get("core"), dict) else {}
    accommodation = data.get("accommodation") if isinstance(data.get("accommodation"), dict) else {}
    package_detail = data.get("package") if isinstance(data.get("package"), dict) else {}
    bmh = data.get("bmh") if isinstance(data.get("bmh"), dict) else {}
    documents = data.get("documents") if isinstance(data.get("documents"), list) else []

    checks = [
        {
            "key": "workflow_case_id",
            "label": "Workflow case ID",
            "ok": bool(first_non_empty(workflow.get("workflow_case_id"), package.get("workflow_case_id"))),
        },
        {
            "key": "candidate_id",
            "label": "Candidate ID",
            "ok": bool(first_non_empty(workflow.get("candidate_id"), core.get("candidate_id"))),
        },
        {
            "key": "assignment_id",
            "label": "Assignment ID",
            "ok": bool(first_non_empty(workflow.get("assignment_id"), core.get("assignment_id"))),
        },
        {
            "key": "full_name",
            "label": "Név",
            "ok": bool(first_non_empty(workflow.get("full_name"), core.get("full_name"))),
        },
        {
            "key": "birth_date",
            "label": "Születési dátum",
            "ok": bool(first_non_empty(workflow.get("birth_date"), core.get("birth_date"))),
        },
        {
            "key": "nationality",
            "label": "Állampolgárság",
            "ok": bool(first_non_empty(workflow.get("nationality"), core.get("nationality"))),
        },
        {
            "key": "passport_number",
            "label": "Útlevélszám",
            "ok": bool(first_non_empty(workflow.get("passport_number"), core.get("passport_number"))),
        },
        {
            "key": "passport_expiry_date",
            "label": "Útlevél lejárat",
            "ok": bool(first_non_empty(workflow.get("passport_expiry_date"), core.get("passport_expiry_date"))),
        },
        {
            "key": "partner_or_employer",
            "label": "Partner / munkáltató",
            "ok": bool(first_non_empty(workflow.get("validated_partner_name"), workflow.get("partner_name"), core.get("partner_name"))),
        },
        {
            "key": "feor",
            "label": "FEOR / munkakör",
            "ok": bool(first_non_empty(workflow.get("feor"), core.get("feor"), package_detail.get("feor"))),
        },
        {
            "key": "accommodation",
            "label": "Szállásadat",
            "ok": bool(first_non_empty(
                workflow.get("planned_accommodation"),
                workflow.get("accommodation_status"),
                accommodation.get("address"),
                accommodation.get("szallas_cim"),
            )),
        },
        {
            "key": "application_type",
            "label": "Kérelem típusa",
            "ok": bool(first_non_empty(
                package_detail.get("app_type"),
                package_detail.get("application_type"),
                workflow.get("package_status"),
                bmh.get("application_type"),
            )),
            "warning_only": True,
        },
        {
            "key": "generated_pdf_or_documents",
            "label": "Generált PDF / dokumentum",
            "ok": bool(documents) or bool(first_non_empty(package_detail.get("pdf_url"), package_detail.get("storage_path"))),
            "warning_only": True,
        },
    ]

    hard_missing = [c for c in checks if not c.get("ok") and not c.get("warning_only")]
    warnings = [c for c in checks if not c.get("ok") and c.get("warning_only")]

    return {
        "ok": len(hard_missing) == 0,
        "hard_missing_count": len(hard_missing),
        "warning_count": len(warnings),
        "hard_missing": hard_missing,
        "warnings": warnings,
        "checks": checks,
    }


@app.get("/health")
def health() -> Dict[str, Any]:
    fill_script = Path(EH_FILL_SCRIPT_PATH)
    attach_script = Path(EH_ATTACH_SCRIPT_PATH)

    return {
        "ok": True,
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "time": utc_now_iso(),
        "host": {
            "python": sys.version.split()[0],
            "platform": platform.platform(),
            "cwd": str(Path.cwd()),
        },
        "mode": {
            "p02_first": True,
            "legacy_mode": LEGACY_MODE,
            "legacy_operational_run_allowed": False,
            "live_fill_allowed_by_env": EH_AGENT_ALLOW_LIVE_FILL,
            "supported_application_types": ["nemzeti", "nemzeti_9_12", "foglalkoztatasi_9_6", "vendeg_9_7", "guest_worker_extension"],
            "xls_free": True,
            "accommodation_tab_supported": True,
        },
        "supabase": {
            "url_configured": bool(SUPABASE_URL),
            "service_role_key_configured": bool(SUPABASE_SERVICE_ROLE_KEY),
            "package_rpc": SUPABASE_PACKAGE_RPC,
            "package_view": SUPABASE_PACKAGE_VIEW,
        },
        "pdf_generator": check_pdf_generator(),
        "scripts": {
            "eh_fill_script": {
                "path": str(fill_script),
                "exists": fill_script.exists(),
            },
            "attachment_script": {
                "path": str(attach_script),
                "exists": attach_script.exists(),
            },
            "fill_command_template_configured": bool(EH_FILL_COMMAND_TEMPLATE),
            "attachment_scan_command_template_configured": bool(EH_ATTACH_SCAN_COMMAND_TEMPLATE),
            "attachment_upload_command_template_configured": bool(EH_ATTACH_UPLOAD_COMMAND_TEMPLATE),
        },
        "python_modules": {
            "requests": check_python_module("requests"),
            "playwright": check_python_module("playwright"),
        },
    }


@app.post("/agent/package/prepare")
def agent_package_prepare(req: AgentBaseRequest) -> Dict[str, Any]:
    run_id, run_dir = new_run_dir("prepare")
    package = load_agent_package(req.workflow_case_id)
    if req.additional_payload:
        package["additional_payload"] = req.additional_payload

    write_json(run_dir / "package.json", package)

    if package.get("ok"):
        validation = validate_agent_payload(package)
    else:
        validation = {"ok": False, "error": package.get("error", "package_load_failed")}

    result = {
        "ok": package.get("ok", False),
        "run_id": run_id,
        "run_dir": str(run_dir),
        "workflow_case_id": req.workflow_case_id,
        "source_mode": package.get("source_mode"),
        "legacy_mode": LEGACY_MODE,
        "validation": validation,
        "package": package,
    }
    write_json(run_dir / "result.json", result)
    return result


@app.post("/agent/eh/fill-dry-run")
def agent_eh_fill_dry_run(req: AgentBaseRequest) -> Dict[str, Any]:
    run_id, run_dir = new_run_dir("fill_dry")
    package = load_agent_package(req.workflow_case_id)
    write_json(run_dir / "package.json", package)

    if not package.get("ok"):
        result = {
            "ok": False,
            "run_id": run_id,
            "run_dir": str(run_dir),
            "workflow_case_id": req.workflow_case_id,
            "error": "package_prepare_failed",
            "package": package,
        }
        write_json(run_dir / "result.json", result)
        return result

    try:
        assert_p02_operational(package)
    except HTTPException as e:
        result = {
            "ok": False,
            "run_id": run_id,
            "run_dir": str(run_dir),
            "workflow_case_id": req.workflow_case_id,
            "error": "legacy_or_non_p02_blocked",
            "detail": e.detail,
        }
        write_json(run_dir / "result.json", result)
        return result

    validation = validate_agent_payload(package)
    result = {
        "ok": validation.get("ok", False),
        "run_id": run_id,
        "run_dir": str(run_dir),
        "workflow_case_id": req.workflow_case_id,
        "source_mode": package.get("source_mode"),
        "dry_run": True,
        "would_open_browser": False,
        "would_submit": False,
        "validation": validation,
    }
    write_json(run_dir / "result.json", result)
    return result


@app.post("/agent/pdf/generate")
def agent_pdf_generate(req: PdfGenerateRequest) -> Dict[str, Any]:
    run_id, run_dir = new_run_dir("pdf")
    package = load_agent_package(req.workflow_case_id)
    write_json(run_dir / "package.json", package)

    if not package.get("ok"):
        result = {"ok": False, "run_id": run_id, "run_dir": str(run_dir), "error": "package_prepare_failed", "package": package}
        write_json(run_dir / "result.json", result)
        return result

    assert_p02_operational(package)

    payload: Dict[str, Any] = {
        "workflow_case_id": req.workflow_case_id,
        "force_refresh": req.force_refresh,
    }
    if req.app_type:
        payload["app_type"] = req.app_type
    if req.additional_payload:
        payload.update(req.additional_payload)

    write_json(run_dir / "pdf_request.json", payload)
    try:
        resp = requests.post(f"{PDF_GENERATOR_URL}/generate-oif-package-pdfs", json=payload, timeout=300)
    except Exception as e:
        result = {
            "ok": False,
            "run_id": run_id,
            "run_dir": str(run_dir),
            "error": "pdf_generator_unreachable",
            "detail": str(e),
            "pdf_generator_url": PDF_GENERATOR_URL,
        }
        write_json(run_dir / "result.json", result)
        return result

    body: Any
    try:
        body = resp.json()
    except Exception:
        body = safe_text(resp)

    result = {
        "ok": resp.ok,
        "run_id": run_id,
        "run_dir": str(run_dir),
        "status_code": resp.status_code,
        "pdf_generator_url": PDF_GENERATOR_URL,
        "response": body,
    }
    write_json(run_dir / "pdf_response.json", result)
    write_json(run_dir / "result.json", result)
    return result


@app.post("/agent/eh/fill")
def agent_eh_fill(req: EhFillRequest) -> Dict[str, Any]:
    run_id, run_dir = new_run_dir("fill")
    package = load_agent_package(req.workflow_case_id)
    write_json(run_dir / "package.json", package)

    if not package.get("ok"):
        result = {"ok": False, "run_id": run_id, "run_dir": str(run_dir), "error": "package_prepare_failed", "package": package}
        write_json(run_dir / "result.json", result)
        return result

    assert_p02_operational(package)
    validation = validate_agent_payload(package)
    if not validation.get("ok"):
        result = {
            "ok": False,
            "run_id": run_id,
            "run_dir": str(run_dir),
            "error": "validation_failed_before_browser",
            "validation": validation,
        }
        write_json(run_dir / "result.json", result)
        return result

    if req.allow_submit:
        result = {
            "ok": False,
            "run_id": run_id,
            "run_dir": str(run_dir),
            "error": "submit_blocked_by_gateway",
            "message": "Beadás/submit nincs engedélyezve ebben a v11 gateway-ben. Előbb human review.",
        }
        write_json(run_dir / "result.json", result)
        return result

    if req.live_fill and not EH_AGENT_ALLOW_LIVE_FILL:
        result = {
            "ok": False,
            "run_id": run_id,
            "run_dir": str(run_dir),
            "error": "live_fill_disabled_by_env",
            "message": "Állítsd EH_AGENT_ALLOW_LIVE_FILL=true értékre, ha tényleg böngészőt nyithat az agent.",
        }
        write_json(run_dir / "result.json", result)
        return result

    template_text = req.command_template_override or EH_FILL_COMMAND_TEMPLATE
    if not template_text:
        result = {
            "ok": False,
            "run_id": run_id,
            "run_dir": str(run_dir),
            "error": "fill_command_template_missing",
            "message": "Nincs EH_FILL_COMMAND_TEMPLATE beállítva. A gateway előkészítette és validálta a P02 payloadot, de nem indított régi kitöltő scriptet.",
            "validation": validation,
            "suggested_template_example": "py C:\\EH_AGENT\\eh_enterhungary_assistant_v10_edge_cdp_loginfix.py --json $json_path",
        }
        write_json(run_dir / "result.json", result)
        return result

    json_path = run_dir / "package.json"
    app_type_for_agent = infer_application_type_for_agent(package.get("data") or {})
    command = render_command(template_text, {
        "workflow_case_id": req.workflow_case_id,
        "run_id": run_id,
        "run_dir": str(run_dir),
        "json_path": str(json_path),
        "xlsx_path": req.xlsx_path or "",
        "eh_fill_script_path": EH_FILL_SCRIPT_PATH,
        "application_type": app_type_for_agent,
        "allow_submit": "false",
        "live_fill": "true" if req.live_fill else "false",
    })

    command_result = run_shell_command(command, run_dir)
    result = {
        "ok": command_result.get("ok", False),
        "run_id": run_id,
        "run_dir": str(run_dir),
        "workflow_case_id": req.workflow_case_id,
        "validation": validation,
        "command_result": command_result,
    }
    write_json(run_dir / "result.json", result)
    return result


@app.post("/agent/attachments/scan")
def agent_attachments_scan(req: AttachmentRequest) -> Dict[str, Any]:
    run_id, run_dir = new_run_dir("attachments_scan")
    package = load_agent_package(req.workflow_case_id)
    write_json(run_dir / "package.json", package)

    if not package.get("ok"):
        result = {"ok": False, "run_id": run_id, "run_dir": str(run_dir), "error": "package_prepare_failed", "package": package}
        write_json(run_dir / "result.json", result)
        return result

    assert_p02_operational(package)

    template_text = req.command_template_override or EH_ATTACH_SCAN_COMMAND_TEMPLATE
    if not template_text:
        result = {
            "ok": True,
            "run_id": run_id,
            "run_dir": str(run_dir),
            "workflow_case_id": req.workflow_case_id,
            "dry_run": True,
            "scan_command_configured": False,
            "message": "Nincs EH_ATTACH_SCAN_COMMAND_TEMPLATE. Egyelőre csak P02 package előkészítés történt.",
            "documents_count": len((package.get("data") or {}).get("documents") or []),
        }
        write_json(run_dir / "result.json", result)
        return result

    command = render_command(template_text, {
        "workflow_case_id": req.workflow_case_id,
        "run_id": run_id,
        "run_dir": str(run_dir),
        "json_path": str(run_dir / "package.json"),
        "package_dir": req.package_dir or "",
        "eh_attach_script_path": EH_ATTACH_SCRIPT_PATH,
        "dry_run": "true" if req.dry_run else "false",
    })

    command_result = run_shell_command(command, run_dir)
    result = {
        "ok": command_result.get("ok", False),
        "run_id": run_id,
        "run_dir": str(run_dir),
        "workflow_case_id": req.workflow_case_id,
        "dry_run": req.dry_run,
        "command_result": command_result,
    }
    write_json(run_dir / "result.json", result)
    return result


@app.post("/agent/attachments/upload")
def agent_attachments_upload(req: AttachmentRequest) -> Dict[str, Any]:
    if req.dry_run:
        return agent_attachments_scan(req)

    if not EH_AGENT_ALLOW_LIVE_FILL:
        raise HTTPException(status_code=403, detail="Éles mellékletfeltöltés tiltva: EH_AGENT_ALLOW_LIVE_FILL=false")

    req.command_template_override = req.command_template_override or EH_ATTACH_UPLOAD_COMMAND_TEMPLATE
    if not req.command_template_override:
        raise HTTPException(status_code=400, detail="Nincs EH_ATTACH_UPLOAD_COMMAND_TEMPLATE beállítva.")

    return agent_attachments_scan(req)


@app.post("/agent/run-full-dry")
def agent_run_full_dry(req: RunFullDryRequest) -> Dict[str, Any]:
    run_id, run_dir = new_run_dir("full_dry")
    package = load_agent_package(req.workflow_case_id)
    write_json(run_dir / "package.json", package)

    if not package.get("ok"):
        result = {"ok": False, "run_id": run_id, "run_dir": str(run_dir), "error": "package_prepare_failed", "package": package}
        write_json(run_dir / "result.json", result)
        return result

    try:
        assert_p02_operational(package)
    except HTTPException as e:
        result = {"ok": False, "run_id": run_id, "run_dir": str(run_dir), "error": "legacy_or_non_p02_blocked", "detail": e.detail}
        write_json(run_dir / "result.json", result)
        return result

    validation = validate_agent_payload(package)
    steps: List[Dict[str, Any]] = [
        {"step": "prepare", "ok": True},
        {"step": "validate", "ok": validation.get("ok", False), "validation": validation},
    ]

    pdf_result = None
    if req.generate_pdf and validation.get("ok"):
        try:
            resp = requests.post(
                f"{PDF_GENERATOR_URL}/generate-oif-package-pdfs",
                json={"workflow_case_id": req.workflow_case_id, "force_refresh": req.force_refresh},
                timeout=300,
            )
            try:
                body = resp.json()
            except Exception:
                body = safe_text(resp)
            pdf_result = {"ok": resp.ok, "status_code": resp.status_code, "response": body}
        except Exception as e:
            pdf_result = {"ok": False, "error": str(e)}
        steps.append({"step": "pdf_generate", **pdf_result})

    attachment_result = None
    if req.scan_attachments and validation.get("ok"):
        docs = (package.get("data") or {}).get("documents") or []
        attachment_result = {"ok": True, "dry_run": True, "documents_count": len(docs), "command_configured": bool(EH_ATTACH_SCAN_COMMAND_TEMPLATE)}
        steps.append({"step": "attachments_scan", **attachment_result})

    ok = all(step.get("ok") for step in steps)
    result = {
        "ok": ok,
        "run_id": run_id,
        "run_dir": str(run_dir),
        "workflow_case_id": req.workflow_case_id,
        "dry_run": True,
        "would_submit": False,
        "source_mode": package.get("source_mode"),
        "validation": validation,
        "steps": steps,
    }
    write_json(run_dir / "result.json", result)
    return result


# Backward compatibility helper for old Retool agent button names.
@app.post("/run-eh-package")
def run_eh_package_compat(req: LegacyRunRequest) -> Dict[str, Any]:
    workflow_case_id = req.workflow_case_id or ((req.payload or {}).get("workflow_case_id") if isinstance(req.payload, dict) else None)
    if not workflow_case_id:
        raise HTTPException(status_code=400, detail="workflow_case_id szükséges. Legacy XLSM-only futtatást a v11 gateway nem indít.")

    # Safe default: compatibility endpoint only performs full dry-run.
    return agent_run_full_dry(RunFullDryRequest(workflow_case_id=workflow_case_id, generate_pdf=False, scan_attachments=False))


# Optional unified proxy: if later Cloudflare points to 8788, existing PDF endpoint still works.
@app.post("/generate-oif-package-pdfs")
async def proxy_generate_oif_package_pdfs(request: Request) -> Dict[str, Any]:
    payload = await request.json()
    try:
        resp = requests.post(f"{PDF_GENERATOR_URL}/generate-oif-package-pdfs", json=payload, timeout=300)
    except Exception as e:
        raise HTTPException(status_code=502, detail={"message": "PDF generator nem elérhető", "error": str(e), "url": PDF_GENERATOR_URL})

    try:
        body = resp.json()
    except Exception:
        body = safe_text(resp)

    if not resp.ok:
        raise HTTPException(status_code=resp.status_code, detail=body)
    return body


@app.options("/{path:path}")
def options_any(path: str) -> Dict[str, Any]:
    return {"ok": True}
