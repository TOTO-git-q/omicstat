"""Build-time package identity for installations deliberately shipped without .git.

The record is generated only from a clean Git checkout.  At runtime it is an
integrity fallback only when the checkout metadata is genuinely absent; a Git
worktree always continues to use its observed HEAD/dirty state.
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, Optional


IDENTITY_REL = "research/remediation/package_identity.json"
SCHEMA = "omicstat.package-identity.v1"
HEX = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")
TREE = re.compile(r"^[0-9a-f]{40}$")


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical_files(files: list[dict[str, str]]) -> bytes:
    return json.dumps(files, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def _relative(value: str) -> bool:
    return bool(value) and not Path(value).is_absolute() and ".." not in Path(value).parts and "\\" not in value


def build(repo: Path) -> dict[str, Any]:
    """Return an identity only for a clean Git worktree, excluding itself."""
    status = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], cwd=repo,
                            capture_output=True, text=True, check=False)
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True, text=True, check=False)
    tree = subprocess.run(["git", "rev-parse", "HEAD^{tree}"], cwd=repo, capture_output=True, text=True, check=False)
    listed = subprocess.run(["git", "ls-files", "-z"], cwd=repo, capture_output=True, check=False)
    if status.returncode or status.stdout.strip() or commit.returncode or tree.returncode or listed.returncode:
        raise RuntimeError("package identity requires a clean Git checkout")
    c, t = commit.stdout.strip().lower(), tree.stdout.strip().lower()
    if not COMMIT.fullmatch(c) or not TREE.fullmatch(t):
        raise RuntimeError("Git did not return commit/tree identities")
    files: list[dict[str, str]] = []
    for raw in listed.stdout.split(b"\0"):
        if not raw:
            continue
        rel = raw.decode("utf-8")
        if rel == IDENTITY_REL:
            continue
        # Package archives are built from Git blobs, which can differ from a
        # Windows checkout's CRLF working bytes. Bind the identity to those
        # exact archive bytes rather than to checkout filters.
        blob = subprocess.run(["git", "show", "HEAD:" + rel], cwd=repo,
                              capture_output=True, check=False)
        if blob.returncode:
            raise RuntimeError("cannot read tracked package blob: " + rel)
        files.append({"path": rel, "sha256": hashlib.sha256(blob.stdout).hexdigest()})
    files.sort(key=lambda row: row["path"])
    return {"schema": SCHEMA, "source_commit": c, "source_tree": t,
            "files": files, "inventory_sha256": hashlib.sha256(_canonical_files(files)).hexdigest()}


def write(repo: Path) -> Path:
    payload = build(repo)
    path = repo / IDENTITY_REL
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return path


def load_and_verify(repo: Path) -> Optional[dict[str, Any]]:
    """Return verified immutable package identity, otherwise None (fail closed)."""
    path = repo / IDENTITY_REL
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(value, dict) or value.get("schema") != SCHEMA:
            return None
        if not COMMIT.fullmatch(str(value.get("source_commit", ""))) or not TREE.fullmatch(str(value.get("source_tree", ""))):
            return None
        files = value.get("files")
        if not isinstance(files, list) or not files:
            return None
        canonical: list[dict[str, str]] = []
        seen: set[str] = set()
        for item in files:
            if not isinstance(item, dict):
                return None
            rel, digest = item.get("path"), item.get("sha256")
            if not isinstance(rel, str) or not _relative(rel) or rel in seen or not isinstance(digest, str) or not HEX.fullmatch(digest):
                return None
            seen.add(rel)
            candidate = repo / rel
            if not candidate.is_file() or _sha(candidate) != digest:
                return None
            canonical.append({"path": rel, "sha256": digest})
        canonical.sort(key=lambda row: row["path"])
        if canonical != files or hashlib.sha256(_canonical_files(canonical)).hexdigest() != value.get("inventory_sha256"):
            return None
        return value
    except (OSError, ValueError, UnicodeError):
        return None
