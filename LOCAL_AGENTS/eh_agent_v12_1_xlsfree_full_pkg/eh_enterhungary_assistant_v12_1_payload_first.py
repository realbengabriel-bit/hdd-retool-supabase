# -*- coding: utf-8 -*-
"""
EnterHungary XLS-free payload-first kitöltő asszisztens v12.1.

Újdonság a v12-höz képest:
- A feltöltött EH HTML-ek alapján pontosított route/tab/field név támogatás.
- XLSM nélkül P02/Retool/Supabase JSON payloadból tölt.
- Támogatott: Nemzeti Kártya 9.12, Foglalkoztatás 9.6, Vendégmunkás 9.7.
- Hosszabbításnál a fő kérelemben automatikusan tartenghosszab=igen.
- A szálláshely/szálláshelyváltozás bejelentése tab opcionálisan töltődik.
- Submit továbbra is kézi review és --allow-submit nélkül tiltott.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import unicodedata
from pathlib import Path
from typing import Any, Dict, Optional, List, Tuple

from playwright.sync_api import sync_playwright

import eh_enterhungary_assistant_v12_payload_first as v12

BASE_URL = v12.BASE_URL
SERVICE_VERSION = "12.1.0-xlsfree-full-eh-html-mapped"

# Kiterjesztett aliasok: Retool/PDF név, EH név, emberi név alapján is felismer.
EXTRA_TYPE_ALIASES = {
    "extension": "foglalkoztatasi_9_6",
    "employment": "foglalkoztatasi_9_6",
    "foglalkoztatas": "foglalkoztatasi_9_6",
    "foglalkoztatási": "foglalkoztatasi_9_6",
    "guest_worker": "vendeg_9_7",
    "guest_worker_extension": "vendeg_9_7",
    "vendegmunkas": "vendeg_9_7",
    "vendégmunkás": "vendeg_9_7",
    "national_card": "nemzeti",
    "nemzeti_kartya": "nemzeti",
    "nemzeti_kártya": "nemzeti",
}


def norm(s: Any) -> str:
    if s is None:
        return ""
    text = str(s).strip().replace("–", "-").replace("—", "-").replace("-", " ")
    text = " ".join(text.split())
    text = unicodedata.normalize("NFD", text)
    text = "".join(ch for ch in text if unicodedata.category(ch) != "Mn")
    return text.lower()


def clean(v: Any) -> str:
    if v is None:
        return ""
    if isinstance(v, (dt.datetime, dt.date)):
        return v.strftime("%Y-%m-%d")
    return " ".join(str(v).strip().split())


def only_digits(v: Any) -> str:
    return re.sub(r"\D+", "", clean(v))


def normalize_date(v: Any) -> str:
    s = clean(v)
    if not s:
        return ""
    m = re.search(r"(\d{4})[.\-/ ](\d{1,2})[.\-/ ](\d{1,2})", s)
    if m:
        return f"{m.group(1)}-{int(m.group(2)):02d}-{int(m.group(3)):02d}"
    return s


def normalize_gender(v: Any) -> str:
    n = norm(v)
    if n in {"m", "male", "ferfi", "ffi", "férfi"} or "ferfi" in n:
        return "Férfi"
    if n in {"f", "female", "no", "nő", "noeoe"} or n == "noi" or "female" in n:
        return "Nő"
    return clean(v)


def normalize_currency(v: Any) -> str:
    n = norm(v)
    if n in {"huf", "ft", "forint", "magyar forint"} or not n:
        return "Forint"
    if n in {"eur", "euro", "euró"}:
        return "Euró"
    return clean(v)


def normalize_yes_no(v: Any, default: str = "nem") -> str:
    n = norm(v)
    if n in {"1", "true", "igen", "yes", "y", "i"}:
        return "igen"
    if n in {"0", "false", "nem", "no", "n"}:
        return "nem"
    return default


def parse_hu_address(text: Any) -> Dict[str, str]:
    s = clean(text)
    if not s:
        return {}
    out: Dict[str, str] = {}
    m = re.search(r"\b(\d{4})\b\s+([^,]+),?\s*(.*)", s)
    rest = s
    if m:
        out["zip"] = m.group(1)
        out["city"] = clean(m.group(2))
        rest = clean(m.group(3))
    # street type vocabulary used by EH labels
    street_types = [
        "utca", "út", "tér", "körút", "köz", "sor", "park", "sétány", "dűlő", "rakpart", "fasor",
        "útja", "tere", "lakótelep", "major", "telep", "hrsz", "helyrajzi szám"
    ]
    # remove trailing dot
    rest = rest.strip(" .,;")
    # house number: everything after last street type or first number cluster
    mnum = re.search(r"(.+?)\s+(\d+[\w/\-.]*)\s*(.*)$", rest)
    if mnum:
        street_part = clean(mnum.group(1))
        out["house_number"] = clean(mnum.group(2))
    else:
        street_part = rest
    parts = street_part.split()
    if parts:
        last = parts[-1].lower()
        if last in street_types:
            out["street_type"] = parts[-1]
            out["street"] = clean(" ".join(parts[:-1]))
        else:
            out["street"] = clean(street_part)
    return {k: v for k, v in out.items() if v}


class PayloadDataV121(v12.PayloadData):
    def __init__(self, payload_path: Path, app_type: Optional[str] = None, mapping_path: Optional[Path] = None):
        super().__init__(payload_path, app_type, mapping_path)
        self.app_type = self._canonical_v121(app_type)
        self.case_cfg = v12.resolve_case_type(self.app_type)

    def _canonical_v121(self, raw: Any) -> str:
        base = v12.canonical_app_type(raw, self.payload)
        blob_parts = [raw, base]
        for k in ["application_type", "application_type_code", "app_type", "data.package.application_type", "data.package.application_type_code", "data.package.app_type"]:
            val = v12.deep_get(self.payload, k)
            if val:
                blob_parts.append(val)
        blob = norm(" ".join(clean(x) for x in blob_parts if x is not None))
        for key, typ in EXTRA_TYPE_ALIASES.items():
            if norm(key) in blob:
                return typ
        return base

    def any_value(self, *keys: str, default: str = "") -> str:
        for key in keys:
            val = self._lookup_key(key)
            if val:
                return clean(val)
        return clean(default)

    def address_value(self, prefix: str, field: str, fallback_text_keys: Tuple[str, ...] = ()) -> str:
        val = self.any_value(f"{prefix}.{field}", f"{prefix}_{field}", field)
        if val:
            return val
        for text_key in fallback_text_keys:
            parsed = parse_hu_address(self.any_value(text_key))
            if parsed.get(field):
                return parsed[field]
        return ""


class PayloadEHAssistantV121(v12.PayloadEHAssistant):
    def __init__(self, page, data: PayloadDataV121, row_no: int, app_type: str, base_dir: Path, allow_submit: bool = False, fill_accommodation: bool = True):
        super().__init__(page, data, row_no, app_type, base_dir, allow_submit=allow_submit)
        self.data: PayloadDataV121 = data
        self.fill_accommodation = fill_accommodation

    def getv(self, *keys: str, default: str = "") -> str:
        return self.data.any_value(*keys, default=default)

    def field_override(self, name: str) -> str:
        for key in [
            f"field_overrides.{name}",
            f"data.field_overrides.{name}",
            f"additional_payload.field_overrides.{name}",
            f"eh_fields.{name}",
            f"data.eh_fields.{name}",
        ]:
            v = self.data._lookup_key(key)
            if v:
                return v
        return ""

    def value_for_name(self, name: str, *keys: str, default: str = "") -> str:
        over = self.field_override(name)
        if over:
            return over
        return self.getv(*keys, default=default)

    def fill_name(self, name: str, value: Any, allow_empty: bool = False) -> None:
        v = clean(value)
        if not v and not allow_empty:
            return
        if self.has_name(name):
            self.fill_by_name(name, v, allow_empty=allow_empty)

    def select_name(self, name: str, value: Any) -> None:
        v = clean(value)
        if not v:
            return
        if self.has_name(name):
            self.select_by_name(name, v)

    def radio_name(self, name: str, value: Any, warn: bool = False) -> None:
        v = clean(value)
        if not v:
            return
        if self.has_name(name):
            self.radio_by_name(name, v, warn=warn)

    def check_name(self, name: str, checked: bool = True) -> None:
        if not self.has_name(name):
            return
        try:
            loc = self.page.locator(f"input[type='checkbox'][name='{name}']").first
            is_checked = loc.is_checked(timeout=500)
            if bool(is_checked) != bool(checked):
                loc.click(timeout=900)
        except Exception as exc:
            self.log("default_checkbox", "WARN", f"{name}={checked}: {exc}")

    def fill_address_names(self, prefix: str, mapping_prefix: str, fallback_text_keys: Tuple[str, ...]) -> None:
        # mapping_prefix is EH field stem without trailing component, e.g. munkaltato or munkavegzeshelye
        address_fields = {
            "zip": [f"{mapping_prefix}iranyitoszam", f"{mapping_prefix}iranyitoszam"],
            "city": [f"{mapping_prefix}telepules"],
            "street": [f"{mapping_prefix}kozteruletneve"],
            "street_type": [f"{mapping_prefix}kozteruletjellege"],
            "house_number": [f"{mapping_prefix}hazszam"],
            "building": [f"{mapping_prefix}epulet"],
            "floor": [f"{mapping_prefix}emelet"],
            "door": [f"{mapping_prefix}ajto"],
        }
        for fld, names in address_fields.items():
            val = self.data.address_value(prefix, fld, fallback_text_keys)
            if not val:
                continue
            for nm in names:
                if nm.endswith("jellege") or nm.endswith("emelet"):
                    self.select_name(nm, val)
                else:
                    self.fill_name(nm, val)

    def fill_common_main_by_names(self) -> None:
        is_extension = bool(self.case_cfg.get("default_extension"))
        self.radio_name("nemfizetek", self.value_for_name("nemfizetek", "fee_exempt", "is_free_procedure", default="nem"))
        self.radio_name("tartenghosszab", "igen" if is_extension else "nem")
        if is_extension:
            self.fill_name("elozotarengszama", self.value_for_name("elozotarengszama", "previous_permit_number", "residence_permit_number", "bmh.residence_permit_number", "workflow.residence_permit_number"))
            self.fill_name("elozotarengideje", normalize_date(self.value_for_name("elozotarengideje", "previous_permit_valid_until", "residence_permit_valid_until", "bmh.residence_permit_valid_until", "workflow.residence_permit_valid_until")))
        else:
            self.fill_name("beutazashelye", self.value_for_name("beutazashelye", "entry_place", "arrival_place", default=""))
            self.fill_name("beutazasideje", normalize_date(self.value_for_name("beutazasideje", "entry_date", "arrival_date", "planned_arrival_date", "workflow.planned_arrival_date")))

        # Person
        self.fill_name("kerelmezocsaladnev", self.value_for_name("kerelmezocsaladnev", "last_name", "person.last_name", "workflow.last_name", "core.last_name"))
        self.fill_name("kerelmezoutonev", self.value_for_name("kerelmezoutonev", "first_name", "person.first_name", "workflow.first_name", "core.first_name"))
        self.fill_name("kerelmezoszulcsaladnev", self.value_for_name("kerelmezoszulcsaladnev", "birth_last_name", "last_name", "person.birth_last_name", "workflow.last_name"))
        self.fill_name("kerelmezoszulutonev", self.value_for_name("kerelmezoszulutonev", "birth_first_name", "first_name", "person.birth_first_name", "workflow.first_name"))
        self.fill_name("kerelmezoanyjacsaladnev", self.value_for_name("kerelmezoanyjacsaladnev", "mother_last_name", "mother_family_name", "person.mother_last_name"))
        self.fill_name("kerelmezoanyjautonev", self.value_for_name("kerelmezoanyjautonev", "mother_first_name", "mother_given_name", "person.mother_first_name"))
        self.select_name("kerelmezoszulorszag", self.value_for_name("kerelmezoszulorszag", "birth_country", "person.birth_country", "workflow.birth_country", "nationality"))
        self.fill_name("kerelmezoszulhely", self.value_for_name("kerelmezoszulhely", "birth_place", "birth_city", "person.birth_place", "workflow.birth_place"))
        self.fill_name("kerelmezoszulido", normalize_date(self.value_for_name("kerelmezoszulido", "birth_date", "person.birth_date", "workflow.birth_date")))
        self.select_name("kerelmezonem", normalize_gender(self.value_for_name("kerelmezonem", "gender", "sex", "person.gender")))
        self.select_name("kerelmezoap", self.value_for_name("kerelmezoap", "nationality", "citizenship", "person.nationality", "workflow.nationality"))
        self.select_name("csaladiallapot", self.value_for_name("csaladiallapot", "marital_status", default="Nőtlen/hajadon"))
        self.fill_name("szakkepzettseg", self.value_for_name("szakkepzettseg", "qualification", "education_qualification", "effective_feor_name", "feor_name", "position_name", default="Betanított munkás"))
        self.select_name("vegzettseg", self.value_for_name("vegzettseg", "education_level", default="Középfokú"))
        self.fill_name("kerelmezokulfoldifoglakozas", self.value_for_name("kerelmezokulfoldifoglakozas", "previous_occupation", "position_name", "effective_feor_name", "feor_name", default="Munkavállaló"))
        self.radio_name("hatarmentiingazo", self.value_for_name("hatarmentiingazo", "border_commuter", default="nem"))

        # Passport
        self.fill_name("utlevelszama", self.value_for_name("utlevelszama", "passport_number", "passport.number", "workflow.passport_number"))
        self.select_name("utleveltipus", self.value_for_name("utleveltipus", "passport_type", default="Magán"))
        self.fill_name("kiallitashelye", self.value_for_name("kiallitashelye", "passport_issue_place", "passport.issue_place"))
        self.fill_name("kiallitasideje", normalize_date(self.value_for_name("kiallitasideje", "passport_issue_date", "passport.issue_date")))
        self.fill_name("ervenyessegiideje", normalize_date(self.value_for_name("ervenyessegiideje", "passport_expiry_date", "passport.expiry_date", "workflow.passport_expiry_date")))

        # Accommodation on main application page
        self.fill_address_names("accommodation", "", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation"))
        # The above empty prefix creates field names iranyitoszam etc.; explicit fallback for common page.
        self.fill_name("iranyitoszam", self.data.address_value("accommodation", "zip", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("telepules", self.data.address_value("accommodation", "city", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("kozteruletneve", self.data.address_value("accommodation", "street", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.select_name("kozteruletjellege", self.data.address_value("accommodation", "street_type", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("hazszam", self.data.address_value("accommodation", "house_number", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("epulet", self.data.address_value("accommodation", "building", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.select_name("emelet", self.data.address_value("accommodation", "floor", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("ajto", self.data.address_value("accommodation", "door", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.select_name("tartjogcim", self.value_for_name("tartjogcim", "accommodation.legal_title", "accommodation_legal_title", default="Egyéb"))
        self.fill_name("tartjogcimegyeb", self.value_for_name("tartjogcimegyeb", "accommodation.legal_title_other", default="befogadó nyilatkozat, munkáltató bérli"))
        self.select_name("ebmagyartart", self.value_for_name("ebmagyartart", "health_insurance", "health_insurance_type", default="Foglalkoztatási Jogviszony Alapján"))

        # Travel/return/coverage
        self.select_name("tovabborszag", self.value_for_name("tovabborszag", "return_country", "nationality", default=""))
        self.radio_name("utlevel", self.value_for_name("utlevel", "has_passport", default="igen"))
        self.radio_name("vizum", self.value_for_name("vizum", "has_visa", default="igen"))
        self.radio_name("jegy", self.value_for_name("jegy", "has_ticket", default="nem"))
        self.radio_name("penz", self.value_for_name("penz", "has_financial_coverage", default="igen"))
        self.fill_name("osszeg", only_digits(self.value_for_name("osszeg", "salary", "gross_salary", "monthly_salary", "expected_income", "package.salary", default="100000")))
        self.select_name("osszegpenznem", normalize_currency(self.value_for_name("osszegpenznem", "currency", "salary_currency", "package.currency", default="Forint")))

        # Risk/medical defaults
        for nm in ["korabbielut", "korabbibuntetes", "korabbikiut", "beteg", "reszesulkezelesben", "kijelentemgyerek", "schengeniokmany"]:
            self.radio_name(nm, self.value_for_name(nm, nm, default="nem"))
        self.fill_name("meddig", normalize_date(self.value_for_name("meddig", "requested_until", "requested_valid_until", "residence_permit_valid_until", "workflow.residence_permit_valid_until")))
        self.fill_name("email", self.value_for_name("email", "email", "person.email", "workflow.email", "case_manager_email", "validated_project_lead_email"))
        self.fill_name("telefon", self.value_for_name("telefon", "phone", "person.phone", "workflow.phone", "case_manager_phone"))
        self.radio_name("atvetel", self.value_for_name("atvetel", "document_pickup_mode", default="atvetel_posta"))
        self.radio_name("atvetel_cim", self.value_for_name("atvetel_cim", "document_delivery_address_type", default="cim_meghatalamzott"))
        self.check_name("nyilatkozat1", True)
        self.check_name("nyilatkozat2", True)

    def fill_employer_and_workplace(self) -> None:
        self.select_name("benyujto", self.value_for_name("benyujto", "submitter_type", default=("minősített kölcsönbeadó" if self.app_type in {"vendeg", "vendeg_9_7"} else "foglalkoztató")))
        self.fill_name("varhatojovedelemosszege", only_digits(self.value_for_name("varhatojovedelemosszege", "salary", "gross_salary", "monthly_salary", "expected_income", "package.salary", default="455976")))
        self.select_name("varhatojovedelemosszegepenznem", normalize_currency(self.value_for_name("varhatojovedelemosszegepenznem", "currency", "salary_currency", "package.currency", default="Forint")))
        self.fill_name("munkaltatomunkaltatoneve", self.value_for_name("munkaltatomunkaltatoneve", "employer.short_name", "employer.name", "company_name", "validated_partner_name", "workflow.validated_partner_name", "workflow.partner_name"))
        self.fill_address_names("employer", "munkaltato", ("employer.address", "company_address", "workplace.address"))
        self.select_name("munkaltatoteaorszam", self.value_for_name("munkaltatoteaorszam", "employer.teao", "teao", "main_activity_teao", default="7820"))
        self.check_name("munkaltatoteaorszam_25", True)
        self.fill_name("munkaltatokshszam", self.value_for_name("munkaltatokshszam", "employer.ksh_number", "ksh_number"))
        self.fill_name("munkaltatomunkaltatoadoszama", self.value_for_name("munkaltatomunkaltatoadoszama", "employer.tax_number", "tax_number", "employer_tax_number", "company_tax_number"))
        self.fill_name("szakkepzettseg", self.value_for_name("szakkepzettseg", "qualification", "education_qualification", "effective_feor_name", "feor_name", default="Betanított munkás"))
        self.select_name("vegzettseg", self.value_for_name("vegzettseg", "education_level", default="Középfokú"))
        self.fill_name("kulfoldifoglakozas", self.value_for_name("kulfoldifoglakozas", "previous_occupation", "position_name", "effective_feor_name", default="Munkavállaló"))
        self.check_name("egymunkahely", True)
        self.fill_address_names("workplace", "munkavegzeshelye", ("workplace.address", "employer.address", "planned_workplace_address"))
        self.fill_name("foglakoztataskezdete", normalize_date(self.value_for_name("foglakoztataskezdete", "preliminary_agreement_date", "employment_contract_date", "assignment_start_date", "workflow.assignment_start_date", "actual_start_date", "workflow.actual_start_date")))
        self.select_name("feorszam", self.value_for_name("feorszam", "effective_feor_code", "feor_code", "feor", "workflow.feor", "package.effective_feor_code"))
        self.fill_name("gyakorlatiido", self.value_for_name("gyakorlatiido", "professional_experience_years", default="0"))
        self.fill_name("specialisismeretek", self.value_for_name("specialisismeretek", "special_skills", "position_name", "effective_feor_name"))
        mother_tongue = self.value_for_name("anyanyelv", "mother_tongue", "native_language", default="Angol")
        self.select_name("anyanyelv", mother_tongue)
        self.radio_name("tudmagyarul", self.value_for_name("tudmagyarul", "speaks_hungarian", default="nem"))
        self.radio_name("korabbandolgozottmo", self.value_for_name("korabbandolgozottmo", "worked_before_in_hungary", default="nem"))

    def fill_annex_by_names(self) -> None:
        self.fill_employer_and_workplace()
        if self.app_type == "foglalkoztatasi_9_6":
            self.radio_name("munkakornemszerepel", self.value_for_name("munkakornemszerepel", "employment_relation_based", default="igen"))
            self.radio_name("foglalkoztatomegallapodas", self.value_for_name("foglalkoztatomegallapodas", "third_country_agreement_based", default="nem"))
            self.radio_name("mentessegkhiv", self.value_for_name("mentessegkhiv", "no_government_office_involvement", default="nem"))
            self.radio_name("mentessegmunkavallas", self.value_for_name("mentessegmunkavallas", "work_permit_exempt", default="nem"))
            self.radio_name("mentessegmpiac", self.value_for_name("mentessegmpiac", "labour_market_test_exempt", default="nem"))
        if self.app_type in {"vendeg", "vendeg_9_7"}:
            self.select_name("foglkoztatotip", self.value_for_name("foglkoztatotip", "qualified_lender_type", "employer.employer_type", default="minősített munkaerő kölcsönző"))
            self.radio_name("btatv34", self.value_for_name("btatv34", "btatv34", "btatv_34", default="igen"))
            self.fill_name("btatv34nap", normalize_date(self.value_for_name("btatv34nap", "qualified_lender_registration_date", default="2024-03-11")))
            self.fill_name("btatv34szam", self.value_for_name("btatv34szam", "qualified_lender_registration_number", default="BP/0702/00010-4/2024"))
            # 9.7-ben alapból a 12. kérdés 1. pont szerinti igen, ha payload nem írja felül.
            self.radio_name("mentessegkhiv", self.value_for_name("mentessegkhiv", "no_government_office_involvement", default="igen"))
            self.fill_name("mentessegkhivpont", self.value_for_name("mentessegkhivpont", "no_government_office_point", default="1"))
            self.radio_name("mentessegmpiac", self.value_for_name("mentessegmpiac", "labour_market_test_exempt", default="nem"))
        # közös 10-13 / visszautazási blokk
        self.select_name("tavorszag", self.value_for_name("tavorszag", "return_country", "nationality", default=""))
        self.select_name("kiutasitasceltip", self.value_for_name("kiutasitasceltip", "expulsion_destination_type", default="az állampolgárságom szerinti állam"))

    def fill_accommodation_tab_by_names(self) -> None:
        self.fill_name("kerelmezoutiokmanyszama", self.value_for_name("kerelmezoutiokmanyszama", "passport_number", "passport.number", "workflow.passport_number"))
        self.fill_name("kerelemzoutiokmanyerv", normalize_date(self.value_for_name("kerelemzoutiokmanyerv", "passport_expiry_date", "passport.expiry_date", "workflow.passport_expiry_date")))
        self.fill_name("kerelmezotartengszama", self.value_for_name("kerelmezotartengszama", "residence_permit_number", "bmh.residence_permit_number", "workflow.residence_permit_number"))
        self.fill_name("kerelmezoiranyitoszam", self.data.address_value("accommodation", "zip", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("kerelmezotelepules", self.data.address_value("accommodation", "city", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("kerelmezokozteruletneve", self.data.address_value("accommodation", "street", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.select_name("kerelmezokozteruletjellege", self.data.address_value("accommodation", "street_type", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("kerelmezohazszam", self.data.address_value("accommodation", "house_number", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("kerelmezoepulet", self.data.address_value("accommodation", "building", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.select_name("kerelmezoemelet", self.data.address_value("accommodation", "floor", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.fill_name("kerelmezoajto", self.data.address_value("accommodation", "door", ("accommodation.address", "planned_accommodation", "workflow.planned_accommodation")))
        self.select_name("kerelmezotartjogcime", self.value_for_name("kerelmezotartjogcime", "accommodation.legal_title", default="Egyéb"))
        self.fill_name("kerelmezotartjogcimeegyeb", self.value_for_name("kerelmezotartjogcimeegyeb", "accommodation.legal_title_other", default="befogadó nyilatkozat, munkáltató bérli"))

    def apply_page_defaults(self, sheet_name: str) -> None:
        super().apply_page_defaults(sheet_name)
        if sheet_name in {"Kerelem", "VendegmKerelem"}:
            self.fill_common_main_by_names()
        elif sheet_name in {"Kerelem2", "VendegmKerelem2"}:
            self.fill_annex_by_names()

    def open_accommodation_page(self) -> bool:
        case_id = self.extract_case_id()
        if not case_id:
            self.log("open_accommodation", "SKIP", "nincs case_id")
            return False
        url = f"{BASE_URL}/eh/cases/edit/{case_id}/bejelentes-szallas"
        print(f"Szálláshely bejelentés megnyitása: {url}")
        self.safe_goto(url)
        self.wait_for_login_if_needed(url)
        expected = ["kerelmezoutiokmanyszama", "kerelmezoiranyitoszam", "kerelmezokozteruletneve"]
        try:
            self.ensure_form_ready("3. oldal / szálláshely bejelentés", expected, url)
            self.log("open_accommodation", "OK", url)
            return True
        except Exception as exc:
            self.log("open_accommodation", "WARN", str(exc))
            return False

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
        if self.fill_accommodation:
            if self.open_accommodation_page():
                self.fill_accommodation_tab_by_names()
                if not self.confirm_and_submit("3. oldal / szálláshely bejelentés"):
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
    parser = argparse.ArgumentParser(description="EnterHungary XLS-free payload-first asszisztens v12.1")
    parser.add_argument("--json", "--package-json", dest="json_path", required=True, help="Retool/Gateway package.json vagy P02 payload JSON útvonala")
    parser.add_argument("--application-type", "--type", dest="application_type", default="", help="nemzeti | foglalkoztatasi_9_6 | vendeg_9_7")
    parser.add_argument("--allow-submit", action="store_true", help="Engedi a Mehet/Rögzít kattintást kézi ellenőrzés után. Alapból tiltva.")
    parser.add_argument("--skip-accommodation", action="store_true", help="Ne töltse a szálláshely/szálláshelyváltozás bejelentése tabot.")
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

    data = PayloadDataV121(json_path, args.application_type)
    app_type = data.app_type
    name = data.row_display_name(2)
    print("\nEH ASSZISZTENS v12.1 XLS-free")
    print(f"Payload: {json_path}")
    print(f"Munkavállaló: {name}")
    print(f"Application type: {app_type} | {data.case_cfg['label']}")
    print(f"EH new URL: {data.case_cfg['new_url']}")
    print(f"Szálláshely tab töltés: {not args.skip_accommodation}")
    print(f"Submit engedélyezve: {args.allow_submit}")

    profile_dir = (script_dir / args.profile).resolve()
    launch_args = [
        "--ignore-certificate-errors",
        "--allow-running-insecure-content",
        "--disable-features=HttpsFirstBalancedModeAutoEnable,HttpsUpgrades",
    ]

    def launch_with_channel(playwright_obj, channel_name: Optional[str], label: str):
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
        assistant = PayloadEHAssistantV121(
            page, data, 2, app_type, json_path.parent,
            allow_submit=args.allow_submit,
            fill_accommodation=not args.skip_accommodation,
        )
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
