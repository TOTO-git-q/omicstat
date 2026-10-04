"""Refusal patterns for patient- or institution-identifying text in free-form tool input.

Requests and proposals are research-method descriptions.  Anything that looks
like a contact detail or a record identifier is refused outright (never
redacted and stored), so no such value is ever persisted.
"""
from __future__ import annotations

import re
from typing import Any, Iterable

SENSITIVE_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("email_address", re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}")),
    ("phone_number", re.compile(r"\+\d{1,3}[\s.\-]?\(?\d{1,4}\)?(?:[\s.\-]?\d{2,4}){2,}")),
    ("phone_number", re.compile(r"\(\d{2,4}\)\s?\d{3,4}[\s.\-]?\d{3,4}")),
    ("phone_number", re.compile(r"(?<!\d)\d{3}[\s.\-]\d{3,4}[\s.\-]\d{4}(?!\d)")),
    ("long_numeric_identifier", re.compile(r"(?<![\d.,])\d{6,}(?![\d.,]?\d)")),
    ("record_identifier_keyword", re.compile(r"\bMRN(?:\b|(?=\d))|住院号|病案号|病历号|门诊号|身份证|patient[\s_\-]*id\b|medical[\s_\-]+record[\s_\-]+(?:number|no)\b|\bSSN\b|social security|passport", re.I)),
)


def _strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, item in value.items():
            yield str(key)
            yield from _strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from _strings(item)


BIBLIOGRAPHIC_LOCATOR = re.compile(r"\bPMID:?\s*\d{1,9}\b|\bPMC\d{3,9}\b|\b10\.\d{4,9}/\S+|https?://\S+", re.I)


def strip_bibliographic_locators(text: str) -> str:
    """Remove PMID/PMCID/DOI/URL locators so a literature citation is not mistaken for a record ID."""
    return BIBLIOGRAPHIC_LOCATOR.sub(" ", text)


def find_sensitive(value: Any) -> list[str]:
    """Return the names of sensitive-pattern classes present anywhere in ``value``."""
    found: list[str] = []
    for text in _strings(value):
        for name, pattern in SENSITIVE_PATTERNS:
            if name not in found and pattern.search(text):
                found.append(name)
    return found
