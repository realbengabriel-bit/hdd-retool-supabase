# -*- coding: utf-8 -*-
r"""
OIF/EH PDF generator gateway v2

Ezt érdemes Cloudflare tunnel mögött futtatni, ha a Retool 4. PDF-generálás gombja
`not_found` hibát ad. A gateway több kompatibilis endpointot is kitesz:

  GET  /health
  POST /generate-oif-package-pdfs
  POST /api/generate-oif-package-pdfs
  POST /oif-eh/generate-oif-package-pdfs
  POST /run-eh-package   agent_mode=generate_pdfs esetén PDF-generátorként működik

A /run-eh-package nem generate_pdfs módjaihoz opcionális upstream proxy állítható:
  EH_AGENT_UPSTREAM_URL=https://eh-agent-old.hddirekt.com

Indítás:
  py -m pip install -r requirements.txt
  py -m uvicorn eh_oif_pdf_generator_gateway_v2:app --host 127.0.0.1 --port 8787
"""
from __future__ import annotations

import os
import traceback
from pathlib import Path
from typing import Any, Dict

import requests
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from eh_oif_pdf_generator_frontlayer_v1 import generate_package_pdfs

app = FastAPI(title="OIF/EH PDF generator gateway", version="3.9.0-official-template-checkbox-calibrated")

# Retool böngészőből hívja a local/Cloudflare agentet fetch-csel.
# A custom headerek és a POST miatt a böngésző először OPTIONS preflightot küld.
# CORS nélkül Retool csak ennyit jelez: "Failed to fetch".
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.options("/{full_path:path}")
async def options_preflight(full_path: str) -> JSONResponse:
    return JSONResponse({"ok": True, "status": "cors_preflight_ok", "path": full_path})


def _normalize_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    payload = dict(payload or {})
    if payload.get("python_export_rows") and not payload.get("python_export_row"):
        try:
            payload["python_export_row"] = payload["python_export_rows"][0]
        except Exception:
            pass
    # Retool régi/új mezőnevek összefésülése
    if not payload.get("person_folder") and payload.get("local_person_folder"):
        payload["person_folder"] = payload.get("local_person_folder")
    return payload


def _generate(payload: Dict[str, Any]) -> Dict[str, Any]:
    payload = _normalize_payload(payload)
    workbook_path = Path(payload["workbook_path"]) if payload.get("workbook_path") else None
    return generate_package_pdfs(payload, workbook_path=workbook_path)


@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "ok": True,
        "service": "oif_eh_pdf_generator_gateway_v2",
        "template_mode": "v3.9-official-template-checkbox-calibrated",
        "pdf_generator_endpoint": "/generate-oif-package-pdfs",
        "aliases": [
            "/api/generate-oif-package-pdfs",
            "/oif-eh/generate-oif-package-pdfs",
            "/run-eh-package with agent_mode=generate_pdfs",
        ],
        "supported_application_types": ["vendeg", "vendeg_9_7", "nemzeti", "foglalkoztatasi_9_6"],
        "feor_binding": "Retool effective_feor_code / feor_change_log override supported; 9.6/9.7 checkbox positions calibrated per official template boxes",
        "unsupported_yet": [],
        "supabase_configured": bool(os.environ.get("SUPABASE_URL") and os.environ.get("SUPABASE_SERVICE_ROLE_KEY")),
        "upstream_eh_agent_configured": bool(os.environ.get("EH_AGENT_UPSTREAM_URL")),
    }


@app.post("/generate-oif-package-pdfs")
async def generate_main(request: Request) -> JSONResponse:
    payload = await request.json()
    try:
        return JSONResponse(_generate(payload))
    except Exception as exc:
        return JSONResponse({
            "ok": False,
            "status": "error",
            "error": f"{type(exc).__name__}: {exc}",
            "traceback": traceback.format_exc(),
        }, status_code=500)


@app.post("/api/generate-oif-package-pdfs")
async def generate_api_alias(request: Request) -> JSONResponse:
    return await generate_main(request)


@app.post("/oif-eh/generate-oif-package-pdfs")
async def generate_oifeh_alias(request: Request) -> JSONResponse:
    return await generate_main(request)


@app.post("/run-eh-package")
async def run_eh_package_compat(request: Request) -> JSONResponse:
    payload = await request.json()
    mode = str(payload.get("agent_mode") or payload.get("mode") or "").strip().lower()

    # Retool fallback: ha a régi /run-eh-package útra esik vissza, generate_pdfs módban itt is kiszolgáljuk.
    if mode in {"generate_pdfs", "pdf_generation", "generate-oif-package-pdfs"} or payload.get("requested_action") == "generate-oif-package-pdfs":
        try:
            result = _generate(payload)
            result["compat_endpoint"] = "/run-eh-package"
            return JSONResponse(result)
        except Exception as exc:
            return JSONResponse({
                "ok": False,
                "status": "error",
                "error": f"{type(exc).__name__}: {exc}",
                "traceback": traceback.format_exc(),
            }, status_code=500)

    # Opcionális: a régi EH kitöltő/feltöltő agent felé továbbküldés.
    upstream = (os.environ.get("EH_AGENT_UPSTREAM_URL") or "").rstrip("/")
    if upstream:
        try:
            headers = {"Content-Type": "application/json"}
            auth = request.headers.get("authorization")
            token = request.headers.get("x-eh-agent-token")
            if auth:
                headers["Authorization"] = auth
            if token:
                headers["X-EH-Agent-Token"] = token
            r = requests.post(f"{upstream}/run-eh-package", json=payload, headers=headers, timeout=600)
            try:
                data = r.json()
            except Exception:
                data = {"raw_text": r.text}
            return JSONResponse(data, status_code=r.status_code)
        except Exception as exc:
            return JSONResponse({
                "ok": False,
                "status": "error",
                "error": f"upstream_proxy_error: {type(exc).__name__}: {exc}",
                "upstream": upstream,
            }, status_code=502)

    return JSONResponse({
        "ok": False,
        "status": "error",
        "error": "run_eh_package_not_configured_in_pdf_gateway",
        "error_text": "Ez a gateway a PDF-generátort szolgálja ki. A régi EH kitöltő/feltöltő /run-eh-package módjaihoz állítsd be az EH_AGENT_UPSTREAM_URL változót, vagy futtasd külön a régi EH agentet.",
        "received_agent_mode": mode,
    }, status_code=501)
