"""omicstat module registry: the ordered module list of method_map.json (omicstat fork addition).

In the medstat-reference base, the reference store learned its module names from seed records and
the literature-request schema carried a hard-coded module enum. In the omicstat fork the method map
is the single registry: search, advise, literature requests, review tags and domain proposals all
accept exactly the modules listed here, whether or not any curated evidence exists for them.
"""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any, Mapping

METHOD_MAP_PATH = Path(__file__).with_name("method_map.json")
METHOD_MAP_SCHEMA = "omicstat.method-map.v1"


class RegistryError(ValueError):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def load_method_map(path: str | Path | None = None) -> dict[str, Any]:
    """Load the authoritative router order; never derive one from dates/hashes."""
    map_path = Path(path) if path is not None else METHOD_MAP_PATH
    try:
        raw = json.loads(map_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RegistryError("invalid_method_map", "Method map must be readable UTF-8 JSON") from exc
    if not isinstance(raw, Mapping) or raw.get("schema") != METHOD_MAP_SCHEMA:
        raise RegistryError("invalid_method_map", "Method map schema is not supported")
    modules = raw.get("modules")
    if not isinstance(modules, list) or not modules:
        raise RegistryError("invalid_method_map", "Method map must contain ordered modules")
    order: list[str] = []
    normalized: list[dict[str, str]] = []
    for item in modules:
        if not isinstance(item, Mapping):
            raise RegistryError("invalid_method_map", "Method map entries must be objects")
        module, entry = item.get("module"), item.get("entry_script")
        if not isinstance(module, str) or not re.fullmatch(r"[a-z0-9-]+", module) or not isinstance(entry, str) or not entry:
            raise RegistryError("invalid_method_map", "Method map entry is malformed")
        order.append(module)
        normalized.append({"module": module, "entry_script": entry})
    if len(set(order)) != len(order):
        raise RegistryError("invalid_method_map", "Method map modules must be unique")
    canonical = {"schema": raw["schema"], "source_path": raw.get("source_path"),
                 "source_sha256": raw.get("source_sha256"), "modules": normalized}
    return {"hash": hashlib.sha256(json.dumps(canonical, ensure_ascii=False, sort_keys=True,
                                                 separators=(",", ":")).encode("utf-8")).hexdigest(),
            "source_sha256": raw.get("source_sha256"), "order": order, "modules": normalized}


def module_order(path: str | Path | None = None) -> list[str]:
    return list(load_method_map(path)["order"])
