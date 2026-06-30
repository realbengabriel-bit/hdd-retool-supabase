# -*- coding: utf-8 -*-
"""
ENTERHUNGARY PDF -> Munkavállalók import extractor v8

Támogatott PDF típusok:
  - 9.7. Betétlap / Vendégmunkás-tartózkodási engedély
  - 9.12. Betétlap / Nemzeti Kártya

Használat VBA-ból:
    py -3 eh_pdf_extractor_v8_fixed_defaults.py --input-list pdf_lista.txt --out-data adatok.tsv --out-log python_log.tsv

Kell hozzá: PyMuPDF
    py -m pip install pymupdf
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
import traceback
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import fitz  # PyMuPDF
except Exception:
    print("HIBA: a PyMuPDF nincs telepítve. Telepítés: py -m pip install pymupdf", file=sys.stderr)
    raise


def make_letters(last: str = "DH") -> List[str]:
    out = []
    n = 1
    while True:
        col = column_letter(n)
        out.append(col)
        if col == last:
            return out
        n += 1


def column_letter(col_num: int) -> str:
    s = ""
    n = col_num
    while n > 0:
        n, r = divmod(n - 1, 26)
        s = chr(65 + r) + s
    return s


LETTERS = make_letters("DH")


def clean(s: Optional[str]) -> str:
    if s is None:
        return ""
    s = s.replace("\u00a0", " ")
    s = re.sub(r"[ \t\r\f\v]+", " ", s)
    s = re.sub(r"\n+", "\n", s)
    return s.strip()


def one_line(s: Optional[str]) -> str:
    return re.sub(r"\s+", " ", clean(s).replace("\n", " ")).strip()


def norm(s: str) -> str:
    s = one_line(s).lower()
    tr = str.maketrans("áéíóöőúüűÁÉÍÓÖŐÚÜŰ", "aeiooouuuAEIOOOUUU")
    return s.translate(tr)


def rx(text: str, pattern: str, flags: int = re.I | re.S) -> str:
    m = re.search(pattern, text, flags)
    return one_line(m.group(1)) if m else ""


def parse_date(s: str) -> str:
    s = one_line(s)
    m = re.search(r"(\d{4})[.\-/ ]+(\d{1,2})[.\-/ ]+(\d{1,2})", s)
    if not m:
        return ""
    y, mo, d = map(int, m.groups())
    return f"{y:04d}.{mo:02d}.{d:02d}"


def parse_hu_date_words(s: str) -> str:
    s = one_line(s)
    m = re.search(r"(\d{4})\s*év\s*(\d{1,2})\s*hó\s*(\d{1,2})\s*nap", s, re.I)
    if m:
        y, mo, d = map(int, m.groups())
        return f"{y:04d}.{mo:02d}.{d:02d}"
    return parse_date(s)


def fmt_money(s: str) -> str:
    s = one_line(s)
    m = re.search(r"([\d\s.]+)", s)
    if not m:
        return ""
    return re.sub(r"\D", "", m.group(1))


def first_nonempty(*values: str) -> str:
    for v in values:
        if one_line(v):
            return one_line(v)
    return ""


def split_hu_address(addr: str) -> Tuple[str, str, str, str, str]:
    """Returns ZIP, city, street name, street type, house number.

    Handles both normal street addresses and HRSZ-style work locations, e.g.
    "2454 Iváncsa, Külterület HRSZ 099/048". For HRSZ addresses the EH dropdown
    compatible street type is returned as "Kültelek", while the HRSZ number goes
    to the house-number/helyrajzi-szám field.
    """
    addr = one_line(addr).strip(" .")
    m_hrsz = re.search(r"^(\d{4})\s+([^,]+),\s*(.*?)\s+HRSZ\s+([0-9A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű/_\-]+)\.?$", addr, re.I)
    if m_hrsz:
        z, city, area, hrsz = m_hrsz.groups()
        return z.strip(), city.strip(), area.strip() or "Külterület", "Kültelek", hrsz.strip().rstrip(".")

    # A hosszabb közterület-jellegek legyenek elöl, különben az "út" elkapná az "útja" elejét.
    street_types = [
        "üdülő-part", "alsórakpart", "lakótelep", "pályaudvar", "pincesor",
        "határút", "autóút", "körönd", "körtér", "körút", "rakpart",
        "sétány", "sikátor", "sugárút", "villasor", "erdősor", "fasor",
        "átjáró", "mélyút", "lépcső", "dűlő", "utca", "útja", "tér",
        "köz", "sor", "út", "u\\.", "park", "part", "kapu", "gát", "árok",
        "akna", "alagút", "domb", "lejáró", "lejtő", "liget", "orom", "udvar", "tanya"
    ]
    pattern = r"^(\d{4})\s+([^,]+),\s+(.+?)\s+(" + "|".join(street_types) + r")\s+(.+?)\.?$"
    m = re.search(pattern, addr, re.I)
    if not m:
        return "", "", "", "", ""
    z, city, street, stype, house = m.groups()
    stype = stype.replace("u.", "utca").strip()
    return z.strip(), city.strip(), street.strip(), stype, house.strip().rstrip(".")


def checkbox_rects_and_checked(page) -> Tuple[List[fitz.Rect], List[fitz.Rect]]:
    rects: List[fitz.Rect] = []
    lines = []
    for d in page.get_drawings():
        for item in d.get("items", []):
            if item[0] == "re":
                r = item[1]
                if 6 <= r.width <= 14 and 6 <= r.height <= 14:
                    rects.append(r)
            elif item[0] == "l":
                p1, p2 = item[1], item[2]
                if abs(p1.x - p2.x) > 4 and abs(p1.y - p2.y) > 4:
                    lines.append((p1, p2))
    checked: List[fitz.Rect] = []
    for r in rects:
        er = fitz.Rect(r.x0 - 1.7, r.y0 - 1.7, r.x1 + 1.7, r.y1 + 1.7)
        cnt = 0
        for p1, p2 in lines:
            if er.contains(p1) and er.contains(p2):
                cnt += 1
        if cnt >= 2:
            checked.append(r)
    return rects, checked


def checked_option_by_label(page, labels: List[str], max_dx: float = 45, max_dy: float = 10) -> str:
    """Find a checked box immediately left of a label word/phrase."""
    _, checked = checkbox_rects_and_checked(page)
    words = page.get_text("words")
    candidates = []
    for label in labels:
        ln = norm(label).strip(".,:;")
        for w in words:
            x0, y0, x1, y1, txt, *_ = w
            if norm(str(txt)).strip(".,:;") == ln:
                ly = (y0 + y1) / 2
                for r in checked:
                    ry = (r.y0 + r.y1) / 2
                    dx = x0 - r.x1
                    if 0 <= dx <= max_dx and abs(ly - ry) <= max_dy:
                        candidates.append((abs(ly - ry) + dx / 100, label))
    if candidates:
        candidates.sort(key=lambda x: x[0])
        return candidates[0][1]
    return ""


def is_checked_near_words(page, yes_words: List[str], no_words: List[str]) -> str:
    opt = checked_option_by_label(page, yes_words + no_words, max_dx=55, max_dy=11)
    n = norm(opt)
    if any(n == norm(w) for w in yes_words):
        return "Igen"
    if any(n == norm(w) for w in no_words):
        return "Nem"
    return ""


def extract_texts(doc) -> List[str]:
    return [p.get_text("text") for p in doc]


def get_page_containing(texts: List[str], needle: str) -> int:
    n = norm(needle)
    for i, t in enumerate(texts):
        if n in norm(t):
            return i
    return -1


def pages_text(texts: List[str], start: int, count: int) -> str:
    if start < 0:
        return ""
    return "\n".join(texts[start:min(len(texts), start + count)])


def option_title_case_school(value: str) -> str:
    n = norm(value)
    mapping = {
        "altalanos": "Általános Iskola",
        "altalanos iskola": "Általános Iskola",
        "szakkozepiskola": "Szakközépiskola",
        "szakmunkaskepzo": "Szakmunkásképző",
        "szakiskola": "Szakiskola",
        "gimnazium": "Gimnázium",
        "technikum": "Technikum",
        "foiskola": "Főiskola",
        "egyetem": "Egyetem",
        "8 altalanosnal kevesebb": "8 Általánosnál Kevesebb",
    }
    return mapping.get(n, value)


def option_work_street_type(value: str) -> str:
    """EH munkavégzési/foglalkoztatói cím dropdown text.

    A fő szálláshely mezőben a közterület jellege kisbetűs (pl. 'utca'),
    de a munkavégzési és foglalkoztatói cím dropdownban nagybetűs
    display text kell (pl. 'Utca', 'Út', 'Tér').
    """
    n = norm(value)
    mapping = {
        "utca": "Utca",
        "u.": "Utca",
        "ut": "Út",
        "utja": "Útja",
        "ter": "Tér",
        "korut": "Körút",
        "koz": "Köz",
        "sor": "Sor",
        "fasor": "Fasor",
        "erdosor": "Erdősor",
        "setany": "Sétány",
        "sugarut": "Sugárút",
        "park": "Park",
        "dulo": "Dűlő",
        "rakpart": "Rakpart",
        "hrsz": "Kültelek",
        "kulterulet": "Kültelek",
        "kultelek": "Kültelek",
    }
    if n in mapping:
        return mapping[n]
    return value[:1].upper() + value[1:] if value else ""


def option_accommodation_title(value: str) -> str:
    mapping = {
        "berlo": "Bérlő",
        "tulajdonos": "Tulajdonos",
        "csaladtag": "Családtag",
        "szivessegi lakashasznalo": "Szívességi Lakáshasználó",
        "egyeb": "Egyéb",
    }
    return mapping.get(norm(value), value)


def find_annex_page(texts: List[str]) -> Tuple[int, str]:
    """Return actual annex start page and form type. Avoid false hits from the purpose list on the main application page."""
    for i, t in enumerate(texts):
        head = t[:1200]
        if re.search(r"^\s*9\.7\.\s*Betétlap", head, re.I | re.M) and "BETÉTLAP" in head:
            return i, "VENDEGMUNKAS"
        if re.search(r"^\s*9\.12\.\s*Betétlap", head, re.I | re.M) and "BETÉTLAP" in head:
            return i, "NEMZETI"
    for i, t in enumerate(texts):
        head = norm(t[:1500])
        if "betetlap tartozkodasi engedely" in head and "vendegmunkas" in head:
            return i, "VENDEGMUNKAS"
        if "betetlap tartozkodasi engedely" in head and "nemzeti kartya" in head:
            return i, "NEMZETI"
    return -1, "ISMERETLEN"


def extract_yes_no_by_section_text(section: str, yes_point_pattern: str = r"Igen") -> str:
    # Text-only fallback: if the PDF parser has the selected answer text near the section.
    if re.search(r"\bNem\b\s*(?:\.|TÁJÉKOZTATÓ|$)", section, re.I):
        # Nem is commonly present unselected, so this alone is not enough.
        return ""
    if re.search(yes_point_pattern, section, re.I):
        return "Igen"
    return ""


def extract_pdf(pdf_path: Path) -> Tuple[Dict[str, str], List[str]]:
    warnings: List[str] = []
    data: Dict[str, str] = {k: "" for k in LETTERS}

    with fitz.open(str(pdf_path)) as doc:
        texts = extract_texts(doc)
        full = "\n".join(texts)
        full1 = one_line(full)
        p_annex, form_type = find_annex_page(texts)

        p_main1 = get_page_containing(texts, "1. A kérelmező személyes adatai")
        p_main2 = get_page_containing(texts, "2. A kérelmező útlevelének adatai")
        p_main3 = get_page_containing(texts, "7. Egyéb adatok")
        p_agreement = get_page_containing(texts, "Előzetes megállapodás foglalkoztatásra")
        if p_agreement < 0:
            p_agreement = get_page_containing(texts, "Pre-employment agreement")

        t1 = texts[p_main1] if p_main1 >= 0 else full
        t2 = texts[p_main2] if p_main2 >= 0 else full
        t3 = texts[p_main3] if p_main3 >= 0 else full
        annex_text = pages_text(texts, p_annex, 3) if p_annex >= 0 else full
        agreement_text = pages_text(texts, p_agreement, 4) if p_agreement >= 0 else full

        # Personal data
        family = rx(t1, r"családi név \(útlevél szerint\):\s*(.*?)\s+utónév \(útlevél szerint\):")
        given = rx(t1, r"utónév \(útlevél szerint\):\s*(.*?)\s+születési családi név:")
        birth_family = rx(t1, r"születési családi név:\s*(.*?)\s+születési utónév:") or family
        birth_given = rx(t1, r"születési utónév:\s*(.*?)(?:\n|$)") or given
        if not family or not given:
            nm = rx(agreement_text, r"Név:\s*([A-ZÁÉÍÓÖŐÚÜŰa-záéíóöőúüű .'-]+)\s+Születési név:")
            if nm:
                parts = nm.split()
                family = family or (parts[0] if parts else "")
                given = given or (" ".join(parts[1:]) if len(parts) > 1 else "")
        mother_family = rx(t2, r"anyja születési családi neve:\s*(.*?)\s+anyja születési utóneve:")
        mother_given = rx(t2, r"anyja születési utóneve:\s*(.*?)\s+nem:")

        gender = rx(agreement_text, r"(?:Gender|Neme):\s*(Nő|Férfi|No|Female|Male)")
        if norm(gender) in ("no", "female"):
            gender = "Nő"
        elif norm(gender) in ("ferfi", "male"):
            gender = "Férfi"
        if not gender and p_main2 >= 0:
            gender = checked_option_by_label(doc[p_main2], ["férfi", "nő"])
            if norm(gender) == "no":
                gender = "Nő"

        birth_date = parse_date(rx(t2, r"születési idő:\s*(.*?)\s+születési hely"))
        birth_place = rx(t2, r"születési hely \(település\):\s*(.*?)\s+ország:")
        birth_country = rx(t2, r"ország:\s*(.*?)\s+állampolgársága:")
        nationality = rx(t2, r"állampolgársága:\s*(.*?)\s+nemzetisége") or rx(agreement_text, r"Állampolgársága:\s*(.*?)(?:\n|mint|\()")

        passport_no = rx(t2, r"útlevél száma:\s*(.*?)\s+kiállításának ideje") or rx(agreement_text, r"(?:Útlevél száma|Passport number|útlevélszáma):\s*([A-Z0-9]+)")
        issue_raw = rx(t2, r"kiállításának ideje, helye:\s*(.*?)\s+útlevél típusa")
        pass_issued = parse_date(issue_raw)
        pass_place = ""
        # The PDF label is inconsistent in practice: some PDFs use date, place; others use place, date.
        m_date_first = re.search(r"^(\d{4}[.\-/]\d{1,2}[.\-/]\d{1,2})\.?,?\s*(.*)$", issue_raw)
        m_date_last = re.search(r"^(.*?),?\s*(\d{4}[.\-/]\d{1,2}[.\-/]\d{1,2})\.?$", issue_raw)
        if m_date_first:
            pass_place = one_line(m_date_first.group(2)).strip(" ,.")
        elif m_date_last:
            pass_place = one_line(m_date_last.group(1)).strip(" ,.")
        pass_valid = parse_date(rx(t2, r"érvényességi ideje:\s*(.*?)\s+3\. A kérelmező"))
        passport_type = ""
        if p_main2 >= 0:
            passport_type = checked_option_by_label(doc[p_main2], ["magánútlevél", "szolgálati", "diplomata", "egyéb"])
        if norm(passport_type).startswith("magan"):
            passport_type = "Magán"

        # Hungarian accommodation
        hu_zip = rx(t2, r"irányítószám:\s*(\d{4})")
        hu_city = rx(t2, r"település:\s*(.*?)\s+közterület neve:")
        hu_street = rx(t2, r"közterület neve:\s*(.*?)\s+közterület jellege:")
        hu_stype = rx(t2, r"közterület jellege:\s*(.*?)\s+házszám:")
        hu_house = rx(t2, r"házszám:\s*([^\n]+?)\s+épület:")
        hu_title_extra = rx(t2, r"egyéb:\s*(.*?)\s*4\. Teljes körű")
        hu_title = ""
        if p_main2 >= 0:
            hu_title = checked_option_by_label(doc[p_main2], ["tulajdonos", "bérlő", "családtag", "szívességi lakáshasználó", "egyéb"], max_dx=55)
        hu_title = option_accommodation_title(hu_title)
        # Ha tényleg az Egyéb van jelölve, akkor kell az éspedig mező.
        # A mintákban gyakori, hogy a 'bérlő' van X-elve, alatta pedig magyarázó szöveg szerepel;
        # ezt nem szabad automatikusan Egyébként feltölteni.
        if norm(hu_title) != "egyeb":
            hu_title_extra = ""

        # foreign address
        foreign_country = rx(t3, r"Ország:\s*(.*?)\s+Település:")
        foreign_city = rx(t3, r"Település:\s*(.*?)\s+Közterület neve:")
        foreign_street = rx(t3, r"Közterület neve:\s*(.*?)\s+Rendelkezik-e")

        # status/education
        marital = ""
        if p_main2 >= 0:
            marital = checked_option_by_label(doc[p_main2], ["nőtlen/hajadon", "özvegy", "házas", "elvált"], max_dx=55)
        marital_map = {"notlen/hajadon": "Nőtlen/hajadon", "hazas": "Házas", "ozvegy": "Özvegy", "elvalt": "Elvált"}
        marital = marital_map.get(norm(marital), marital)

        education = ""
        if p_main2 >= 0:
            education = checked_option_by_label(doc[p_main2], ["alapfokú", "középfokú", "felsőfokú"], max_dx=50)
        education = {"alapfoku": "Alapfokú", "kozepfoku": "Középfokú", "felsofoku": "Felsőfokú"}.get(norm(education), education)

        school_type = ""
        if p_annex >= 0:
            for ix in range(p_annex, min(len(texts), p_annex + 3)):
                if "Iskolai végzettsége" in texts[ix]:
                    school_type = checked_option_by_label(
                        doc[ix],
                        ["általános", "szakiskola", "szakmunkásképző", "gimnázium", "szakközépiskola", "technikum", "főiskola", "egyetem", "8 általánosnál kevesebb"],
                        max_dx=55,
                    )
                    if school_type:
                        break
        school_type = option_title_case_school(school_type)

        qualification = first_nonempty(
            rx(t2, r"szakképzettsége:\s*(.*?)\s+iskolai végzettsége:"),
            rx(annex_text, r"(?:3|5)\. Munkakör betöltéséhez szükséges\s+szakképzettsége:\s*(.*?)\s+(?:4|6)\. Iskolai"),
        )
        previous_job = first_nonempty(
            rx(t2, r"Magyarországra érkezést\s+megelőző foglalkozás:\s*(.*?)\s+2\. A kérelmező"),
            rx(annex_text, r"(?:5|7)\. Magyarországra érkezést\s+megelőző\s+foglalkozása:\s*(.*?)\s+(?:6|8)\. Munkavégzés"),
        )
        language = rx(annex_text, r"Anyanyelve:\s*(.*?)\s+Egyéb nyelvismerete")
        if not language:
            language = "ukrán" if norm(nationality).startswith("ukran") else ("angol" if norm(nationality).startswith("fulop") else "")

        # Dates and purpose
        application_until = parse_date(rx(full, r"Meddig kérelmezi tartózkodása engedélyezését\?\s*(.*?)\s+Kijelentem"))
        kelt = parse_date(rx(full, r"Kelt:\s*[^,\n]+,\s*(\d{4}[.\-/]\d{1,2}[.\-/]\d{1,2})"))
        if not kelt:
            kelt = parse_date(rx(full, r"Kelt/Date:\s*[^,\n]+,\s*(\d{4}[.\-/]\d{1,2}[.\-/]\d{1,2})"))
        agreement_date = parse_date(rx(annex_text, r"Foglalkoztatóval kötött előzetes megállapodás kelte:\s*(.*?)\s+(?:8|10)\. Munkakör")) or kelt

        # Annex values
        salary = fmt_money(rx(annex_text, r"munkaviszonyból származó várható jövedelem összege:\s*(.*?)\s+előző évi"))
        employer_name = rx(annex_text, r"2\. Magyarországi munkáltató adatai\s+név:\s*(.*?)\s+székhely címe")
        company_code = "HRD" if "HR DIREKT" in employer_name.upper() else "HDD"
        employer_short = "HR Direkt Kft." if company_code == "HRD" else "HD Direkt Hungary Kft."
        tax_no = rx(annex_text, r"Munkáltató adószáma /adóazonosító jele:\s*(.*?)\s+KSH-szám:")
        ksh = rx(annex_text, r"KSH-szám:\s*(.*?)\s+TEÁOR száma:")
        teaor = rx(annex_text, r"TEÁOR száma:\s*(.*?)(?:\s+3\.|\n3\.|\s+Munkakör|$)")
        reg_date = parse_hu_date_words(rx(annex_text, r"Nyilvántartásba vétel napja:\s*(.*?),\s*Nyilvántartási szám:"))
        reg_no = rx(annex_text, r"Nyilvántartási szám:\s*(.*?)\s+(?:5\. Munkakör|TÁJÉKOZTATÓ|$)")

        feor = rx(annex_text, r"(?:8|10)\. Munkakör \(FEOR szám\):\s*(\d{3,4})")
        feor_name = ""
        m = re.search(r"6\. A harmadik országbeli állampolgár által.*?megnevezése:\s*/?\s*(\d{3,4})\s*[-–]\s*(.*?)(?:\s+6,|\s+7\.|\n7\.|/)", agreement_text, re.I | re.S)
        if m:
            feor_name = one_line(m.group(2)).strip(" ./")
        elif feor == "9310":
            feor_name = "Egyszerű ipari foglalkozású"

        work_addr = ""
        # 1 munkahely: címe(i). Capture the whole line because some locations are HRSZ-based.
        work_addr = rx(annex_text, r"címe\(i\):\s*(\d{4}[^\n]+?)(?:\s+A munka természetéből|\s+7\.|\s+9\.|\n)")
        # több vármegye esetén: kezdés helye
        if not work_addr:
            work_addr = rx(annex_text, r"munkavégzés megkezdésének\s+helye \(címe\):\s*(\d{4}[^\n]+?)(?:\s+A foglalkoztató|\s+7\.|\n)")
        if not work_addr:
            work_addr = rx(agreement_text, r"9\. A munkavégzés helye\(i\):\s*(\d{4}[^\n]+?)(?:\s+9,|\s+10\.|\n)")
        wz, wc, ws, wt, wh = split_hu_address(work_addr)
        if norm(wt) == "kultelek" and re.search(r"\bHRSZ\b", work_addr, re.I):
            warnings.append("Munkahely HRSZ-formátumú cím: BX=Kültelek, BY=helyrajzi szám. Ellenőrizd az EH feltöltés után.")
        wt = option_work_street_type(wt)

        # 242 + 445 logic
        # DB: 242 section answer. DE/DF: user-requested point columns in the new 2026-05-19 workbook.
        # Vendégmunkás: DE = 1, DF = üres. Nemzeti Kártya: DE = üres, DF = 36.
        # DB a feltöltő mintája alapján numerikus checkbox/radio érték: 1 = jelölt/igen.
        db_242_answer = "1" if re.search(r"242\.\s*§\s*\(7\).*?bekezdés\s*[13]\.\s*pontja", full1, re.I) else ""
        de_242_point = "1" if form_type == "VENDEGMUNKAS" else ""
        df_445_point = "36" if form_type == "NEMZETI" else ""
        if form_type == "ISMERETLEN":
            warnings.append("A PDF típusa nem volt egyértelmű: nem 9.7 vendégmunkás és nem 9.12 nemzeti kártya.")

        full_name = one_line(f"{family} {given}")
        return_country_choice = "az állampolgárságom szerinti állam"

        data.update({
            "A": kelt,
            "B": company_code,
            "C": full_name,
            "D": family,
            "E": given,
            "F": birth_family or family,
            "G": gender,
            "H": birth_place,
            "I": birth_country,
            "J": birth_date,
            "K": nationality,
            "L": mother_family,
            "M": mother_given,
            "N": passport_no,
            "O": "",
            "P": foreign_country,
            "Q": foreign_city,
            "R": foreign_street,
            "S": "", "T": "", "U": "", "V": "", "W": "",
            "X": marital,
            "Y": education,
            "Z": school_type,
            "AA": qualification,
            "AB": "Nem",  # fix: dolgozott-e Magyarországon
            "AC": previous_job,
            "AD": language,
            "AE": hu_zip,
            "AF": hu_city,
            "AG": hu_street,
            "AH": hu_stype,
            "AI": hu_house,
            "AJ": "", "AK": "", "AL": "", "AM": "",
            "AN": "",
            "AO": hu_title,
            "AP": hu_title_extra,
            "AQ": application_until if form_type == "NEMZETI" else "Határozatlan ideig",
            "AR": "Foglalkoztatási Jogviszony Alapján",
            "AS": "",
            "AT": "", "AU": "",
            "AV": passport_type,
            "AW": pass_place,
            "AX": pass_issued,
            "AY": pass_valid,
            "AZ": agreement_date,
            "BA": feor,
            "BB": feor_name,
            "BC": "",
            "BD": foreign_country or birth_country,
            "BE": "",
            "BF": application_until,
            "BG": employer_short,
            "BH": teaor,
            "BI": ksh,
            "BJ": tax_no,
            "BK": "01 09 931447" if company_code == "HDD" else "01 09 182281",
            "BL": "Kft.",
            "BM": "1087" if company_code == "HDD" else "1095",
            "BN": "Baross" if company_code == "HDD" else "Soroksári",
            "BO": "tér" if company_code == "HDD" else "út",
            "BP": "Tér" if company_code == "HDD" else "Út",
            "BQ": "1" if company_code == "HDD" else "48-54",
            "BR": "",
            "BS": "03" if company_code == "HDD" else "",
            "BT": "14" if company_code == "HDD" else "",
            "BU": wz,
            "BV": wc,
            "BW": ws,
            "BX": wt,
            "BY": wh,
            "BZ": "", "CA": "", "CB": "", "CC": "", "CD": "", "CE": "", "CF": "", "CG": "", "CH": "",
            "CI": "", "CJ": "", "CK": "", "CL": "", "CM": "", "CN": "",
            "CO": "Posta",
            "CP": rx(t1, r"E-mail cím:\s*(\S+@\S+)") or "hatosag@hddirekt.com",
            "CQ": re.sub(r"[^+0-9]", "", rx(t1, r"Telefonszám:\s*([^\s]+(?:[- ]?\d+)*)") or "+36309560634"),
            "CR": "foglalkoztató",  # fix: benyújtó
            "CS": "",
            "CT": salary,
            "CU": "Forint",
            "CV": return_country_choice,
            "CW": "",
            "CX": rx(t2, r"helyrajzi szám:\s*(.*?)\s+irányítószám:"),
            "CY": "minősített munkaerő kölcsönző",
            "CZ": reg_date,
            "DA": reg_no,
            "DB": db_242_answer,
            "DC": "",
            "DD": "",
            "DE": de_242_point,
            "DF": df_445_point,
            "DG": "",
            "DH": "",
        })

        required = ["C", "D", "E", "J", "N"]
        missing = [c for c in required if not data.get(c)]
        if missing:
            warnings.append("Hiányzó kötelező mezők: " + ", ".join(missing))
        if not feor:
            warnings.append("FEOR nem olvasható biztosan.")
        if not salary:
            warnings.append("Várható jövedelem nem olvasható biztosan.")
        if not work_addr:
            warnings.append("Munkavégzés helye nem olvasható biztosan.")

    return data, warnings


def write_tsv(path: Path, headers: List[str], rows: List[Dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=headers, dialect="excel-tab", extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def process(input_list: Path, out_data: Path, out_log: Path) -> int:
    pdf_paths = [Path(line.strip().strip('"')) for line in input_list.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
    rows: List[Dict[str, str]] = []
    logs: List[Dict[str, str]] = []
    for pdf in pdf_paths:
        log = {
            "Időpont": datetime.now().strftime("%Y.%m.%d %H:%M:%S"),
            "PDF fájl": pdf.name,
            "Állapot": "",
            "Név": "",
            "Útlevél": "",
            "Üzenet": "",
        }
        try:
            data, warnings = extract_pdf(pdf)
            data["__PDF_PATH__"] = str(pdf)
            data["__PDF_NAME__"] = pdf.name
            data["__STATUS__"] = "OK"
            data["__WARNINGS__"] = " | ".join(warnings)
            rows.append(data)
            log["Állapot"] = "OK - FIGYELMEZTETÉS" if warnings else "OK"
            log["Név"] = data.get("C", "")
            log["Útlevél"] = data.get("N", "")
            log["Üzenet"] = data.get("__WARNINGS__", "")
        except Exception as exc:
            log["Állapot"] = "HIBA"
            log["Üzenet"] = f"{type(exc).__name__}: {exc}\n{traceback.format_exc()}"
        logs.append(log)

    data_headers = ["__PDF_PATH__", "__PDF_NAME__", "__STATUS__", "__WARNINGS__"] + LETTERS
    log_headers = ["Időpont", "PDF fájl", "Állapot", "Név", "Útlevél", "Üzenet"]
    write_tsv(out_data, data_headers, rows)
    write_tsv(out_log, log_headers, logs)
    return 0 if all(l["Állapot"] != "HIBA" for l in logs) else 1


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-list", required=True)
    parser.add_argument("--out-data", required=True)
    parser.add_argument("--out-log", required=True)
    args = parser.parse_args(argv)
    return process(Path(args.input_list), Path(args.out_data), Path(args.out_log))


if __name__ == "__main__":
    sys.exit(main())
