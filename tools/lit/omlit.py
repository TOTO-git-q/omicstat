"""omlit -- omicstat S0 literature layer (ENGINEERING_PLAN 2.1-2.2, L3/L4).

Structure borrowed from reference/medstat-reference (discovery.py: whitelist gate,
section-level Europe PMC query, Methods-region signal, licence rule); the HTTP
work goes through the vendored Claude Science clients (read-only import):
  europepmc_fulltext.EuropePMCClient   search + fullTextXML
  pubmed_fetch.PubMedFetcher           PMID efetch echo
Python here is retrieval and text screening only -- never an analysis engine.

Persistence rule (2.2 step 3): full text is parsed in memory and discarded; only
<= 25-word snippets, section paths, detected parameter values and the sha256 of
the JATS bytes are stored. PubMed efetch records (public bibliographic metadata)
are archived as the proof of the PMID echo.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
VENDOR_LIB = ROOT / "vendor" / "claude_science" / "bio_tools" / "lib"
if str(VENDOR_LIB) not in sys.path:
    sys.path.insert(0, str(VENDOR_LIB))

from lxml import etree  # noqa: E402  (vendored requirement)

SNIPPET_MAX_WORDS = 25
CONTACT = os.environ.get("OMICSTAT_CONTACT_EMAIL", "omicstat-s0@example.invalid")
ISSN_RE = re.compile(r"^\d{4}-\d{3}[\dX]$")
HERE = Path(__file__).resolve().parent


class LitError(RuntimeError):
    pass


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def _norm_title(t: str) -> str:
    import html
    t = re.sub(r"<[^>]+>", " ", html.unescape(html.unescape(t or "")))
    return re.sub(r"[^a-z0-9]+", "", t.lower())


# ------------------------------------------------------------------ journals

def load_journals(path: str | Path | None = None) -> dict[str, Any]:
    doc = json.loads(Path(path or HERE / "journals.json").read_text(encoding="utf-8"))
    by_issn: dict[str, Any] = {}
    for j in doc["journals"]:
        for i in j["issn"]:
            if not ISSN_RE.match(i):
                raise LitError(f"bad ISSN {i} for {j['name']}")
            by_issn[i] = j
    doc["by_issn"] = by_issn
    return doc


def journal_clause(journals: Mapping[str, Any], tiers: Iterable[str] = ("A", "B")) -> str:
    issns = sorted({i for j in journals["journals"] if j["tier"] in set(tiers) for i in j["issn"]})
    return "(" + " OR ".join(f'ISSN:"{i}"' for i in issns) + ")"


def result_issns(result: Mapping[str, Any]) -> list[str]:
    found: list[str] = []
    info = result.get("journalInfo") or {}
    journal = info.get("journal") or {}
    for v in (journal.get("issn"), journal.get("essn")):
        if isinstance(v, str):
            found.append(v.strip().upper())
    if isinstance(result.get("journalIssn"), str):
        found.extend(x.strip().upper() for x in result["journalIssn"].split(";") if x.strip())
    return [x for x in dict.fromkeys(found) if ISSN_RE.match(x)]


# ------------------------------------------------------------------ profiles

def load_profiles(path: str | Path | None = None) -> dict[str, Any]:
    doc = json.loads(Path(path or HERE / "discovery_profiles.json").read_text(encoding="utf-8"))
    out = {}
    for p in doc["profiles"]:
        comp = {"signal": re.compile(p["signal_regex"], re.I)}
        if p.get("require_regex"):
            comp["require"] = re.compile(p["require_regex"], re.I)
        if p.get("exclude_regex"):
            comp["exclude"] = re.compile(p["exclude_regex"])
        comp["variants"] = {v["parameter"]: [re.compile(rx, re.I) for rx in v["regex"]] for v in p.get("parameters", [])}
        out[p["module"]] = dict(p, compiled=comp)
    doc["by_module"] = out
    return doc


def build_query(profile: Mapping[str, Any], cfg: Mapping[str, Any], journals: Mapping[str, Any], today: dt.date) -> str:
    filt = cfg["common_filter"].replace("{today}", today.isoformat()).replace("{min_year}", str(cfg["min_year"]))
    return " AND ".join(["(" + profile["epmc_query"] + ")", filt, journal_clause(journals)])


# ------------------------------------------------------------------ Europe PMC

def epmc_client():
    from europepmc_fulltext import EuropePMCClient
    return EuropePMCClient(max_retries=3)


def epmc_search_all(client, query: str, max_records: int = 1000, page_size: int = 100) -> dict[str, Any]:
    """All pages of /search (cursorMark), through the vendored client's throttled GET."""
    results: list[dict] = []
    cursor = "*"
    hit_count = None
    while len(results) < max_records:
        resp = client._get(f"{client.base_url}/search", params={
            "query": query, "format": "json", "resultType": "core", "pageSize": page_size, "cursorMark": cursor})
        resp.raise_for_status()
        doc = resp.json()
        hit_count = doc.get("hitCount", hit_count)
        page = (doc.get("resultList") or {}).get("result") or []
        results.extend(page)
        nxt = doc.get("nextCursorMark")
        if not page or not nxt or nxt == cursor:
            break
        cursor = nxt
    return {"hit_count": hit_count, "results": results[:max_records]}


def pub_types(result: Mapping[str, Any]) -> list[str]:
    ptl = result.get("pubTypeList") or {}
    vals = ptl.get("pubType", []) if isinstance(ptl, Mapping) else []
    if isinstance(vals, str):
        vals = [vals]
    return [str(x).strip().lower() for x in vals]


def screen_metadata(result: Mapping[str, Any], profile: Mapping[str, Any], journals: Mapping[str, Any],
                    cfg: Mapping[str, Any], today: dt.date) -> tuple[str, dict[str, Any]]:
    issns = result_issns(result)
    match = next((journals["by_issn"][i] for i in issns if i in journals["by_issn"]), None)
    if match is None:
        return "off_whitelist", {"issns": issns}
    info = {"journal": match["name"], "tier": match["tier"]}
    title = str(result.get("title") or "")
    types = pub_types(result)
    if not title:
        return "invalid_metadata", info
    if any("retract" in t for t in types) or str(result.get("hasRetractedFlag") or "").upper() == "Y" or re.match(r"^\s*retract", title, re.I):
        return "retracted", info
    if any(t in {"review", "review-article", "systematic review", "meta-analysis", "preprint"} for t in types):
        return "pubtype_excluded", info
    try:
        year = int(str(result.get("pubYear"))[:4])
    except ValueError:
        return "invalid_metadata", info
    info["year"] = year
    if year < cfg["min_year"] or year > today.year:
        return "year_out_of_range", info
    ex = profile["compiled"].get("exclude")
    if ex is not None and ex.search(title + " " + re.sub(r"<[^>]+>", " ", str(result.get("abstractText") or ""))):
        return "excluded_by_regex", info
    return "pass", info


# ------------------------------------------------------------------ JATS

METHOD_ROOT = re.compile(r"\b(method|methods|materials? and methods|experimental procedures|methods? details|online methods|star\s*\*?\s*methods|experimental model|quantification and statistical analysis|statistical analys[ie]s|data analysis|bioinformatic)", re.I)
NON_METHOD = re.compile(r"^\s*(introduction|background|results?|discussion|conclusions?|abstract|acknowledg|references|funding|author contributions?|competing interests?|supplementary)\b", re.I)
_SKIP = {"sec", "title", "label", "table-wrap", "fig", "table-wrap-group", "fig-group", "supplementary-material"}


def _local(tag: Any) -> str:
    return str(tag).rsplit("}", 1)[-1]


def _clean(el) -> str:
    return "" if el is None else re.sub(r"\s+", " ", "".join(el.itertext())).strip()


def method_regions(body) -> list[dict[str, Any]]:
    """Methods subtrees only (Introduction / Results / Discussion are never searched)."""
    regions: list[dict[str, Any]] = []

    def walk(sec, path, inside):
        heading = _clean(sec.find("./title"))
        st = (sec.get("sec-type") or "").lower()
        here = path + [heading or "(untitled)"]
        if not inside:
            if NON_METHOD.search(heading) or any(x in st for x in ("intro", "result", "discussion", "conclusion")):
                return
            inside = bool(METHOD_ROOT.search(heading)) or "method" in st
        if inside:
            text = " ".join(_clean(c) for c in sec if _local(c.tag) not in _SKIP and _clean(c))
            if text:
                regions.append({"section_id": sec.get("id"), "section_path": " > ".join(here)[:300], "text": text})
        for child in sec.findall("./sec"):
            walk(child, here, inside)

    for top in body.findall("./sec"):
        walk(top, [], False)
    return regions


def snippet_around(text: str, start: int, max_words: int = SNIPPET_MAX_WORDS) -> str:
    before = text[:start].split()[-8:]
    after = text[start:].split()[: max(1, max_words - len(before))]
    return " ".join(before + after)


NEGATION = re.compile(r"\b(?:not|no|never|without|neither|nor)\b|n't\b", re.I)


def _negated(text: str, s: int, e: int) -> bool:
    return bool(NEGATION.search(text[max(0, s - 40):s]) or NEGATION.search(text[e:e + 25]))


def signal_hit(regions, profile) -> dict[str, Any] | None:
    comp = profile["compiled"]
    req = comp.get("require")
    if req is not None and not any(req.search(r["text"]) for r in regions):
        return None
    for r in regions:
        m = next((m for m in comp["signal"].finditer(r["text"]) if not _negated(r["text"], m.start(), m.end())), None)
        if m:
            q = snippet_around(r["text"], m.start())
            return {"snippet": q, "matched": m.group(0)[:120], "section_path": r["section_path"], "section_id": r["section_id"]}
    return None


def extract_variants(regions, profile) -> dict[str, list[dict[str, Any]]]:
    """Every parameter pattern found in the Methods regions: value (named group
    'value' when present, else the match) + a <= 25-word snippet + section path.
    These are CANDIDATES: a human reads the snippets before counting (PACK V)."""
    out: dict[str, list[dict[str, Any]]] = {}
    for param, rxs in profile["compiled"]["variants"].items():
        seen = set()
        for r in regions:
            for rx in rxs:
                for m in rx.finditer(r["text"]):
                    if _negated(r["text"], m.start(), m.end()):
                        continue
                    val = (m.groupdict().get("value") or m.group(0)).strip()
                    key = (val.lower(), r["section_path"])
                    if key in seen:
                        continue
                    seen.add(key)
                    out.setdefault(param, []).append({"value": val[:80], "snippet": snippet_around(r["text"], m.start()),
                                                      "section_path": r["section_path"]})
    return out


# ------------------------------------------------------------------ licence (medstat R1 rule)

COUNTABLE = frozenset({"cc-by", "cc-by-nc", "cc0"})
RANK = {"cc0": 0, "cc-by": 1, "cc-by-nc": 2, "cc-by-sa": 3, "cc-by-nc-sa": 4, "cc-by-nd": 5, "cc-by-nc-nd": 6, "other": 7}
_CC_URL = re.compile(r"creativecommons\.org/(?:licenses/([a-z][a-z\-]*)/?|publicdomain/(zero|mark)\b)", re.I)
_CC_TOKEN = re.compile(r"\bCC[- ]?BY((?:[- ](?:NC|ND|SA))*)(?![A-Za-z])", re.I)
_CC_WORDS = re.compile(r"Creative Commons Attribution((?:[- ](?:Non-?Commercial|No-?Derivatives|No-?Derivs|Share-?Alike))*)", re.I)
TDM_PROHIBITED = re.compile(
    r"\b(?:not|no|prohibit\w*|forbid\w*)\b[^.]{0,120}\b(?:text (?:and|&) data mining|text[- ]mining|data mining|TDM|AI training)\b"
    r"|\b(?:text (?:and|&) data mining|text[- ]mining|TDM)\b[^.]{0,60}\b(?:not (?:permitted|allowed)|prohibited|forbidden)", re.I)


def _parts(t: str) -> set[str]:
    t = t.lower().replace("non-commercial", "nc").replace("noncommercial", "nc")
    t = re.sub(r"no-?deriv(?:ative)?s", "nd", t).replace("share-alike", "sa").replace("sharealike", "sa")
    return {p for p in re.split(r"[- ]+", t) if p in {"nc", "nd", "sa"}}


def _code(parts: set[str]) -> str:
    c = "cc-by" + ("-nc" if "nc" in parts else "")
    return c + ("-nd" if "nd" in parts else "-sa" if "sa" in parts else "")


def classify_rights(text: str, links: Iterable[str]) -> dict[str, Any]:
    codes: set[str] = set()
    for src in [text, *links]:
        for m in _CC_URL.finditer(src or ""):
            if m.group(2):
                codes.add("cc0" if m.group(2).lower() == "zero" else "other")
            else:
                raw = m.group(1).lower().strip("-")
                codes.add("cc-" + raw if ("cc-" + raw) in RANK else "other")
    if not codes:
        for m in _CC_TOKEN.finditer(text or ""):
            codes.add(_code(_parts(m.group(1) or "")))
        for m in _CC_WORDS.finditer(text or ""):
            codes.add(_code(_parts(m.group(1) or "")))
    lic = max(codes, key=RANK.get) if codes else "unknown"
    return {"licence": lic, "tdm_prohibited": bool(TDM_PROHIBITED.search(text or "")), "countable": lic in COUNTABLE and not TDM_PROHIBITED.search(text or "")}


def screen_fulltext(xml: bytes, profile) -> tuple[str, dict[str, Any]]:
    root = etree.fromstring(xml)
    art = root if _local(root.tag) == "article" else root.find(".//article")
    if art is None:
        return "no_article", {}
    body = art.find("./body")
    if body is None or not _clean(body):
        return "headers_only_fulltext", {}
    perm = art.find("./front/article-meta/permissions")
    links = [] if perm is None else [v for e in perm.iter() for k, v in e.attrib.items() if _local(k).endswith("href")]
    rights = classify_rights(_clean(perm), links)
    regions = method_regions(body)
    if not regions:
        return "no_methods_section", {"rights": rights}
    hit = signal_hit(regions, profile)
    if hit is None:
        return "no_methods_signal", {"rights": rights, "n_method_regions": len(regions)}
    return "screened", {"rights": rights, "signal": hit, "variants": extract_variants(regions, profile),
                        "n_method_regions": len(regions), "method_chars": sum(len(r["text"]) for r in regions)}


# ------------------------------------------------------------------ PubMed echo

def efetch_echo(pmids: list[str], expected: Mapping[str, Mapping[str, Any]], archive_dir: Path) -> dict[str, dict[str, Any]]:
    """efetch every PMID; the record passes when the PubMed title matches the
    Europe PMC title and the journal ISSN / year agree. Raw XML is archived."""
    from pubmed_fetch import PubMedFetcher
    f = PubMedFetcher(email=CONTACT, tool="omicstat-s0")
    xml = f.fetch_xml(pmids, strict=False)
    recs = {r.get("pmid"): r for r in f.fetch_records(pmids, strict=False)}
    archive_dir.mkdir(parents=True, exist_ok=True)
    out = {}
    for p in pmids:
        x = xml.get(p)
        if x:
            (archive_dir / f"{p}.xml").write_text(x if isinstance(x, str) else x.decode("utf-8"), encoding="utf-8")
        r = recs.get(p) or {}
        exp = expected.get(p, {})
        title_ok = bool(r) and _norm_title(r.get("title", ""))[:120] == _norm_title(exp.get("title", ""))[:120]
        year = str(r.get("year") or r.get("pub_year") or (r.get("pub_date") or {}).get("year") or "")[:4]
        year_ok = year == str(exp.get("year", ""))[:4] or not year
        out[p] = {"echoed": bool(r), "title_match": title_ok, "year_match": year_ok,
                  "pubmed_title": (r.get("title") or "")[:200], "pubmed_journal": str(r.get("journal") or r.get("journal_title") or "")[:120],
                  "pubmed_year": year, "xml_sha256": sha256_bytes((x if isinstance(x, bytes) else (x or "").encode())) if x else None,
                  "verified": bool(r) and title_ok}
    return out
