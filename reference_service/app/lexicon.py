"""Method lexicon matcher (omicstat fork, coverage upgrade).

The lexicon (``method_lexicon.json``, built by ``build_lexicon.py``) lists omics packages and omics method
names.  ``scan`` returns the SORTED TOKENS that occur in Methods text; nothing else is ever stored (no
snippet, no offsets).  Callers must only pass text from articles with a countable licence.
Pure stdlib, no I/O besides loading the JSON.
"""
from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable, Mapping

LEXICON_PATH = Path(__file__).with_name("method_lexicon.json")
LEXICON_SCHEMA = "omicstat.reference.method-lexicon.v1"


class LexiconError(ValueError):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def load_lexicon(path: str | Path | None = None) -> dict[str, Any]:
    p = Path(path) if path is not None else LEXICON_PATH
    try:
        raw = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise LexiconError("invalid_lexicon", "method_lexicon.json must be readable UTF-8 JSON") from exc
    if not isinstance(raw, Mapping) or raw.get("schema") != LEXICON_SCHEMA or not isinstance(raw.get("entries"), list) or not raw["entries"]:
        raise LexiconError("invalid_lexicon", "method lexicon schema is not supported")
    compiled, by_token = [], {}
    for entry in raw["entries"]:
        token, regex = entry.get("token"), entry.get("regex")
        if not isinstance(token, str) or not re.fullmatch(r"[a-z0-9][a-z0-9+-]*", token) or not isinstance(regex, str) or not regex:
            raise LexiconError("invalid_lexicon", "lexicon entry needs a token and a regex")
        if token in by_token:
            raise LexiconError("invalid_lexicon", "duplicate lexicon token " + token)
        try:
            pattern = re.compile(regex, re.I if entry.get("case_insensitive", True) else 0)
        except re.error as exc:
            raise LexiconError("invalid_lexicon", "lexicon regex does not compile: " + token) from exc
        by_token[token] = entry
        compiled.append((token, pattern))
    return {"version": str(raw.get("version")), "entries": raw["entries"], "by_token": by_token, "compiled": compiled,
            "families": list(raw.get("families", []))}


@lru_cache(maxsize=1)
def default_lexicon() -> dict[str, Any]:
    return load_lexicon()


def scan(regions: Iterable[Mapping[str, Any] | str], lexicon: Mapping[str, Any] | None = None) -> list[str]:
    """Sorted unique lexicon tokens found in the given Methods regions (dicts with 'text', or plain strings)."""
    lex = lexicon or default_lexicon()
    texts = [r if isinstance(r, str) else str(r.get("text", "")) for r in regions]
    found = {token for token, pattern in lex["compiled"] if any(pattern.search(t) for t in texts)}
    return sorted(found)
