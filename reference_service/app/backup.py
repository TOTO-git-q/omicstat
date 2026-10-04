"""Timestamped, WAL-safe backups of the reference data directory.

Used automatically before any additive schema migration touches an existing
database, and manually via ``cli.py backup`` / the documented upgrade steps.
SQLite files are copied through the online backup API (never a raw copy of a
file that may have an uncommitted WAL); other small top-level files are copied
verbatim.  The ``backups/`` directory itself is never included.
"""
from __future__ import annotations

import datetime as dt
import io
import os
import shutil
import sqlite3
import tarfile
import uuid
from contextlib import closing
from pathlib import Path

BACKUP_DIRNAME = "backups"
MAX_PLAIN_FILE_BYTES = 5_000_000


def backup_data_dir(data_dir: str | Path, label: str = "manual") -> Path:
    data = Path(data_dir).resolve()
    if not data.is_dir():
        raise OSError(f"data directory does not exist: {data}")
    safe_label = "".join(ch for ch in label if ch.isalnum() or ch in "-_")[:40] or "backup"
    target_dir = data / BACKUP_DIRNAME
    target_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    archive = target_dir / f"omicstat-reference-data-{stamp}-{safe_label}-{uuid.uuid4().hex[:6]}.tar"
    staging = target_dir / (".staging-" + uuid.uuid4().hex)
    staging.mkdir()
    try:
        members: list[tuple[Path, str]] = []
        for item in sorted(data.iterdir()):
            if item.name == BACKUP_DIRNAME or item.name.startswith(".staging-") or not item.is_file():
                continue
            if item.suffix == ".sqlite":
                copy = staging / item.name
                with closing(sqlite3.connect(item.as_uri() + "?mode=ro", uri=True, timeout=10)) as src, \
                        closing(sqlite3.connect(str(copy))) as dst:
                    src.backup(dst)
                members.append((copy, item.name))
            elif item.name.endswith(("-wal", "-shm", ".lock", ".tmp")):
                continue
            elif item.stat().st_size <= MAX_PLAIN_FILE_BYTES:
                members.append((item, item.name))
        temporary = archive.with_suffix(".tar.partial")
        with tarfile.open(temporary, "w") as tar:
            for path, name in members:
                tar.add(str(path), arcname="data/" + name, recursive=False)
            manifest = ("created_utc=%s\nlabel=%s\nfiles=%s\n" % (stamp, safe_label, ",".join(n for _, n in members))).encode()
            info = tarfile.TarInfo("data/BACKUP_MANIFEST.txt")
            info.size = len(manifest)
            tar.addfile(info, io.BytesIO(manifest))
        os.replace(temporary, archive)
        return archive
    finally:
        shutil.rmtree(staging, ignore_errors=True)


def list_backups(data_dir: str | Path) -> list[str]:
    target = Path(data_dir).resolve() / BACKUP_DIRNAME
    return sorted(p.name for p in target.glob("omicstat-reference-data-*.tar")) if target.is_dir() else []
