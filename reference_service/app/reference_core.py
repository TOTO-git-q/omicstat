"""Read-only, evidence-aware reference catalogue for the omicstat companion (omicstat_reference).

This module indexes a supplied catalogue verbatim.  It deliberately does not
turn catalogue observations into estimator settings or executable arguments.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import threading
from collections import Counter
from pathlib import Path
from typing import Any


class ReferenceError(ValueError):
    """A stable, wrapper-friendly error with a non-secret structured payload."""

    def __init__(self, code: str, message: str, **details: Any) -> None:
        super().__init__(message)
        self.code, self.details = code, details

    def as_dict(self) -> dict[str, Any]:
        return {"error": {"code": self.code, "message": str(self), "details": self.details}}


def _synchronized(method: Any) -> Any:
    """Serialize access when the service caches one store across workers."""
    def wrapped(self: "ReferenceStore", *args: Any, **kwargs: Any) -> Any:
        with self._lock:
            return method(self, *args, **kwargs)
    return wrapped


class ReferenceStore:
    """An immutable-seed SQLite search index.

    A database is tied to the SHA-256 of its seed.  Opening it with a changed
    seed refuses rather than silently replacing a research collection.
    """

    # omicstat fork: query-word expansions for omics vocabulary (the medstat-reference base carried
    # clinical-statistics aliases here). Each alternative is matched as a substring of a record.
    _ALIASES = {
        "差异表达": ("differential expression", "differentially expressed", "deseq2", "edger", "limma"),
        "差异分析": ("differential expression", "differentially expressed", "deseq2", "edger", "limma"),
        "富集": ("enrichment", "gsea", "clusterprofiler", "fgsea", "gsva"),
        "富集分析": ("enrichment", "gsea", "clusterprofiler", "fgsea", "gsva"),
        "单细胞": ("single-cell", "single cell", "scrna-seq", "seurat", "scran", "scanpy"),
        "批次": ("batch", "combat", "sva", "harmony", "fastmnn"),
        "聚类": ("cluster", "leiden", "louvain"),
        "注释": ("annotation", "singler", "scanvi"),
        "轨迹": ("trajectory", "pseudotime", "monocle3", "slingshot"),
        "拟时序": ("pseudotime", "trajectory", "monocle3", "slingshot"),
        "细胞通讯": ("cellchat", "communication", "ligand"),
        "细胞比例": ("proportion", "composition", "propeller"),
        "免疫浸润": ("infiltration", "deconvolution", "immunedeconv"),
        "突变": ("mutation", "maftools", "somatic"),
        "共表达": ("co-expression", "coexpression", "wgcna"),
        "pseudobulk": ("pseudobulk", "pseudo-bulk", "muscat"),
        "gsea": ("gsea", "gene set enrichment", "fgsea"),
    }
    _BAD_EVIDENCE = (
        "not_verified", "pending", "rights", "excerpt", "ambigu", "inconsistent",
        "not_checked", "unverified", "unsupported", "comparator", "candidate",
        "needs_", "partial", "only", "not_reported",
    )
    _UNKNOWN_STRINGS = {"unknown", "未知", "待定", "not applicable", "not_applicable", "n/a", "na"}
    _MAX_CONTRACT_BYTES = 65_536
    _MAX_CONTRACT_STRING = 4_000
    _MAX_CONTRACT_ITEMS = 200
    _MAX_CONTRACT_FIELDS = 100
    _MAX_CONTRACT_DEPTH = 8

    def __init__(self, db_path: str | Path, catalog_path: str | Path, modules: list[str] | None = None) -> None:
        self.db_path, self.catalog_path = Path(db_path), Path(catalog_path)
        # omicstat fork: the module registry is the method map, not the seed's record tags.
        if modules is None:
            import registry
            modules = registry.module_order()
        self.registered_modules = list(modules)
        if not self.catalog_path.is_file():
            raise ReferenceError("catalog_not_found", "Catalog file does not exist.", path=str(self.catalog_path))
        raw = self.catalog_path.read_bytes()
        self.seed_hash = hashlib.sha256(raw).hexdigest()
        try:
            self.catalog = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ReferenceError("invalid_catalog", "Catalog must be valid UTF-8 JSON.") from exc
        self._validate_catalog(self.catalog)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()
        self._conn = sqlite3.connect(str(self.db_path), timeout=5, isolation_level=None, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._conn.execute("PRAGMA busy_timeout = 5000")
        self._conn.execute("PRAGMA foreign_keys = ON")
        try:
            self._initialize()
        except Exception:
            self._conn.close()
            raise

    def close(self) -> None:
        with self._lock:
            self._conn.close()

    def _validate_catalog(self, catalog: dict[str, Any]) -> None:
        if not isinstance(catalog, dict) or not all(isinstance(catalog.get(k), list) for k in ("papers", "usages", "decisions")):
            raise ReferenceError("invalid_catalog", "Catalog needs papers, usages, and decisions lists.")
        ids: dict[str, set[str]] = {"paper": set(), "usage": set(), "decision": set()}
        key = {"paper": "paper_id", "usage": "usage_id", "decision": "decision_id"}
        for typ, collection in (("paper", catalog["papers"]), ("usage", catalog["usages"]), ("decision", catalog["decisions"])):
            for item in collection:
                ident = item.get(key[typ]) if isinstance(item, dict) else None
                if not isinstance(ident, str) or not ident or ident in ids[typ]:
                    raise ReferenceError("invalid_catalog", f"Duplicate or missing {typ} identifier.", record_type=typ, record_id=ident)
                ids[typ].add(ident)
        for usage in catalog["usages"]:
            if usage.get("paper_id") not in ids["paper"]:
                raise ReferenceError("dangling_reference", "Usage refers to a missing paper.", usage_id=usage.get("usage_id"), paper_id=usage.get("paper_id"))
        registered = set(self.registered_modules)
        for typ, collection, field in (("usage", catalog["usages"], "module_tags"), ("decision", catalog["decisions"], "modules")):
            for item in collection:
                unknown = sorted(m for m in item.get(field, []) if m not in registered)
                if unknown:
                    raise ReferenceError("invalid_catalog", "Catalog record is tagged with modules outside the omicstat registry.", record_type=typ, modules=unknown)
        for decision in catalog["decisions"]:
            dangling = [x for x in decision.get("evidence_usage_ids", []) if x not in ids["usage"]]
            if dangling:
                raise ReferenceError("dangling_reference", "Decision refers to missing usage evidence.", decision_id=decision.get("decision_id"), usage_ids=dangling)

    def _initialize(self) -> None:
        self._conn.execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        self._conn.execute("CREATE TABLE IF NOT EXISTS records (record_type TEXT NOT NULL, record_id TEXT NOT NULL, data TEXT NOT NULL, searchable TEXT NOT NULL, modules TEXT NOT NULL, PRIMARY KEY(record_type, record_id))")
        # Recheck after taking the write lock: two constructors can both see an
        # empty database before either gets its SQLite transaction.
        self._conn.execute("BEGIN IMMEDIATE")
        current = self._conn.execute("SELECT value FROM metadata WHERE key = ?", ("seed_hash",)).fetchone()
        if current:
            self._conn.execute("COMMIT")
            if current["value"] != self.seed_hash:
                raise ReferenceError("seed_mismatch", "Existing reference database is bound to a different seed; create a new database explicitly.", existing_seed_hash=current["value"], supplied_seed_hash=self.seed_hash)
            return
        try:
            for typ, key, collection in (("paper", "paper_id", self.catalog["papers"]), ("usage", "usage_id", self.catalog["usages"]), ("decision", "decision_id", self.catalog["decisions"])):
                for record in collection:
                    modules = record.get("module_tags", []) if typ == "usage" else record.get("modules", []) if typ == "decision" else []
                    blob = json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
                    searchable = self._searchable(record)
                    self._conn.execute("INSERT INTO records(record_type,record_id,data,searchable,modules) VALUES(?,?,?,?,?)", (typ, record[key], blob, searchable, json.dumps(modules, ensure_ascii=False)))
            meta = {"seed_hash": self.seed_hash, "seed_schema": str(self.catalog.get("schema", "unknown")), "seed_status": str(self.catalog.get("status", "unknown"))}
            for k, v in meta.items():
                self._conn.execute("INSERT INTO metadata(key,value) VALUES(?,?)", (k, v))
            self._conn.execute("COMMIT")
        except Exception:
            self._conn.execute("ROLLBACK")
            raise

    @staticmethod
    def _searchable(record: dict[str, Any]) -> str:
        def flatten(value: Any) -> list[str]:
            if isinstance(value, dict): return sum((flatten(v) for v in value.values()), [])
            if isinstance(value, list): return sum((flatten(v) for v in value), [])
            if value is None: return []
            return [str(value)]
        return " ".join(flatten(record)).casefold()

    @_synchronized
    def status(self) -> dict[str, Any]:
        with self._lock:
            counts = {x["record_type"]: x["n"] for x in self._conn.execute("SELECT record_type, COUNT(*) n FROM records GROUP BY record_type")}
            modules = Counter()
            for row in self._conn.execute("SELECT modules FROM records WHERE record_type IN (?, ?)", ("usage", "decision")):
                modules.update(json.loads(row["modules"]))
            return {"counts": {"papers": counts.get("paper", 0), "usages": counts.get("usage", 0), "decisions": counts.get("decision", 0)}, "seed_hash": self.seed_hash, "seed_schema": self.catalog.get("schema"), "seed_version": self.catalog.get("schema", "unknown"), "seed_status": self.catalog.get("status"), "module_counts": dict(sorted(modules.items())), "registered_modules": len(self.registered_modules), "modules_without_curated_evidence": sorted(m for m in self.registered_modules if not modules.get(m)), "limitations": list(self.catalog.get("limitations", [])) + ["Catalogue evidence is not a verification of every source, universal parameter choice, biological or clinical correctness, or executable analysis."]}

    @_synchronized
    def search(self, query: str = "", module: str | None = None, limit: int = 10, offset: int = 0) -> dict[str, Any]:
        if not isinstance(query, str) or (module is not None and not isinstance(module, str)):
            raise ReferenceError("invalid_input", "query and module must be strings.")
        if not isinstance(limit, int) or isinstance(limit, bool) or not 1 <= limit <= 50 or not isinstance(offset, int) or isinstance(offset, bool) or offset < 0:
            raise ReferenceError("invalid_pagination", "limit must be 1..50 and offset must be non-negative.")
        normalized_module = module.strip() if module else None
        if normalized_module and normalized_module not in self._modules():
            raise ReferenceError("unknown_module", "Module is not in this catalogue.", module=normalized_module)
        term_groups = self._term_groups(query)
        rows = self._conn.execute("SELECT record_type,record_id,data,searchable,modules FROM records ORDER BY record_type,record_id").fetchall()
        paper_modules: dict[str, set[str]] = {}
        if normalized_module:
            for usage_row in rows:
                if usage_row["record_type"] != "usage":
                    continue
                usage = json.loads(usage_row["data"])
                for tagged in json.loads(usage_row["modules"]):
                    paper_modules.setdefault(usage.get("paper_id"), set()).add(tagged)
        results: list[tuple[int, str, str, dict[str, Any]]] = []
        for row in rows:
            record, mods = json.loads(row["data"]), json.loads(row["modules"])
            record_modules = mods if row["record_type"] != "paper" else paper_modules.get(row["record_id"], set())
            if normalized_module and normalized_module not in record_modules: continue
            if term_groups and not all(any(term in row["searchable"] for term in group) for group in term_groups): continue
            score = sum(sum(row["searchable"].count(term) for term in group) for group in term_groups)
            if normalized_module and row["record_type"] == "decision": score += 100
            results.append((-score, row["record_type"], row["record_id"], record))
        results.sort(key=lambda x: (x[0], x[1], x[2]))
        sliced = results[offset:offset + limit]
        answer = {"query": query, "module": normalized_module, "total": len(results), "offset": offset, "next_offset": offset + limit if offset + limit < len(results) else None, "results": [self._summary(typ, ident, record) for _, typ, ident, record in sliced]}
        if normalized_module:
            answer["curated_evidence"] = self._curated_evidence(normalized_module)
        return answer

    def _curated_evidence(self, module: str) -> dict[str, Any]:
        """omicstat fork: say explicitly when a registered module has no curated seed evidence."""
        n = sum(1 for r in self._conn.execute("SELECT modules FROM records WHERE record_type IN (?,?)", ("usage", "decision")) if module in json.loads(r["modules"]))
        if n:
            return {"status": "curated_evidence_available", "module": module, "records": n}
        return {"status": "no_curated_evidence_yet", "module": module, "records": 0,
                "message": "No curated evidence yet for this omicstat module. The discovery column (unreviewed_machine_screened) may hold machine-screened papers; if evidence is insufficient, file reference_request_literature and do not wait."}

    def _term_groups(self, query: str) -> list[tuple[str, ...]]:
        raw = [x.casefold() for x in re.findall(r"[\w\-]+|[\u3400-\u9fff]+", query)]
        return [tuple(dict.fromkeys(x for x in self._ALIASES.get(word, (word,)) if x)) for word in raw]

    def _summary(self, typ: str, ident: str, record: dict[str, Any]) -> dict[str, Any]:
        title = record.get("title") or record.get("question") or record.get("decision_topic") or record.get("method") or ident
        return {"record_type": typ, "record_id": ident, "summary": str(title)[:360], "modules": record.get("module_tags", record.get("modules", [])), "citations": self._citations(record)}

    @_synchronized
    def get(self, record_type: str, record_id: str) -> dict[str, Any]:
        if record_type not in {"paper", "usage", "decision"}:
            raise ReferenceError("unknown_record_type", "record_type must be paper, usage, or decision.", record_type=record_type)
        if not isinstance(record_id, str) or not record_id:
            raise ReferenceError("invalid_input", "record_id must be a non-empty string.")
        row = self._conn.execute("SELECT data FROM records WHERE record_type = ? AND record_id = ?", (record_type, record_id)).fetchone()
        if not row: raise ReferenceError("not_found", "Record was not found.", record_type=record_type, record_id=record_id)
        record = json.loads(row["data"])
        related = self._related(record_type, record)
        return {"record_type": record_type, "record_id": record_id, "record": record, "related_ids": related, "provenance": self._provenance(record)}

    def _related(self, typ: str, record: dict[str, Any]) -> dict[str, list[str]]:
        if typ == "paper":
            return {"usage_ids": [r["record_id"] for r in self._conn.execute("SELECT record_id,data FROM records WHERE record_type = ?", ("usage",)) if json.loads(r["data"]).get("paper_id") == record["paper_id"]]}
        if typ == "usage": return {"paper_ids": [record["paper_id"]], "decision_ids": [r["record_id"] for r in self._conn.execute("SELECT record_id,data FROM records WHERE record_type = ?", ("decision",)) if record["usage_id"] in json.loads(r["data"]).get("evidence_usage_ids", [])]}
        return {"usage_ids": list(record.get("evidence_usage_ids", [])), "paper_ids": sorted({self.get("usage", x)["record"].get("paper_id") for x in record.get("evidence_usage_ids", [])})}

    @staticmethod
    def _provenance(record: dict[str, Any]) -> dict[str, Any]:
        return {k: record[k] for k in ("source_lane", "supplement_lane", "access_level", "verification_status", "reviewer_status", "retrieval_date", "metadata_verification_sources", "fulltext_provenance") if k in record}

    def _citations(self, record: dict[str, Any]) -> list[dict[str, Any]]:
        if "paper_id" in record and "title" not in record:
            paper = record.get("paper") or self.get("paper", record["paper_id"])["record"]
            locator = record.get("source_locator", {})
            return [{"paper_id": paper["paper_id"], "title": paper.get("title"), "year": paper.get("year"), "doi": paper.get("doi"), "url": locator.get("url") or paper.get("url"), "locator": locator, "verification_status": record.get("verification_status"), "access_level": record.get("access_level")}]
        if "paper_id" in record: return [{"paper_id": record["paper_id"], "title": record.get("title"), "year": record.get("year"), "doi": record.get("doi"), "url": record.get("url"), "verification_status": record.get("verification_status"), "access_level": record.get("access_level")}]
        return []

    def _modules(self) -> set[str]:
        # omicstat fork: registry = method map (was: module tags found in seed records).
        return set(self.registered_modules)

    @_synchronized
    def advise(self, module: str, study_contract: dict[str, Any]) -> dict[str, Any]:
        if module not in self._modules(): raise ReferenceError("unknown_module", "Module is not in this catalogue.", module=module)
        if not isinstance(study_contract, dict): raise ReferenceError("invalid_study_contract", "study_contract must be an object.")
        self._validate_contract_bounds(study_contract)
        rules = self._rules().get(module, {})
        common = self._common_required()
        missing = self._missing_inputs(study_contract, {**common, **rules.get("additional_required", {})})
        decisions = [self.get("decision", x["record_id"])["record"] for x in self.search(module=module, limit=50)["results"] if x["record_type"] == "decision"]
        candidates = [{"decision_id": d["decision_id"], "question": d.get("question"), "status": d.get("status"), "applicable_when": d.get("applicable_when"), "options": d.get("options", []), "avoid_when": d.get("avoid_when", []), "unresolved": d.get("unresolved", []), "required_inputs": d.get("required_inputs", []), "evidence_usage_ids": d.get("evidence_usage_ids", []), "citations": [citation for usage_id in d.get("evidence_usage_ids", []) for citation in self._citations(self.get("usage", usage_id)["record"])]} for d in decisions]
        base = {"module": module, "execution_authorized": False, "automatic_parameter_application": False, "curated_evidence": self._curated_evidence(module), "input_checklist": {"common": common, "module_specific": rules.get("additional_required", {}), "contraindication_prompts": rules.get("contraindication_prompts", []), "reusable_covariate_goals": self._covariate_goals()}, "material_unknowns": missing, "candidate_decisions": candidates}
        if missing:
            return {**base, "status": "needs_input", "assumptions_to_confirm": ["Explicit null/not_applicable values are recorded as material unknowns and need human review."], "candidate_usages": [], "parameter_options": []}
        usages = [self.get("usage", x["record_id"])["record"] for x in self.search(module=module, limit=50)["results"] if x["record_type"] == "usage"]
        # Reviewed supplement is additive evidence, never part of the curated seed.
        import curation
        supplement = curation.supplement_usages(self.db_path.parent, module)
        supplement_total = len(supplement)
        # Bound the initial advice page; full observations are available through search/get.
        usages.extend(supplement[:3])
        proposed = [self._parameter_option(u) for u in usages if self._eligible(u)]
        return {**base, "status": "review_required", "assumptions_to_confirm": ["Study-contract fields and design compatibility require human confirmation.", "Reported source values are observations, not a universal optimum or parameter prescription."], "candidate_usages": [self._usage_candidate(u) for u in usages], "parameter_options": proposed, "reviewed_supplement_total": supplement_total, "reviewed_supplement_returned": min(3, supplement_total), "evidence_page_note": "Initial supplement page (usage_id order); use reference_search and reference_get_record(record_type=supplement) for all observations.", "parameter_option_note": "Empty options means no evidence met the conservative parameter-proposal gate; browseable records remain available via search/get."}

    def _rules(self) -> dict[str, Any]:
        here = Path(__file__).with_name("decision_rules.json")
        return json.loads(here.read_text(encoding="utf-8"))["modules"]

    @staticmethod
    def _covariate_goals() -> list[dict[str, str]]:
        return json.loads(Path(__file__).with_name("decision_rules.json").read_text(encoding="utf-8"))["reusable_covariate_goals"]

    @staticmethod
    def _common_required() -> dict[str, str]:
        # omicstat fork: the common study-context checklist is configuration (StudyContract omics mapping).
        return dict(json.loads(Path(__file__).with_name("decision_rules.json").read_text(encoding="utf-8"))["common_required"])

    @classmethod
    def _validate_contract_bounds(cls, contract: dict[str, Any]) -> None:
        try:
            encoded = json.dumps(contract, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode("utf-8")
        except (TypeError, ValueError) as exc:
            raise ReferenceError("invalid_study_contract", "study_contract must be finite JSON-compatible data.") from exc
        if len(encoded) > cls._MAX_CONTRACT_BYTES:
            raise ReferenceError("study_contract_too_large", "study_contract exceeds the 65536-byte limit.", max_bytes=cls._MAX_CONTRACT_BYTES)
        def walk(value: Any, depth: int = 0) -> None:
            if depth > cls._MAX_CONTRACT_DEPTH:
                raise ReferenceError("study_contract_too_deep", "study_contract nesting exceeds the bounded limit.", max_depth=cls._MAX_CONTRACT_DEPTH)
            if isinstance(value, str) and len(value) > cls._MAX_CONTRACT_STRING:
                raise ReferenceError("study_contract_string_too_long", "study_contract contains an overlong string.", max_characters=cls._MAX_CONTRACT_STRING)
            if isinstance(value, dict):
                if len(value) > cls._MAX_CONTRACT_FIELDS:
                    raise ReferenceError("study_contract_too_many_fields", "study_contract object has too many fields.", max_fields=cls._MAX_CONTRACT_FIELDS)
                for item in value.values(): walk(item, depth + 1)
            elif isinstance(value, list):
                if len(value) > cls._MAX_CONTRACT_ITEMS:
                    raise ReferenceError("study_contract_too_many_items", "study_contract list has too many items.", max_items=cls._MAX_CONTRACT_ITEMS)
                for item in value: walk(item, depth + 1)
        walk(contract)

    @staticmethod
    def _missing_inputs(contract: dict[str, Any], required: dict[str, str]) -> list[dict[str, str]]:
        missing = []
        for key, kind in required.items():
            value = contract.get(key)
            declared_unknown = value is None or (isinstance(value, str) and value.strip().casefold() in ReferenceStore._UNKNOWN_STRINGS)
            ok = (declared_unknown or (kind == "positive_integer" and isinstance(value, int) and not isinstance(value, bool) and value > 0) or (kind == "nonempty_string" and isinstance(value, str) and bool(value.strip())) or (kind == "nonempty_description" and ((isinstance(value, str) and bool(value.strip())) or (isinstance(value, dict) and bool(value)))) or (kind == "string_or_not_applicable" and (isinstance(value, str) and bool(value.strip()) or value in (None, "not_applicable"))) or (kind == "list_or_not_applicable" and (isinstance(value, list) or value in (None, "not_applicable"))) or (kind == "object_or_not_applicable" and (isinstance(value, dict) or value in (None, "not_applicable"))) or (kind == "boolean_or_not_applicable" and (isinstance(value, bool) or value in (None, "not_applicable"))))
            if not ok:
                missing.append({"field": key, "expected": kind})
            elif key not in contract or declared_unknown:
                # These are allowed declarations, but they are never silently
                # treated as sufficient evidence for a scientific decision.
                missing.append({"field": key, "expected": kind, "provided_as": "unknown_or_not_applicable"})
        return missing

    def _eligible(self, usage: dict[str, Any]) -> bool:
        if usage.get("column") == "discovery":
            return False
        if usage.get("column") == "reviewed_supplement":
            parameters = usage.get("parameters", [])
            if not parameters or not all(p.get("source_locator", {}).get("snippet") and
                                         p.get("source_locator", {}).get("section_path") for p in parameters):
                return False
        text = " ".join(str(usage.get(k, "")) for k in ("verification_status", "reviewer_status", "access_level", "implementation_compatibility", "support_role")).casefold()
        if any(flag in text for flag in self._BAD_EVIDENCE): return False
        verification = str(usage.get("verification_status", "")).casefold()
        # A bare word such as "verified", "passed", or a user-supplied status
        # is not a safety signal.  The catalogue needs a specifically located
        # primary/full-text verification before a root-reviewed usage can pass.
        trusted_locator = any(marker in verification for marker in (
            "full_text_locator_verified", "primary_source_full_text_verified",
            "primary_source_methods_verified", "full_text_opened; parameter_values_located",
        ))
        role = usage.get("support_role")
        compatibility = usage.get("implementation_compatibility")
        compatibility_status = compatibility.get("status", "") if isinstance(compatibility, dict) else str(compatibility or "")
        return trusted_locator and role in {"direct_application", "methodological_basis"} and usage.get("reviewer_status") in {"ready_for_root_review", "root_reviewed"} and "inventory_supported" in compatibility_status and bool(usage.get("parameters"))

    def _usage_candidate(self, usage: dict[str, Any]) -> dict[str, Any]:
        return {"usage_id": usage["usage_id"], "method": usage.get("method"), "support_role": usage.get("support_role", "legacy_unspecified"), "verification_status": usage.get("verification_status"), "reviewer_status": usage.get("reviewer_status", "legacy_unspecified"), "eligible_for_parameter_proposal": self._eligible(usage), "citations": self._citations(usage)}

    def _parameter_option(self, usage: dict[str, Any]) -> dict[str, Any]:
        return {"usage_id": usage["usage_id"], "column": usage.get("column", "curated"), "reported_parameters": usage.get("parameters"), "compatibility": usage.get("implementation_compatibility"), "verification_status": usage.get("verification_status"), "transfer_conditions": usage.get("transfer_conditions"), "reported_rationale": usage.get("reported_rationale"), "limitations": usage.get("limitations"), "citations": self._citations(usage), "applicability_status": "not_checked_against_study_contract", "note": "Reported study-specific observation only; no automatic matching has been performed. Review current-design applicability and source locator before any analysis decision."}
