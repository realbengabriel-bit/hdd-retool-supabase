from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import UUID, uuid4

import httpx
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from supabase import create_client

load_dotenv()

SERVICE_NAME = "eh_agent_gateway_v11_p02"
SERVICE_VERSION = "11.0.0-p02-first-rebuild"
SERVICE_MODE = "p02_first_pre_execution"
EXECUTION_ALLOWED_NOW = False


def env_bool(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None or raw == "":
        return default
    return raw.strip().lower() in {"1", "true", "yes", "y", "on"}


class Settings:
    supabase_url: str = os.getenv("SUPABASE_URL", "").strip()
    supabase_service_role_key: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    package_rpc: str = os.getenv("EH_AGENT_PACKAGE_RPC", "get_oif_eh_agent_package").strip() or "get_oif_eh_agent_package"
    package_view: str = os.getenv("EH_AGENT_PACKAGE_VIEW", "v_oif_eh_agent_package_source").strip() or "v_oif_eh_agent_package_source"
    pdf_generator_url: str = os.getenv("OIF_EH_PDF_GENERATOR_URL", "http://127.0.0.1:8787").strip()
    legacy_mode: str = os.getenv("EH_AGENT_LEGACY_MODE", "search_only").strip() or "search_only"
    env_allow_live_fill: bool = env_bool("EH_AGENT_ALLOW_LIVE_FILL", False)
    env_allow_submit: bool = env_bool("EH_AGENT_ALLOW_SUBMIT", False)
    run_dir: str = os.getenv("EH_AGENT_RUN_DIR", r"C:\EH_AGENT\agent_runs").strip() or r"C:\EH_AGENT\agent_runs"
    token: str = os.getenv("EH_AGENT_TOKEN", "").strip()
    allow_pdf_generator_bridge: bool = env_bool("ALLOW_PDF_GENERATOR_BRIDGE", False)


settings = Settings()
app = FastAPI(title=SERVICE_NAME, version=SERVICE_VERSION)


@app.exception_handler(HTTPException)
async def safety_http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "ok": False,
            "status": "error",
            "detail": exc.detail,
            "timestamp": utc_now_iso(),
            **safety_flags(),
        },
        headers=getattr(exc, "headers", None),
    )


@app.exception_handler(RequestValidationError)
async def safety_validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "ok": False,
            "status": "validation_error",
            "detail": exc.errors(),
            "timestamp": utc_now_iso(),
            **safety_flags(),
        },
    )


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def supabase_configured() -> bool:
    return bool(settings.supabase_url and settings.supabase_service_role_key)


def safety_flags() -> dict[str, Any]:
    return {
        "live_fill_allowed": False,
        "submit_allowed": False,
        "execution_allowed_now": EXECUTION_ALLOWED_NOW,
        "robot_barat_integration": False,
    }


def demo_safety_flags(execution_scope: str) -> dict[str, Any]:
    return {
        **safety_flags(),
        "final_submit_blocked": True,
        "execution_scope": execution_scope,
    }


def as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


def blocked_confirmation_required_response(execution_scope: str) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={
            "ok": False,
            "status": "blocked_confirmation_required",
            "reason": "demo_operator_confirmed=true is required for this demo endpoint.",
            "timestamp": utc_now_iso(),
            **demo_safety_flags(execution_scope),
        },
    )


def blocked_submit_not_allowed_response(reason: str, execution_scope: str) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={
            "ok": False,
            "status": "blocked_submit_not_allowed",
            "reason": reason,
            "timestamp": utc_now_iso(),
            **demo_safety_flags(execution_scope),
        },
    )


def ignored_env_guard_warnings() -> list[str]:
    warnings: list[str] = []
    if settings.env_allow_live_fill:
        warnings.append("EH_AGENT_ALLOW_LIVE_FILL is true in env but ignored by this rebuild; live fill remains disabled.")
    if settings.env_allow_submit:
        warnings.append("EH_AGENT_ALLOW_SUBMIT is true in env but ignored by this rebuild; submit remains disabled.")
    return warnings


async def require_bearer_token(authorization: str | None = Header(default=None)) -> bool:
    if not settings.token:
        return True
    expected = "Bearer " + settings.token
    if authorization != expected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid bearer token.",
        )
    return True


def validate_optional_uuid(field_name: str, value: str | None) -> str | None:
    if value is None or str(value).strip() == "":
        return None
    try:
        return str(UUID(str(value)))
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid UUID for {field_name}.",
        ) from exc


class PreparePackageRequest(BaseModel):
    workflow_case_id: str | None = None
    candidate_id: str | None = None
    assignment_id: str | None = None
    rq_code: str | None = None
    requested_by: str | None = None
    dry_run: bool = True


class FillDryRunRequest(BaseModel):
    package: dict[str, Any] = Field(default_factory=dict)
    requested_by: str | None = None


class PdfGenerateRequest(BaseModel):
    payload: dict[str, Any] = Field(default_factory=dict)
    requested_by: str | None = None
    dry_run: bool = True
    demo_operator_confirmed: bool = False


def normalized_prepare_request(req: PreparePackageRequest) -> dict[str, Any]:
    workflow_case_id = validate_optional_uuid("workflow_case_id", req.workflow_case_id)
    candidate_id = validate_optional_uuid("candidate_id", req.candidate_id)
    assignment_id = validate_optional_uuid("assignment_id", req.assignment_id)
    rq_code = (req.rq_code or "").strip() or None

    if not any([workflow_case_id, candidate_id, assignment_id, rq_code]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one identifier is required: workflow_case_id, candidate_id, assignment_id, or rq_code.",
        )

    return {
        "workflow_case_id": workflow_case_id,
        "candidate_id": candidate_id,
        "assignment_id": assignment_id,
        "rq_code": rq_code,
        "requested_by": (req.requested_by or "").strip() or "eh-agent-gateway-v11-p02",
        "dry_run": True,
    }


def safety_blocked_response(reason: str, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "ok": False,
        "status": "safety_blocked",
        "reason": reason,
        "warnings": ignored_env_guard_warnings(),
        "timestamp": utc_now_iso(),
        **demo_safety_flags("pre_execution_only"),
    }
    if extra:
        payload.update(extra)
    return payload


def write_audit_log(kind: str, payload: dict[str, Any]) -> str | None:
    try:
        run_dir = Path(settings.run_dir)
        run_dir.mkdir(parents=True, exist_ok=True)
        file_path = run_dir / f"{utc_now_iso().replace(':', '-').replace('.', '-')}_{kind}_{uuid4().hex}.json"
        file_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        return str(file_path)
    except Exception:
        return None


async def fetch_package_source(normalized: dict[str, Any]) -> dict[str, Any]:
    if not supabase_configured():
        return {
            "ok": False,
            "status": "not_configured",
            "source_mode": "supabase_rpc_not_configured",
            "package_preview": None,
            "warnings": ["SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not configured."],
            "rpc": settings.package_rpc,
            "view": settings.package_view,
            **safety_flags(),
        }

    rpc_args = {
        "p_workflow_case_id": normalized["workflow_case_id"],
        "p_candidate_id": normalized["candidate_id"],
        "p_assignment_id": normalized["assignment_id"],
        "p_rq_code": normalized["rq_code"],
        "p_requested_by": normalized["requested_by"],
        "p_dry_run": True,
    }

    try:
        client = create_client(settings.supabase_url, settings.supabase_service_role_key)
        response = client.rpc(settings.package_rpc, rpc_args).execute()
        data = getattr(response, "data", None)
        return {
            "ok": True,
            "status": "ready" if data else "empty",
            "source_mode": "supabase_rpc",
            "rpc": settings.package_rpc,
            "view": settings.package_view,
            "package_preview": data,
            "warnings": ignored_env_guard_warnings(),
            **safety_flags(),
        }
    except Exception as exc:
        return {
            "ok": False,
            "status": "source_error",
            "source_mode": "supabase_rpc_error",
            "rpc": settings.package_rpc,
            "view": settings.package_view,
            "package_preview": None,
            "warnings": ignored_env_guard_warnings(),
            "error": str(exc),
            **safety_flags(),
        }


def prepare_request_from_payload(payload: dict[str, Any]) -> PreparePackageRequest | None:
    workflow_case_id = payload.get("workflow_case_id") or payload.get("workflowCaseId")
    candidate_id = payload.get("candidate_id") or payload.get("candidateId")
    assignment_id = payload.get("assignment_id") or payload.get("assignmentId")
    rq_code = payload.get("rq_code") or payload.get("rqCode") or payload.get("request_code") or payload.get("workflow_code")
    requested_by = payload.get("requested_by") or payload.get("requestedBy")

    nested_payload = payload.get("payload")
    if isinstance(nested_payload, dict):
        workflow_case_id = workflow_case_id or nested_payload.get("workflow_case_id") or nested_payload.get("workflowCaseId")
        candidate_id = candidate_id or nested_payload.get("candidate_id") or nested_payload.get("candidateId")
        assignment_id = assignment_id or nested_payload.get("assignment_id") or nested_payload.get("assignmentId")
        rq_code = rq_code or nested_payload.get("rq_code") or nested_payload.get("rqCode") or nested_payload.get("request_code") or nested_payload.get("workflow_code")

    if not any([workflow_case_id, candidate_id, assignment_id, rq_code]):
        return None

    return PreparePackageRequest(
        workflow_case_id=str(workflow_case_id) if workflow_case_id else None,
        candidate_id=str(candidate_id) if candidate_id else None,
        assignment_id=str(assignment_id) if assignment_id else None,
        rq_code=str(rq_code) if rq_code else None,
        requested_by=str(requested_by) if requested_by else None,
        dry_run=True,
    )


def extract_package_payload(payload: dict[str, Any], package_prepare_result: dict[str, Any] | None = None) -> dict[str, Any]:
    if isinstance(payload.get("package"), dict) and payload["package"]:
        return payload["package"]
    if isinstance(payload.get("payload"), dict) and payload["payload"]:
        return payload["payload"]
    if package_prepare_result and isinstance(package_prepare_result.get("package_preview"), dict):
        return package_prepare_result["package_preview"]
    if package_prepare_result and package_prepare_result.get("package_preview") is not None:
        return {"package_preview": package_prepare_result.get("package_preview")}
    return payload


async def maybe_prepare_package_from_demo_payload(payload: dict[str, Any]) -> tuple[dict[str, Any] | None, list[str]]:
    warnings = ignored_env_guard_warnings()
    prepare_req = prepare_request_from_payload(payload)
    if prepare_req is None:
        warnings.append("No workflow/candidate/assignment/rq identifier was supplied; PDF bridge will use the provided payload only.")
        return None, warnings

    normalized = normalized_prepare_request(prepare_req)
    package_prepare_result = await fetch_package_source(normalized)
    return {"request": normalized, **package_prepare_result}, warnings


async def handle_demo_pdf_generation(payload: dict[str, Any]) -> Any:
    execution_scope = "demo_pdf_generation_only"
    if not as_bool(payload.get("demo_operator_confirmed")):
        return blocked_confirmation_required_response(execution_scope)

    package_prepare_result, warnings = await maybe_prepare_package_from_demo_payload(payload)

    if not settings.allow_pdf_generator_bridge:
        response = {
            "ok": False,
            "status": "blocked_bridge_disabled",
            "reason": "ALLOW_PDF_GENERATOR_BRIDGE is false.",
            "requested_by": (str(payload.get("requested_by") or payload.get("requestedBy") or "").strip() or "eh-agent-gateway-v11-p02"),
            "package_prepare_result": package_prepare_result,
            "warnings": warnings,
            "timestamp": utc_now_iso(),
            **demo_safety_flags(execution_scope),
        }
        response["audit_log_path"] = write_audit_log("demo_pdf_generate_blocked", response)
        return response

    if not settings.pdf_generator_url:
        response = {
            "ok": False,
            "status": "not_configured",
            "reason": "OIF_EH_PDF_GENERATOR_URL is not configured.",
            "package_prepare_result": package_prepare_result,
            "warnings": warnings,
            "timestamp": utc_now_iso(),
            **demo_safety_flags(execution_scope),
        }
        response["audit_log_path"] = write_audit_log("demo_pdf_generate_not_configured", response)
        return response

    forward_payload = {
        **payload,
        "payload": extract_package_payload(payload, package_prepare_result),
        "package_prepare_result": package_prepare_result,
        "requested_by": (str(payload.get("requested_by") or payload.get("requestedBy") or "").strip() or "eh-agent-gateway-v11-p02"),
        "dry_run": True,
        "demo_operator_confirmed": True,
        "allow_submit": False,
        "live_fill": False,
        "execution_allowed_now": False,
        "final_submit_blocked": True,
        "live_fill_allowed": False,
        "submit_allowed": False,
        "execution_scope": execution_scope,
        "robot_barat_integration": False,
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            legacy_response = await client.post(settings.pdf_generator_url, json=forward_payload)
        response = {
            "ok": legacy_response.status_code < 400,
            "status": "legacy_pdf_generator_bridge_response",
            "legacy_status_code": legacy_response.status_code,
            "legacy_response_text": legacy_response.text[:5000],
            "package_prepare_result": package_prepare_result,
            "warnings": warnings,
            "timestamp": utc_now_iso(),
            **demo_safety_flags(execution_scope),
        }
        try:
            response["legacy_response_json"] = legacy_response.json()
        except Exception:
            response["legacy_response_json"] = None
        response["audit_log_path"] = write_audit_log("demo_pdf_generate_bridge", response)
        return response
    except Exception as exc:
        response = {
            "ok": False,
            "status": "legacy_pdf_generator_bridge_error",
            "error": str(exc),
            "package_prepare_result": package_prepare_result,
            "warnings": warnings,
            "timestamp": utc_now_iso(),
            **demo_safety_flags(execution_scope),
        }
        response["audit_log_path"] = write_audit_log("demo_pdf_generate_bridge_error", response)
        return response


async def handle_demo_eh_fill(payload: dict[str, Any]) -> Any:
    execution_scope = "demo_eh_draft_fill_only"
    if not as_bool(payload.get("demo_operator_confirmed")):
        return blocked_confirmation_required_response(execution_scope)
    if as_bool(payload.get("allow_submit")):
        return blocked_submit_not_allowed_response("allow_submit=false is required. Final submit is blocked.", execution_scope)

    package_prepare_result, warnings = await maybe_prepare_package_from_demo_payload(payload)
    package_payload = extract_package_payload(payload, package_prepare_result)
    dry_run_result = build_fill_dry_run(package_payload)

    response = {
        "ok": False,
        "status": "not_implemented_on_this_host_package",
        "demo_draft_action_allowed": True,
        "manual_next_step": "Use the prepared payload and generated PDFs for a manually supervised EH draft demo on the office host; do not submit.",
        "missing_capability": "safe_browser_draft_fill_adapter_not_present_in_v11_p02_package",
        "request_must_be_deleted_after_demo": True,
        "received_live_fill_request": as_bool(payload.get("live_fill")),
        "package_prepare_result": package_prepare_result,
        "dry_run_result": dry_run_result,
        "warnings": warnings,
        "timestamp": utc_now_iso(),
        **demo_safety_flags(execution_scope),
    }
    response["audit_log_path"] = write_audit_log("demo_eh_fill_not_implemented", response)
    return response


def collect_field_paths(value: Any, prefix: str = "package", limit: int = 200) -> list[str]:
    paths: list[str] = []

    def walk(current: Any, current_path: str) -> None:
        if len(paths) >= limit:
            return
        if isinstance(current, dict):
            if not current:
                paths.append(current_path + " (empty object)")
                return
            for key, nested in current.items():
                walk(nested, current_path + "." + str(key))
            return
        if isinstance(current, list):
            if not current:
                paths.append(current_path + " (empty list)")
                return
            for index, nested in enumerate(current[:20]):
                walk(nested, current_path + "[" + str(index) + "]")
            if len(current) > 20:
                paths.append(current_path + " (truncated after 20 items)")
            return
        paths.append(current_path)

    walk(value, prefix)
    return paths


def build_fill_dry_run(package: dict[str, Any]) -> dict[str, Any]:
    warnings = ignored_env_guard_warnings()
    if not isinstance(package, dict) or not package:
        warnings.append("Package payload is empty or not an object.")

    field_paths = collect_field_paths(package)
    checklist = [
        {"step": "validate_package_shape", "status": "passed" if isinstance(package, dict) and bool(package) else "warning"},
        {"step": "browser_fill", "status": "blocked", "reason": "Live browser fill is disabled in v11 P02-first rebuild."},
        {"step": "eh_oif_submit", "status": "blocked", "reason": "EH/OIF submit is disabled in v11 P02-first rebuild."},
        {"step": "notifications", "status": "blocked", "reason": "Notifications are disabled."},
    ]

    return {
        "ok": True,
        "status": "dry_run_ready" if package else "dry_run_warning",
        "dry_run": True,
        "checklist": checklist,
        "would_fill_fields": field_paths,
        "warnings": warnings,
        "timestamp": utc_now_iso(),
        **safety_flags(),
    }


@app.get("/health")
async def health() -> dict[str, Any]:
    return {
        "ok": True,
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "mode": SERVICE_MODE,
        "legacy_mode": settings.legacy_mode,
        "live_fill_allowed": False,
        "submit_allowed": False,
        "execution_allowed_now": EXECUTION_ALLOWED_NOW,
        "pdf_generator_url": settings.pdf_generator_url,
        "supabase_configured": supabase_configured(),
        "run_dir": settings.run_dir,
        "timestamp": utc_now_iso(),
    }


@app.get("/version")
async def version() -> dict[str, Any]:
    return {
        "service": SERVICE_NAME,
        "version": SERVICE_VERSION,
        "mode": SERVICE_MODE,
        "legacy_mode": settings.legacy_mode,
        "timestamp": utc_now_iso(),
        **safety_flags(),
    }


@app.get("/capabilities", dependencies=[Depends(require_bearer_token)])
async def capabilities() -> dict[str, Any]:
    return {
        "p02_first_package_prepare": True,
        "supabase_package_read": supabase_configured(),
        "legacy_pdf_generator_bridge": bool(settings.pdf_generator_url and settings.allow_pdf_generator_bridge),
        "fill_dry_run": True,
        "full_dry_run": True,
        "live_fill": False,
        "submit": False,
        "notifications": False,
        "robot_barat_integration": False,
        "warnings": ignored_env_guard_warnings(),
        "timestamp": utc_now_iso(),
        "execution_allowed_now": EXECUTION_ALLOWED_NOW,
    }


@app.post("/agent/package/prepare", dependencies=[Depends(require_bearer_token)])
async def prepare_package(req: PreparePackageRequest) -> dict[str, Any]:
    if req.dry_run is not True:
        return safety_blocked_response("dry_run=false is not allowed. Package prepare is dry-run/preview only.")

    normalized = normalized_prepare_request(req)
    result = await fetch_package_source(normalized)
    response = {
        "request": normalized,
        "timestamp": utc_now_iso(),
        **result,
    }
    response["audit_log_path"] = write_audit_log("package_prepare", response)
    return response


@app.post("/agent/eh/fill-dry-run", dependencies=[Depends(require_bearer_token)])
async def fill_dry_run(req: FillDryRunRequest) -> dict[str, Any]:
    result = build_fill_dry_run(req.package)
    response = {
        "requested_by": (req.requested_by or "").strip() or "eh-agent-gateway-v11-p02",
        **result,
    }
    response["audit_log_path"] = write_audit_log("fill_dry_run", response)
    return response


@app.post("/agent/run-full-dry", dependencies=[Depends(require_bearer_token)])
async def run_full_dry(req: PreparePackageRequest) -> dict[str, Any]:
    if req.dry_run is not True:
        return safety_blocked_response("dry_run=false is not allowed. Full dry run cannot become live execution.")

    normalized = normalized_prepare_request(req)
    package_result = await fetch_package_source(normalized)
    package_for_validation: dict[str, Any]
    if isinstance(package_result.get("package_preview"), dict):
        package_for_validation = package_result["package_preview"]
    else:
        package_for_validation = {"package_preview": package_result.get("package_preview")}

    dry_run_result = build_fill_dry_run(package_for_validation)
    response = {
        "ok": package_result.get("ok") is True,
        "status": "full_dry_run_complete" if package_result.get("ok") is True else "full_dry_run_with_source_warning",
        "request": normalized,
        "package_prepare_result": package_result,
        "dry_run_result": dry_run_result,
        "timestamp": utc_now_iso(),
        **safety_flags(),
    }
    response["audit_log_path"] = write_audit_log("run_full_dry", response)
    return response


@app.post("/generate-oif-package-pdfs", dependencies=[Depends(require_bearer_token)], response_model=None)
async def generate_oif_package_pdfs(payload: dict[str, Any]) -> Any:
    return await handle_demo_pdf_generation(payload)


@app.post("/api/generate-oif-package-pdfs", dependencies=[Depends(require_bearer_token)], response_model=None)
async def api_generate_oif_package_pdfs(payload: dict[str, Any]) -> Any:
    return await handle_demo_pdf_generation(payload)


@app.post("/oif-eh/generate-oif-package-pdfs", dependencies=[Depends(require_bearer_token)], response_model=None)
async def oif_eh_generate_oif_package_pdfs(payload: dict[str, Any]) -> Any:
    return await handle_demo_pdf_generation(payload)


@app.post("/agent/eh/fill", dependencies=[Depends(require_bearer_token)], response_model=None)
async def agent_eh_fill(payload: dict[str, Any]) -> Any:
    return await handle_demo_eh_fill(payload)


@app.post("/agent/pdf/generate", dependencies=[Depends(require_bearer_token)], response_model=None)
async def pdf_generate(req: PdfGenerateRequest) -> Any:
    payload = {
        "payload": req.payload,
        "requested_by": req.requested_by,
        "dry_run": req.dry_run,
        "demo_operator_confirmed": req.demo_operator_confirmed,
    }
    return await handle_demo_pdf_generation(payload)


@app.post("/run-eh-package", dependencies=[Depends(require_bearer_token)], response_model=None)
async def run_eh_package(payload: dict[str, Any]) -> Any:
    if str(payload.get("agent_mode") or payload.get("mode") or "").strip().lower() == "generate_pdfs":
        return await handle_demo_pdf_generation(payload)

    requested_live = any(
        payload.get(key) is True
        for key in ["execute", "run", "live", "live_fill", "submit", "allow_submit"]
    ) or payload.get("dry_run") is False

    package_payload = payload.get("package") if isinstance(payload.get("package"), dict) else payload
    dry_run_result = build_fill_dry_run(package_payload)

    response = {
        "ok": not requested_live,
        "status": "safety_blocked" if requested_live else "compatibility_dry_run_complete",
        "compatibility_mode": True,
        "reason": "Legacy live execution flags are blocked and routed to dry-run only." if requested_live else None,
        "dry_run_result": dry_run_result,
        "request_must_be_deleted_after_demo": True,
        "timestamp": utc_now_iso(),
        **demo_safety_flags("legacy_run_compatibility_dry_run_only"),
    }
    response["audit_log_path"] = write_audit_log("run_eh_package_compat", response)
    return response
