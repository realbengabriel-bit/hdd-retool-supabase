# -*- coding: utf-8 -*-
"""
EnterHungary XLS-free payload-first kitöltő asszisztens v12.

Cél:
- Nem kell többé ENTERHUNGARY.xlsm adatforrásként.
- Retool / Supabase / P02 package JSON-ból dolgozik.
- A régi, bevált EH Playwright kitöltőmotor logikáját használja,
  de a soradatokat JSON payloadból adja neki.
- Támogatott első kör:
  * nemzeti / nemzeti_9_12  -> /eh/cases/new/tartcelharm-c12
  * vendeg / vendeg_9_7     -> /eh/cases/new/tartcelharm-c7
  * foglalkoztatasi_9_6     -> /eh/cases/new/tartcelharm-c6

Fontos:
- Submit/beadás nincs automatán. A régi motor kézi ellenőrzési pontot tart.
- Hosszabbításnál a konkrét EH hosszabbítás HTML alapján még lehet finomítani.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
import time
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

from playwright.sync_api import sync_playwright, BrowserContext

import eh_enterhungary_assistant_legacy_v10 as legacy

BASE_URL = "https://enterhungary.gov.hu"
SERVICE_VERSION = "12.0.0-xlsfree-payload-first"

CASE_TYPES: Dict[str, Dict[str, Any]] = {
    "nemzeti": {
        "label": "Nemzeti Kártya / 9.12",
        "canonical": "nemzeti",
        "url_suffix": "tartcelharm-c12",
        "new_url": BASE_URL + "/eh/cases/new/tartcelharm-c12",
        "accordion_url": BASE_URL + "/eh/cases/new#tartcelharm",
        "first_sheet": "Kerelem",
        "second_sheet": "Kerelem2",
        "link_texts": ["Nemzeti Kártya", "Nemzeti Kartya"],
        "default_extension": False,
    },
    "nemzeti_9_12": {
        "alias_of": "nemzeti",
    },
    "vendeg": {
        "label": "Vendégmunkás / 9.7",
        "canonical": "vendeg",
        "url_suffix": "tartcelharm-c7",
        "new_url": BASE_URL + "/eh/cases/new/tartcelharm-c7",
        "accordion_url": BASE_URL + "/eh/cases/new#tartcelharm",
        "first_sheet": "VendegmKerelem",
        "second_sheet": "VendegmKerelem2",
        "link_texts": ["Vendégmunkás", "Vendegmunkas", "Vendégmunkás-tartózkodási engedély"],
        "default_extension": False,
    },
    "vendeg_9_7": {
        "label": "Vendégmunkás hosszabbítás / 9.7",
        "canonical": "vendeg_9_7",
        "url_suffix": "tartcelharm-c7",
        "new_url": BASE_URL + "/eh/cases/new/tartcelharm-c7",
        "accordion_url": BASE_URL + "/eh/cases/new#tartcelharm",
        "first_sheet": "VendegmKerelem",
        "second_sheet": "VendegmKerelem2",
        "link_texts": ["Vendégmunkás", "Vendegmunkas", "Vendégmunkás-tartózkodási engedély"],
        "default_extension": True,
    },
    "guest_worker_extension": {
        "alias_of": "vendeg_9_7",
    },
    "foglalkoztatasi_9_6": {
        "label": "Foglalkoztatás hosszabbítás / 9.6",
        "canonical": "foglalkoztatasi_9_6",
        "url_suffix": "tartcelharm-c6",
        "new_url": BASE_URL + "/eh/cases/new/tartcelharm-c6",
        "accordion_url": BASE_URL + "/eh/cases/new#tartcelharm",
        "first_sheet": "Kerelem",
        "second_sheet": "Kerelem2",
        "link_texts": ["Foglalkoztatás", "Foglalkoztatas"],
        "default_extension": True,
    },
    "foglalkoztatasi": {
        "alias_of": "foglalkoztatasi_9_6",
    },
    "employment_extension": {
        "alias_of": "foglalkoztatasi_9_6",
    },
}


def norm(s: Any) -> str:
    if s is None:
        return ""
    s = str(s).strip().replace("–", "-").replace("—", "-").replace("-", " ")
    s = " ".join(s.split())
    s = unicodedata.normalize("NFD", s)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    return s.lower()


def clean(v: Any) -> str:
    if v is None:
        return ""
    if isinstance(v, (dt.datetime, dt.date)):
        return v.strftime("%Y-%m-%d")
    return " ".join(str(v).strip().split())


def first_non_empty(*vals: Any) -> str:
    for v in vals:
        if v is None:
            continue
        if isinstance(v, str) and not v.strip():
            continue
        if isinstance(v, list) and not v:
            continue
        return clean(v)
    return ""


def deep_get(data: Any, dotted: str) -> Any:
    cur = data
    for part in dotted.split("."):
        if isinstance(cur, dict):
            cur = cur.get(part)
        else:
            return None
    return cur


def flatten_dict(data: Any, prefix: str = "", out: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    if out is None:
        out = {}
    if isinstance(data, dict):
        for k, v in data.items():
            key = f"{prefix}.{k}" if prefix else str(k)
            out[key] = v
            flatten_dict(v, key, out)
    elif isinstance(data, list):
        out[prefix] = data
    return out


def canonical_app_type(raw: Any, payload: Dict[str, Any]) -> str:
    candidates = [raw]
    flat = flatten_dict(payload)
    for key in [
        "application_type", "application_type_code", "app_type", "package.application_type",
        "data.package.application_type", "data.workflow.application_type", "data.workflow.request_code",
        "package.app_type", "data.package.app_type"
    ]:
        if key in flat:
            candidates.append(flat.get(key))
    blob = " ".join(clean(x) for x in candidates if x is not None)
    n = norm(blob)
    if "foglalkoztatasi_9_6" in n or "employment extension" in n or "foglalkoztatas" in n and "9 6" in n:
        return "foglalkoztatasi_9_6"
    if "vendeg_9_7" in n or "guest worker extension" in n or "vendegmunkas" in n and "9 7" in n:
        return "vendeg_9_7"
    if "nemzeti_9_12" in n or "nemzeti" in n or "national card" in n:
        return "nemzeti"
    if "vendeg" in n or "guest" in n:
        return "vendeg"
    return "nemzeti"


def resolve_case_type(app_type: str) -> Dict[str, Any]:
    key = app_type or "nemzeti"
    seen = set()
    while True:
        cfg = CASE_TYPES.get(key)
        if not cfg:
            raise RuntimeError(f"Nem támogatott application_type: {app_type!r}")
        if "alias_of" not in cfg:
            return cfg
        if key in seen:
            raise RuntimeError(f"application_type alias kör: {app_type!r}")
        seen.add(key)
        key = cfg["alias_of"]


@dataclass
class MappingRow:
    row_no: int
    xpath: str
    kind: str
    col_name: str


# Régi Excel-oszlop nevek -> P02/PDF payload kulcsok.
HEADER_ALIASES: Dict[str, List[str]] = {
    "Vezetéknév": ["last_name", "family_name", "surname", "core.last_name", "workflow.last_name", "person.last_name"],
    "Keresztnév": ["first_name", "given_name", "core.first_name", "workflow.first_name", "person.first_name"],
    "Születési Vezetéknév": ["birth_last_name", "last_name", "core.birth_last_name", "person.birth_last_name"],
    "Anyja vezetéknév": ["mother_last_name", "mother_family_name", "core.mother_last_name", "person.mother_last_name"],
    "Anyja keresztnév": ["mother_first_name", "mother_given_name", "core.mother_first_name", "person.mother_first_name"],
    "Születési helye (Ország)": ["birth_country", "core.birth_country", "workflow.birth_country", "person.birth_country"],
    "Születési helye (Város)": ["birth_place", "birth_city", "core.birth_place", "workflow.birth_place", "person.birth_place"],
    "Születési idő": ["birth_date", "core.birth_date", "workflow.birth_date", "person.birth_date"],
    "Neme (Nő/Férfi)": ["gender", "sex", "core.gender", "person.gender"],
    "Állampolgárság": ["nationality", "citizenship", "core.nationality", "workflow.nationality", "person.nationality"],
    "Családi állapota (Nőtlen/hajadon; Elvált; Házas; özvegy)": ["marital_status", "core.marital_status", "person.marital_status"],
    "Szakképzettsége": ["qualification", "education_qualification", "position_name", "feor_name", "effective_feor_name", "core.qualification", "workflow.feor_name"],
    "Iskolai végzettség (Alapfokú; Felsőfokú; Középfokú; Nincs)": ["education_level", "core.education_level"],
    "Magyarországra érkezést megelőző foglalkozása": ["previous_occupation", "position_name", "feor_name", "effective_feor_name"],
    "Útlevél száma": ["passport_number", "core.passport_number", "workflow.passport_number", "passport.number"],
    "Útlevél típusa": ["passport_type", "passport.type"],
    "Útlevél kiállításának helye": ["passport_issue_place", "passport.issue_place"],
    "Útlevél kiállításának dátuma": ["passport_issue_date", "passport.issue_date"],
    "Útlevél érvényes dátum": ["passport_expiry_date", "passport.expiry_date", "workflow.passport_expiry_date"],
    "Beutazás hely": ["entry_place", "entry_border", "arrival_place"],
    "Beutazás ideje": ["entry_date", "arrival_date", "planned_arrival_date", "workflow.planned_arrival_date"],
    "Meddig kérelmezi tartózkodása engedélyezését?": ["requested_until", "requested_valid_until", "residence_permit_valid_until", "workflow.residence_permit_valid_until"],
    "Sz.Irányítószám": ["accommodation.zip", "accommodation.postal_code", "szallas_zip", "planned_accommodation_zip"],
    "Sz.Közterület neve": ["accommodation.street", "accommodation.street_name", "szallas_street", "planned_accommodation_street"],
    "Sz.Közterület jellege": ["accommodation.street_type", "szallas_street_type"],
    "Sz.Házszám": ["accommodation.house_number", "szallas_house_number"],
    "Sz.Épület": ["accommodation.building", "szallas_building"],
    "Sz.Emelet (01; 02; 03…）": ["accommodation.floor", "szallas_floor"],
    "Sz.Emelet (01; 02; 03… )": ["accommodation.floor", "szallas_floor"],
    "Sz.Emelet (01; 02; 03…）": ["accommodation.floor", "szallas_floor"],
    "Sz.Emelet (01; 02; 03…)": ["accommodation.floor", "szallas_floor"],
    "Sz.Ajtó": ["accommodation.door", "szallas_door"],
    "Szálláshelyen tartózkodás jogcíme": ["accommodation_legal_title", "accommodation.legal_title"],
    "Éspedig": ["accommodation_legal_title_other", "accommodation.legal_title_other"],
    "Ország": ["return_country", "country", "nationality_country"],
    "Rendelkezik-e egészségbiztosítással?": ["has_health_insurance", "health_insurance", "taj_status"],
    "Rendelkezik-e a szükséges útlevéllel?": ["has_passport"],
    "útlevéllel?": ["has_passport"],
    "Vízummal?": ["has_visa"],
    "Menetjeggyel?": ["has_ticket"],
    "Anyagi fedezettel?": ["has_financial_coverage"],
    "Pénznem": ["currency", "salary_currency", "package.currency"],
    "Várható jövedelem": ["salary", "gross_salary", "net_salary", "expected_income", "monthly_salary", "package.salary"],
    "Benyújtó": ["submitter_type", "package.submitter_type"],
    "Rövid cégnév": ["employer.short_name", "short_name", "employer_name", "company_name", "validated_partner_name", "partner_name", "workflow.validated_partner_name"],
    "Foglalkoztató Adószám": ["employer.tax_number", "tax_number", "employer_tax_number", "company_tax_number"],
    "KSH szám": ["employer.ksh_number", "ksh_number"],
    "TEÁOR": ["employer.teao", "teao", "main_activity_teao"],
    "Foglalkoztató irányítószám": ["employer.zip", "zip", "postal_code", "employer.postal_code", "workplace.zip"],
    "Foglalkoztató közterület neve": ["employer.street", "street", "street_name", "employer.street_name", "workplace.street"],
    "Foglalkoztató közterület jellege": ["employer.street_type", "street_type", "workplace.street_type"],
    "Foglalkoztató közterület jellege2": ["employer.street_type", "street_type", "workplace.street_type"],
    "Foglalkoztató házszám": ["employer.house_number", "house_number", "workplace.house_number"],
    "Foglalkoztató Épület": ["employer.building", "building", "workplace.building"],
    "Foglalkoztató Emelet": ["employer.floor", "floor", "workplace.floor"],
    "Foglalkoztató Ajtó": ["employer.door", "door", "workplace.door"],
    "Munkahely irányítószám": ["workplace.zip", "workplace.postal_code", "employer.zip"],
    "Munkahely település": ["workplace.city", "employer.city", "city", "settlement", "employer.settlement"],
    "Munkahely közterület neve": ["workplace.street", "workplace.street_name", "employer.street"],
    "Munkahely közterület jellege": ["workplace.street_type", "employer.street_type"],
    "Munkahely házszám": ["workplace.house_number", "employer.house_number"],
    "Munkahely Épület": ["workplace.building", "employer.building"],
    "Munkahely Emelet": ["workplace.floor", "employer.floor"],
    "Munkahely Ajtó": ["workplace.door", "employer.door"],
    "Előzetes megállapodás kelte": ["preliminary_agreement_date", "employment_contract_date", "assignment_start_date", "workflow.assignment_start_date"],
    "FEOR": ["effective_feor_code", "feor_code", "feor", "workflow.feor", "package.effective_feor_code"],
    "Minősített kölcsönző": ["qualified_lender_type", "is_qualified_lender"],
    "Nyilvántartásba vétel napja": ["qualified_lender_registration_date", "registration_date"],
    "Nyilvántartási száma": ["qualified_lender_registration_number", "registration_number"],
    "Btátv": ["btatv34", "btatv_34"],
    "Ügyintéző email": ["case_manager_email", "validated_project_lead_email", "project_lead_email"],
    "Ügyintéző telefonszám": ["case_manager_phone", "project_lead_phone", "phone"],
}

# Literals/defaults; ezek akkor is értéket adnak, ha nincs payloadban.
DEFAULT_VALUES: Dict[str, str] = {
    "Igen": "Igen",
    "Nem": "Nem",
    "Rendelkezik-e a szükséges útlevéllel?": "Igen",
    "útlevéllel?": "Igen",
    "Vízummal?": "Igen",
    "Menetjeggyel?": "Nem",
    "Anyagi fedezettel?": "Igen",
    "Rendelkezik-e egészségbiztosítással?": "Foglalkoztatási Jogviszony Alapján",
    "Útlevél típusa": "Magánútlevél",
    "Szálláshelyen tartózkodás jogcíme": "Egyéb",
    "Éspedig": "befogadó nyilatkozat, munkáltató bérli",
    "Pénznem": "Forint",
    "Benyújtó": "foglalkoztató",
    "Minősített kölcsönző": "minősített munkaerő kölcsönző",
    "Btátv": "Igen",
    "Nyilvántartásba vétel napja": "2024-03-11",
    "Nyilvántartási száma": "BP/0702/00010-4/2024",
}


class PayloadData:
    def __init__(self, payload_path: Path, app_type: Optional[str] = None, mapping_path: Optional[Path] = None):
        self.path = payload_path
        self.payload = json.loads(payload_path.read_text(encoding="utf-8"))
        self.app_type = canonical_app_type(app_type, self.payload)
        self.case_cfg = resolve_case_type(self.app_type)
        self.mapping_path = mapping_path or Path(__file__).with_name("eh_xpath_mappings.json")
        self.mappings = json.loads(self.mapping_path.read_text(encoding="utf-8"))
        self.flat = flatten_dict(self.payload)
        self.short = self._build_short_index()

    def _build_short_index(self) -> Dict[str, Any]:
        out: Dict[str, Any] = {}
        for k, v in self.flat.items():
            out[norm(k)] = v
            out[norm(k.split(".")[-1])] = v
        data = self.payload.get("data") if isinstance(self.payload, dict) else None
        if isinstance(data, dict):
            for group_key in ["workflow", "core", "person", "package", "accommodation", "employer", "workplace", "bmh"]:
                grp = data.get(group_key)
                if isinstance(grp, dict):
                    for k, v in grp.items():
                        out[norm(k)] = v
        return out

    def start_row(self) -> int:
        return 2

    def get_cell_by_letter(self, row_no: int, col_letter: str) -> str:
        return ""

    def detect_type(self, row_no: int = 2) -> str:
        return self.app_type

    def row_display_name(self, row_no: int = 2) -> str:
        return first_non_empty(
            self.short.get(norm("full_name")),
            self.short.get(norm("name")),
            " ".join(x for x in [self.get_value(2, "Vezetéknév", self.app_type), self.get_value(2, "Keresztnév", self.app_type)] if x).strip(),
            self.path.stem,
        )

    def mapping_rows(self, sheet_name: str) -> List[legacy.MappingRow]:
        rows = []
        for r in self.mappings.get(sheet_name, []):
            rows.append(legacy.MappingRow(int(r.get("row_no") or 0), r.get("xpath") or "", r.get("kind") or "", r.get("col_name") or ""))
        if not rows:
            raise RuntimeError(f"Nincs beépített mapping ehhez a fülhöz: {sheet_name}")
        return rows

    def _lookup_key(self, key: str) -> str:
        # exact dotted
        val = deep_get(self.payload, key)
        if val not in (None, ""):
            return clean(val)
        if key in self.flat and self.flat[key] not in (None, ""):
            return clean(self.flat[key])
        n = norm(key)
        if n in self.short and self.short[n] not in (None, ""):
            return clean(self.short[n])
        return ""

    def get_value(self, row_no: int, header_or_literal: str, app_type: str) -> str:
        header = clean(header_or_literal)
        if not header:
            return ""
        # explicit additional_payload / field_overrides may override Hungarian labels
        for prefix in ["additional_payload.field_overrides", "field_overrides", "data.field_overrides"]:
            v = deep_get(self.payload, f"{prefix}.{header}")
            if v not in (None, ""):
                return legacy.normalize_for_field(header, v, self.app_type)
        # direct header variants
        for candidate in [header, norm(header)]:
            v = self._lookup_key(candidate)
            if v:
                return legacy.normalize_for_field(header, v, self.app_type)
        for k in HEADER_ALIASES.get(header, []):
            v = self._lookup_key(k)
            if v:
                return legacy.normalize_for_field(header, v, self.app_type)
        if header in DEFAULT_VALUES:
            return legacy.normalize_for_field(header, DEFAULT_VALUES[header], self.app_type)
        if norm(header) in {"igen", "nem"}:
            return header
        return ""


class PayloadEHAssistant(legacy.EHAssistant):
    def __init__(self, page, data: PayloadData, row_no: int, app_type: str, base_dir: Path, allow_submit: bool = False):
        super().__init__(page, data, row_no, app_type, base_dir)
        self.data: PayloadData = data
        self.case_cfg = data.case_cfg
        self.allow_submit_flag = allow_submit

    def try_click_new_case_type_link(self) -> bool:
        candidates = []
        suffix = self.case_cfg["url_suffix"]
        candidates.append(f"a[href*='{suffix}']")
        for text in self.case_cfg.get("link_texts") or []:
            candidates.extend([f"button:has-text('{text}')", f"a:has-text('{text}')", f"input[value*='{text}']"])
        for sel in candidates:
            try:
                loc = self.page.locator(sel).first
                if loc.count() > 0:
                    loc.click(timeout=5000)
                    self.safe_wait_dom()
                    self.disable_leave_warning()
                    return True
            except Exception:
                pass
        return False

    def open_new_case(self) -> None:
        expected = ["kerelmezocsaladnev", "kerelmezoutonev", "kerelmezoap"]
        candidates = [self.case_cfg["new_url"], self.case_cfg["accordion_url"], BASE_URL + "/eh/cases/new"]
        last_url = candidates[0]
        for idx, url in enumerate(candidates, start=1):
            last_url = url
            print(f"Megnyitás / próba {idx}: {url}")
            self.safe_goto(url)
            self.wait_for_login_if_needed(url)
            self.safe_wait_dom()
            self.disable_leave_warning()
            if self.has_any_field(expected, timeout_ms=8000):
                self.log("open_new_case", "OK", self.page.url)
                return
            if self.try_click_new_case_type_link():
                self.wait_for_login_if_needed(self.page.url)
                self.safe_wait_dom()
                self.disable_leave_warning()
                if self.has_any_field(expected, timeout_ms=8000):
                    self.log("open_new_case", "OK", self.page.url)
                    return
        print("Nem jutottam automatikusan az EH űrlapra.")
        print(f"Várt típus: {self.case_cfg['label']} | utolsó URL: {last_url}")
        input("Nyisd meg kézzel a megfelelő EH űrlapot, majd itt Enter...")
        self.log("open_new_case", "MANUAL", self.page.url)

    def apply_page_defaults(self, sheet_name: str) -> None:
        # Alap régi defaultok megmaradnak, utána a hosszabbítás / kérelemtípus felülírja.
        super().apply_page_defaults(sheet_name)
        is_extension = bool(self.case_cfg.get("default_extension"))
        if sheet_name in {"Kerelem", "VendegmKerelem"}:
            # tartenghosszab: nem/igen. Régi script alapból nem-et tett, extension esetén felülírjuk igenre.
            self.radio_by_name("tartenghosszab", "igen" if is_extension else "nem", warn=False)
            # Biztonság kedvéért pár EH variáns.
            self.radio_by_name("hosszabbitas", "igen" if is_extension else "nem", warn=False)
            self.radio_by_name("extension", "igen" if is_extension else "nem", warn=False)
        if sheet_name in {"Kerelem2", "VendegmKerelem2"}:
            # Közös munkavállalási betétlap mezők, ha név alapján léteznek.
            self.radio_by_name("tudmagyarul", "nem", warn=False)
            anyanyelv = first_non_empty(self.data._lookup_key("mother_tongue"), self.data._lookup_key("native_language"), "Angol")
            if anyanyelv:
                self.select_by_name("anyanyelv", anyanyelv)
            feor = first_non_empty(self.data._lookup_key("effective_feor_code"), self.data._lookup_key("feor_code"), self.data._lookup_key("feor"))
            if feor:
                for nm in ["feor", "FEOR"]:
                    if self.has_name(nm):
                        try:
                            self.fill_by_name(nm, feor)
                        except Exception:
                            pass
            if self.app_type in {"vendeg", "vendeg_9_7"}:
                self.radio_by_name("btatv34", "igen", warn=False)
                self.fill_by_name("btatv34nap", first_non_empty(self.data._lookup_key("qualified_lender_registration_date"), "2024-03-11"), allow_empty=False)
                self.fill_by_name("btatv34szam", first_non_empty(self.data._lookup_key("qualified_lender_registration_number"), "BP/0702/00010-4/2024"), allow_empty=False)

    def open_second_page(self) -> bool:
        case_id = self.extract_case_id()
        if not case_id:
            print("Nem tudtam automatikusan kiolvasni az EH ügyazonosítót az URL-ből.")
            case_id = input("Írd be az EH ügyazonosítót, vagy Enter a megszakításhoz: ").strip()
            if not case_id:
                return False
        suffix = self.case_cfg["url_suffix"]
        url = f"{BASE_URL}/eh/cases/edit/{case_id}/{suffix}"
        print(f"Betétlap megnyitása: {url}")
        self.safe_goto(url)
        self.wait_for_login_if_needed(url)
        expected = ["anyanyelv", "tudmagyarul"]
        if self.app_type in {"vendeg", "vendeg_9_7"}:
            expected += ["btatv34", "btatv34nap", "btatv34szam"]
        self.ensure_form_ready(f"2. oldal / {self.case_cfg['label']}", expected, url)
        self.log("open_second_page", "OK", url)
        return True

    def confirm_and_submit(self, stage_label: str) -> bool:
        print("\n" + "=" * 70)
        print(f"ELLENŐRZÉSI PONT: {stage_label}")
        if not self.allow_submit_flag:
            print("Biztonsági mód: submit tiltva. Nézd át az oldalt; Enter = tovább submit nélkül, q = kilép.")
            ans = input("> ").strip().lower()
            if ans == "q":
                return False
            self.log(stage_label, "REVIEW_ONLY_NO_SUBMIT", "allow_submit=false")
            return True
        return super().confirm_and_submit(stage_label)

    def run(self) -> None:
        self.open_new_case()
        first_sheet = self.case_cfg["first_sheet"]
        second_sheet = self.case_cfg["second_sheet"]
        self.fill_mapping_sheet(first_sheet)
        if not self.confirm_and_submit("1. oldal / fő kérelem"):
            return
        if not self.open_second_page():
            return
        self.fill_mapping_sheet(second_sheet)
        if not self.confirm_and_submit("2. oldal / betétlap"):
            return
        self.log("workflow", "DONE", "Payload-first EH kitöltési workflow befejezve")
        print("\nKész. Ellenőrizd az EH-ban a végső állapotot / dokumentumfeltöltést / beadást.")


def safe_accept_dialog(dialog) -> None:
    try:
        print(f"EH felugró ablak kezelve: {dialog.message}")
        dialog.accept()
    except Exception:
        pass


def main() -> int:
    parser = argparse.ArgumentParser(description="EnterHungary XLS-free payload-first asszisztens v12")
    parser.add_argument("--json", "--package-json", dest="json_path", required=True, help="Retool/Gateway package.json vagy P02 payload JSON útvonala")
    parser.add_argument("--application-type", "--type", dest="application_type", default="", help="nemzeti | vendeg | foglalkoztatasi_9_6 | vendeg_9_7")
    parser.add_argument("--allow-submit", action="store_true", help="Engedi a régi Mehet/Rögzít kattintást kézi ellenőrzés után. Alapból tiltva.")
    parser.add_argument("--profile", default=".eh_edge_profile", help="Playwright profil mappa")
    parser.add_argument("--browser", choices=["chrome", "edge", "chromium", "auto"], default="edge")
    parser.add_argument("--connect-cdp", action="store_true", help="Már futó Edge/Chrome remote debugging böngészőhöz kapcsolódik")
    parser.add_argument("--cdp-url", default="http://127.0.0.1:9222")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    json_path = Path(args.json_path).resolve()
    if not json_path.exists():
        print(f"Nem találom a JSON payloadot: {json_path}")
        return 2

    data = PayloadData(json_path, args.application_type)
    app_type = data.app_type
    name = data.row_display_name(2)
    print("\nEH ASSZISZTENS v12 XLS-free")
    print(f"Payload: {json_path}")
    print(f"Munkavállaló: {name}")
    print(f"Application type: {app_type} | {data.case_cfg['label']}")
    print(f"EH new URL: {data.case_cfg['new_url']}")
    print(f"Submit engedélyezve: {args.allow_submit}")
    if args.connect_cdp:
        print(f"CDP mód: {args.cdp_url}")

    profile_dir = (script_dir / args.profile).resolve()
    launch_args = [
        "--ignore-certificate-errors",
        "--allow-running-insecure-content",
        "--disable-features=HttpsFirstBalancedModeAutoEnable,HttpsUpgrades",
    ]

    def launch_with_channel(playwright_obj, channel_name: Optional[str], label: str) -> BrowserContext:
        kwargs = dict(
            user_data_dir=str(profile_dir),
            headless=False,
            viewport={"width": 1400, "height": 950},
            accept_downloads=True,
            ignore_https_errors=True,
            args=launch_args,
            chromium_sandbox=True,
        )
        if channel_name:
            kwargs["channel"] = channel_name
        print(f"Böngésző indítása: {label} | profil: {profile_dir}")
        return playwright_obj.chromium.launch_persistent_context(**kwargs)

    with sync_playwright() as p:
        browser = None
        close_context_at_end = True
        if args.connect_cdp:
            try:
                browser = p.chromium.connect_over_cdp(args.cdp_url, timeout=15000)
                context = browser.contexts[0] if browser.contexts else browser.new_context(ignore_https_errors=True, accept_downloads=True)
                close_context_at_end = False
                print("CDP kapcsolat OK.")
            except Exception as exc:
                print(f"Nem sikerült csatlakozni CDP-n: {exc}")
                return 3
        else:
            try:
                if args.browser == "chrome":
                    context = launch_with_channel(p, "chrome", "Google Chrome")
                elif args.browser == "edge":
                    context = launch_with_channel(p, "msedge", "Microsoft Edge")
                elif args.browser == "chromium":
                    context = launch_with_channel(p, None, "Playwright Chromium")
                else:
                    try:
                        context = launch_with_channel(p, "msedge", "Microsoft Edge")
                    except Exception:
                        context = launch_with_channel(p, "chrome", "Google Chrome")
            except Exception as exc:
                print(f"Böngésző indítás fallback Chromiumra: {exc}")
                context = launch_with_channel(p, None, "Playwright Chromium")
        page = context.pages[0] if context.pages else context.new_page()
        page.on("dialog", lambda dialog: safe_accept_dialog(dialog))
        assistant = PayloadEHAssistant(page, data, 2, app_type, json_path.parent, allow_submit=args.allow_submit)
        try:
            assistant.run()
        finally:
            input("Enter a script befejezéséhez...")
            if close_context_at_end:
                try:
                    context.close()
                except Exception as exc:
                    print(f"A böngésző már bezáródott / kapcsolat megszakadt: {exc}")
            else:
                print("CDP módban nem zárom be a böngészőt.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
