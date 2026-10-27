"""v2 discovery configuration and pure screening gates.

"The journal list is the gate; the topic only ranks."  Nothing in this module
performs network I/O: it loads the verified whitelist and the per-module
profiles, builds bounded Europe PMC queries, and decides whether one search
result / one JATS article passes each gate.  Article text is evidence data and
never an instruction; only a <=25-word snippet and a hash ever leave here.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any, Iterable, Mapping

ROOT = Path(__file__).resolve().parent
JOURNALS_SCHEMA = "omicstat.reference.journals.v1"
PROFILES_SCHEMA = "omicstat.reference.discovery-profiles.v1"
MIN_YEAR = 2018
SNIPPET_MAX_WORDS = 25
TIERS = ("A", "B", "M")
TIER_RANK = {"A": 0, "B": 1, "M": 2}
ISSN_RE = re.compile(r"^\d{4}-\d{3}[\dX]$")
MODULE_RE = re.compile(r"^[a-z0-9][a-z0-9:-]{0,79}$")
# Headings that open a Methods region (the whole subtree is taken) ...
METHOD_ROOT = re.compile(r"\b(?:methods?|methodology|materials?|statistic(?:s|al)|analys[ie]s|analytic(?:al)?|study design|design and setting|participants|data sources?|patients)\b", re.I)
# ... and headings whose subtree is never Methods evidence.
NON_METHOD = re.compile(r"\b(?:results?|findings|discussion|introduction|background|conclusions?|limitations|acknowledg|references?|supplementary|appendix|abbreviations|funding|declarations?|contributions?|conflicts?)\b", re.I)
NON_METHOD_SECTYPES = ("result", "discussion", "intro", "conclusion", "supplementary", "display-objects", "ack")


class DiscoveryError(RuntimeError):
    """Configuration or screening error with a stable code."""
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code, self.message = code, message


def _sha(obj: Any) -> str:
    return hashlib.sha256(json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()


def load_journals(path: str | Path | None = None) -> dict[str, Any]:
    """Load and validate the ISSN whitelist; every entry must carry its verification."""
    path = Path(path) if path is not None else ROOT / "journals.json"
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise DiscoveryError("invalid_journals", "journals.json must be readable UTF-8 JSON") from exc
    if not isinstance(raw, Mapping) or raw.get("schema") != JOURNALS_SCHEMA or not isinstance(raw.get("journals"), list) or not raw["journals"]:
        raise DiscoveryError("invalid_journals", "journals.json schema is not supported")
    by_issn: dict[str, dict[str, Any]] = {}
    for item in raw["journals"]:
        if not isinstance(item, Mapping):
            raise DiscoveryError("invalid_journals", "journal entries must be objects")
        name, issns, tier = item.get("name"), item.get("issn"), item.get("tier")
        if not isinstance(name, str) or not name.strip() or tier not in TIERS:
            raise DiscoveryError("invalid_journals", "journal needs name and tier A/B/M")
        if not isinstance(issns, list) or not issns or not all(isinstance(x, str) and ISSN_RE.match(x) for x in issns):
            raise DiscoveryError("invalid_journals", f"journal {name!r} has malformed ISSN list")
        if not isinstance(item.get("verified_on"), str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", item["verified_on"]) or not isinstance(item.get("verified_via"), str) or not item["verified_via"].strip():
            raise DiscoveryError("invalid_journals", f"journal {name!r} lacks verified_on/verified_via")
        secondary = item.get("secondary_tier")
        if secondary is not None and secondary not in TIERS:
            raise DiscoveryError("invalid_journals", f"journal {name!r} has invalid secondary_tier")
        entry = {"name": name, "tier": tier, "secondary_tier": secondary, "nlm_abbreviation": item.get("nlm_abbreviation")}
        for issn in issns:
            if issn in by_issn and by_issn[issn]["name"] != name:
                raise DiscoveryError("invalid_journals", f"ISSN {issn} is assigned to two journals")
            by_issn[issn] = entry
    return {"journals": list(raw["journals"]), "by_issn": by_issn, "issns": sorted(by_issn), "hash": _sha(raw)}


def journal_clause(journals: Mapping[str, Any]) -> str:
    return "(" + " OR ".join('ISSN:"%s"' % issn for issn in journals["issns"]) + ")"


def _compile(pattern: Any, field: str, module: str) -> re.Pattern[str]:
    if not isinstance(pattern, str) or not pattern.strip() or len(pattern) > 2000:
        raise DiscoveryError("invalid_profiles", f"{module}: {field} must be a nonempty pattern")
    try:
        return re.compile(pattern, re.I)
    except re.error as exc:
        raise DiscoveryError("invalid_profiles", f"{module}: {field} does not compile") from exc


def validate_profile(item: Mapping[str, Any]) -> dict[str, Any]:
    """Validate one profile object (also used for curator-supplied domain profiles)."""
    if not isinstance(item, Mapping):
        raise DiscoveryError("invalid_profiles", "profile must be an object")
    module = item.get("module")
    if not isinstance(module, str) or not MODULE_RE.match(module):
        raise DiscoveryError("invalid_profiles", "profile module is malformed")
    query = item.get("epmc_query")
    if not isinstance(query, str) or not query.strip() or len(query) > 3000 or "METHODS:" not in query:
        raise DiscoveryError("invalid_profiles", f"{module}: epmc_query must be a bounded METHODS: section query")
    if query.count("(") != query.count(")") or query.count('"') % 2:
        raise DiscoveryError("invalid_profiles", f"{module}: epmc_query has unbalanced syntax")
    status = item.get("profile_status", "ok")
    if status not in {"ok", "weak"}:
        raise DiscoveryError("invalid_profiles", f"{module}: profile_status must be ok or weak")
    compiled = {"signal": _compile(item.get("signal_regex"), "signal_regex", module),
                "require": _compile(item["signal_require_regex"], "signal_require_regex", module) if item.get("signal_require_regex") else None,
                "exclude": _compile(item["exclude_regex"], "exclude_regex", module) if item.get("exclude_regex") else None}
    return {"module": module, "epmc_query": query, "meta": bool(item.get("meta")), "profile_status": status,
            "signal_regex": item["signal_regex"], "signal_require_regex": item.get("signal_require_regex"),
            "exclude_regex": item.get("exclude_regex"), "compiled": compiled}


def load_profiles(path: str | Path | None = None) -> dict[str, Any]:
    path = Path(path) if path is not None else ROOT / "discovery_profiles.json"
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise DiscoveryError("invalid_profiles", "discovery_profiles.json must be readable UTF-8 JSON") from exc
    if not isinstance(raw, Mapping) or raw.get("schema") != PROFILES_SCHEMA or not isinstance(raw.get("profiles"), list):
        raise DiscoveryError("invalid_profiles", "discovery profile schema is not supported")
    filters = {}
    for key in ("common_filter", "meta_filter"):
        value = raw.get(key)
        if not isinstance(value, str) or "{today}" not in value or "HAS_FT:Y" not in value or "OPEN_ACCESS:Y" not in value:
            raise DiscoveryError("invalid_profiles", f"{key} must include HAS_FT:Y, OPEN_ACCESS:Y and a {{today}} bound")
        filters[key] = value
    profiles: dict[str, dict[str, Any]] = {}
    for item in raw["profiles"]:
        profile = validate_profile(item)
        if profile["module"] in profiles:
            raise DiscoveryError("invalid_profiles", "profile modules must be unique")
        profiles[profile["module"]] = profile
    return {"profiles": profiles, "filters": filters, "hash": _sha(raw)}


def build_query(profile: Mapping[str, Any], config: Mapping[str, Any], journals: Mapping[str, Any], *,
                today: dt.date, keywords: Iterable[str] | None = None, keyword_mode: tuple[list[str], list[str]] | None = None) -> str:
    """Compose method gate AND (sanitized keywords) AND uniform filter AND journal whitelist.

    ``keyword_mode`` is (required_terms, any_terms): every required term must
    appear, and at least one of the optional terms.  Terms are already cleaned
    to [a-z0-9 -] and are always quoted, so they cannot introduce syntax.
    """
    filt = config["filters"]["meta_filter" if profile.get("meta") else "common_filter"].replace("{today}", today.isoformat())
    parts = ["(" + profile["epmc_query"] + ")"]
    if keyword_mode is not None:
        required, optional = keyword_mode
        for term in required:
            parts.append('"%s"' % term)
        if optional:
            parts.append("(" + " OR ".join('"%s"' % t for t in optional) + ")")
    parts.append(filt)
    parts.append(journal_clause(journals))
    return " AND ".join(parts)


# ---------------------------------------------------------------- metadata gate

def result_issns(result: Mapping[str, Any]) -> list[str]:
    found: list[str] = []
    info = result.get("journalInfo") if isinstance(result.get("journalInfo"), Mapping) else {}
    journal = info.get("journal") if isinstance(info.get("journal"), Mapping) else {}
    for value in (journal.get("issn"), journal.get("essn")):
        if isinstance(value, str):
            found.append(value.strip().upper())
    if isinstance(result.get("journalIssn"), str):
        found.extend(x.strip().upper() for x in result["journalIssn"].split(";") if x.strip())
    return [x for x in dict.fromkeys(found) if ISSN_RE.match(x)]


def pub_types(result: Mapping[str, Any]) -> list[str]:
    ptl = result.get("pubTypeList")
    values = ptl.get("pubType", []) if isinstance(ptl, Mapping) else result.get("pubType", [])
    if isinstance(values, str):
        values = [values]
    return [str(x).strip().lower() for x in values if str(x).strip()]


def _year(value: Any) -> int | None:
    text = str(value or "")[:4]
    return int(text) if re.fullmatch(r"\d{4}", text) else None


def screen_metadata(result: Mapping[str, Any], profile: Mapping[str, Any], journals: Mapping[str, Any], *, today: dt.date) -> tuple[str, dict[str, Any]]:
    """Return (verdict, info).  verdict 'pass' or a stable gate name."""
    issns = result_issns(result)
    match = next((journals["by_issn"][i] for i in issns if i in journals["by_issn"]), None)
    if match is None:
        return "off_whitelist", {"issns": issns}
    info = {"journal_name": match["name"], "journal_tier": match["tier"], "journal_secondary_tier": match.get("secondary_tier"), "issns": issns}
    title = str(result.get("title") or "").strip()
    types = pub_types(result)
    if not title:
        return "invalid_metadata", info
    if any("retract" in t for t in types) or re.match(r"^\s*(?:retracted|retraction)\b", title, re.I) or str(result.get("hasRetractedFlag") or "").upper() == "Y":
        return "retracted", info
    if any("preprint" in t for t in types):
        return "pubtype_excluded", info
    is_review = any(t in {"review", "review-article"} for t in types)
    if profile.get("meta"):
        if is_review and not any(("meta-analysis" in t) or ("systematic review" in t) or t == "systematic-review" for t in types):
            return "pubtype_excluded", info
    elif is_review or any(t in {"systematic review", "systematic-review", "meta-analysis"} for t in types):
        return "pubtype_excluded", info
    year = _year(result.get("pubYear"))
    first = _year(result.get("firstPublicationDate"))
    info["year"] = year
    if year is None or year < MIN_YEAR or year > today.year or (first is not None and first > today.year):
        return "year_out_of_range", info
    abstract = str(result.get("abstractText") or "")
    exclude = profile["compiled"].get("exclude")
    if exclude is not None and exclude.search(title + " \n " + re.sub(r"<[^>]+>", " ", abstract)):
        return "excluded_by_regex", info
    return "pass", info


# ------------------------------------------------------------- full-text gate

def _clean_text(element: ET.Element | None) -> str:
    if element is None:
        return ""
    return re.sub(r"\s+", " ", "".join(element.itertext())).strip()


def _local(tag: Any) -> str:
    return str(tag).rsplit("}", 1)[-1]


def _direct_text(sec: ET.Element) -> str:
    """Prose that belongs to this section itself (not nested sections, tables or figures)."""
    chunks = []
    for child in sec:
        name = _local(child.tag)
        if name in {"sec", "title", "label", "table-wrap", "fig", "table-wrap-group", "fig-group", "supplementary-material"}:
            continue
        text = _clean_text(child)
        if text:
            chunks.append(text)
    return " ".join(chunks)


def method_regions(body: ET.Element) -> list[dict[str, Any]]:
    """Locate Methods subtrees; Introduction/Results/Discussion subtrees are never searched."""
    regions: list[dict[str, Any]] = []

    def walk(sec: ET.Element, path: list[str], inside: bool) -> None:
        heading = _clean_text(sec.find("./title"))
        sec_type = (sec.get("sec-type") or "").lower()
        here = path + [heading or "(untitled)"]
        if not inside:
            if NON_METHOD.search(heading) or any(x in sec_type for x in NON_METHOD_SECTYPES):
                return
            inside = bool(METHOD_ROOT.search(heading)) or "method" in sec_type
        if inside:
            text = _direct_text(sec)
            if text:
                regions.append({"section_id": sec.get("id"), "section_path": " > ".join(here), "text": text})
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


def _negated(text: str, start: int, end: int) -> bool:
    """A method named only to say it was NOT used ("survey weights were not applied") is no signal."""
    return bool(NEGATION.search(text[max(0, start - 40):start]) or NEGATION.search(text[end:end + 25]))


def signal_hit(regions: list[Mapping[str, Any]], profile: Mapping[str, Any]) -> dict[str, Any] | None:
    compiled = profile["compiled"]
    require = compiled.get("require")
    if require is not None and not any(require.search(r["text"]) for r in regions):
        return None
    for region in regions:
        match = next((m for m in compiled["signal"].finditer(region["text"])
                      if not _negated(region["text"], m.start(), m.end())), None)
        if match:
            quote = snippet_around(region["text"], match.start())
            return {"snippet": quote, "word_count": len(quote.split()), "matched": match.group(0)[:120],
                    "section_id": region.get("section_id"), "section_path": region["section_path"][:300]}
    return None


# ------------------------------------------------------------- licence (R1)

COUNTABLE_LICENCES = frozenset({"cc-by", "cc-by-nc", "cc0"})
LICENCE_RANK = {"cc0": 0, "cc-by": 1, "cc-by-nc": 2, "cc-by-sa": 3, "cc-by-nc-sa": 4, "cc-by-nd": 5, "cc-by-nc-nd": 6, "other": 7}
_CC_URL = re.compile(r"creativecommons\.org/(?:licenses/([a-z][a-z\-]*)/?|publicdomain/(zero|mark)\b)", re.I)
_CC_TOKEN = re.compile(r"\bCC[- ]?BY((?:[- ](?:NC|ND|SA))*)(?![A-Za-z])", re.I)
_CC_ZERO = re.compile(r"\bCC0\b|\bCC[- ]zero\b", re.I)
_CC_WORDS = re.compile(r"Creative Commons Attribution((?:[- ](?:Non-?Commercial|No-?Derivatives|No-?Derivs|Share-?Alike))*)", re.I)
TDM_PROHIBITED = re.compile(
    r"\b(?:not|no|prohibit\w*|forbid\w*)\b[^.]{0,120}\b(?:text (?:and|&) data mining|text[- ]mining|data mining|TDM|AI training)\b"
    r"|\b(?:text (?:and|&) data mining|text[- ]mining|TDM)\b[^.]{0,60}\b(?:not (?:permitted|allowed)|prohibited|forbidden)", re.I)


def _code_from_parts(parts: set[str]) -> str:
    code = "cc-by" + ("-nc" if "nc" in parts else "")
    if "nd" in parts:
        return code + "-nd"
    if "sa" in parts:
        return code + "-sa"
    return code


def _parts(text: str) -> set[str]:
    lowered = text.lower().replace("non-commercial", "nc").replace("noncommercial", "nc")
    lowered = re.sub(r"no-?deriv(?:ative)?s", "nd", lowered).replace("share-alike", "sa").replace("sharealike", "sa")
    return {p for p in re.split(r"[- ]+", lowered) if p in {"nc", "nd", "sa"}}


def classify_rights(permissions_text: str, links: Iterable[str]) -> dict[str, Any]:
    """R1 licence classification: explicit CC URL (text, href or ali:license_ref) first, then textual markers.

    When several licences are declared the most restrictive one is used.
    tdm_prohibited is true when a negation and a text/data-mining term share a sentence.
    """
    text = permissions_text or ""
    codes: set[str] = set()
    for source in [text, *[str(l) for l in links]]:
        for match in _CC_URL.finditer(source):
            if match.group(2):
                codes.add("cc0" if match.group(2).lower() == "zero" else "other")
                continue
            raw = match.group(1).lower().strip("-")
            codes.add("cc-" + raw if ("cc-" + raw) in LICENCE_RANK else "other")
    if not codes:
        for match in _CC_TOKEN.finditer(text):
            codes.add(_code_from_parts(_parts(match.group(1) or "")))
        for match in _CC_WORDS.finditer(text):
            codes.add(_code_from_parts(_parts(match.group(1) or "")))
        if _CC_ZERO.search(text):
            codes.add("cc0")
    licence = max(codes, key=LICENCE_RANK.get) if codes else "unknown"
    return {"licence": licence, "tdm_prohibited": bool(TDM_PROHIBITED.search(text))}


def screen_article(article: ET.Element, profile: Mapping[str, Any]) -> tuple[str, dict[str, Any]]:
    """Given a parsed JATS <article>, return ('screened'|gate, detail)."""
    body = article.find("./body")
    if body is None or not _clean_text(body):
        return "headers_only_fulltext", {}
    permission_node = article.find("./front/article-meta/permissions")
    permissions = _clean_text(permission_node)
    links = [] if permission_node is None else [v for e in permission_node.iter() for k, v in e.attrib.items() if _local(k).endswith("href")]
    # R1: only CC-BY / CC-BY-NC / CC0 without a text/data-mining prohibition may count.
    # A licence may be declared as prose, an xlink:href, or <ali:license_ref> text.
    rights = classify_rights(permissions, links)
    if rights["tdm_prohibited"] or rights["licence"] not in COUNTABLE_LICENCES | {"unknown"}:
        return "rights_restricted", {"licence": rights["licence"], "tdm_prohibited": rights["tdm_prohibited"], "license_links": links[:4]}
    if rights["licence"] == "unknown":
        return "rights_unconfirmed", {"licence": "unknown", "license_links": links[:4]}
    regions = method_regions(body)
    if not regions:
        return "no_method_section", {"licence": rights["licence"], "license_links": links[:4]}
    # Coverage upgrade: lexicon tokens (names only, never text) of this countable-licence article's Methods
    # regions, returned for both outcomes; the caller stores them as method mentions.
    import lexicon
    mentions = lexicon.scan(regions)
    hit = signal_hit(regions, profile)
    if hit is None:
        return "off_topic", {"method_regions": len(regions), "licence": rights["licence"], "method_mentions": mentions}
    return "screened", {"signal": hit, "licence": rights["licence"], "license_links": links[:4], "method_regions": len(regions),
                        "method_mentions": mentions}
