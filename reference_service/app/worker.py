"""Resident, bounded acquisition worker for the container deployment.

The worker uses only the official direct transport.  Its durable heartbeat is
separate from harvest.sqlite, so a health probe never needs a network request.
Each cycle calls harvest_daily, which serves queued literature requests first
(at most 4 screened per day) and then the module rotation; only v2 screened
candidates count toward the daily ten, and each day's shortfall is recorded.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import signal
import sys
import threading
import uuid
from pathlib import Path
from typing import Any, Callable, Mapping

from harvest import HarvestError, HarvestStore, TZ_SHANGHAI, harvest_daily

INTERVAL_SECONDS = 10_800
HEARTBEAT_SECONDS = 60
HEALTH_MAX_AGE_SECONDS = 600
MAX_ATTEMPTS_PER_DAY = 8
STATUS_SCHEMA = "omicstat.reference.worker-status.v1"
ROOT = Path(__file__).resolve().parent


def _data_dir() -> Path:
    return Path(os.environ.get("OMICSTAT_REFERENCE_DATA", str(ROOT / "data"))).resolve()


def _logs_dir() -> Path:
    return Path(os.environ.get("OMICSTAT_REFERENCE_LOGS", str(ROOT / "logs"))).resolve()


def _status_path(data_dir: Path | None = None) -> Path:
    return (data_dir or _data_dir()) / "worker_status.json"


class _WorkerLock:
    """A process-lifetime singleton lock; the OS releases it after a hard death.

    The lock *file* may remain after a reboot.  That is harmless: flock/msvcrt
    lock ownership belongs to the open process handle, never to the file's age.
    """
    def __init__(self, path: Path):
        self.path = path
        self._handle: Any | None = None

    def acquire(self) -> bool:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        handle = self.path.open("a+b")
        try:
            if os.name == "nt":
                # Windows has no flock.  Reserve one persistent byte so msvcrt
                # can take a non-blocking byte-range lock with identical intent.
                import msvcrt
                handle.seek(0, os.SEEK_END)
                if handle.tell() == 0:
                    handle.write(b"0")
                    handle.flush()
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            handle.close()
            return False
        self._handle = handle
        return True

    def release(self) -> None:
        handle, self._handle = self._handle, None
        if handle is None:
            return
        try:
            if os.name == "nt":
                import msvcrt
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        finally:
            handle.close()


def _now() -> dt.datetime:
    return dt.datetime.now(TZ_SHANGHAI).replace(microsecond=0)


def _iso(value: dt.datetime) -> str:
    return value.astimezone(TZ_SHANGHAI).replace(microsecond=0).isoformat()


def _parse_time(value: Any) -> dt.datetime | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = dt.datetime.fromisoformat(value)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed.astimezone(TZ_SHANGHAI)


def _read_status(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) and value.get("schema") == STATUS_SCHEMA else None


def _write_status(path: Path, status: Mapping[str, Any]) -> None:
    """Atomically publish a small status object suitable for Docker healthchecks."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + uuid.uuid4().hex + ".tmp")
    payload = json.dumps(dict(status), ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    try:
        temporary.write_text(payload + "\n", encoding="utf-8")
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass


def _compact_summary(value: Mapping[str, Any]) -> dict[str, Any]:
    keys = ("day", "state", "collected", "daily_total", "target", "quota_basis", "shortfall", "shortage", "requests",
            "route", "gt103_fallback", "gate_counts", "literature_requests_served", "runtime_seconds", "errors")
    return {key: value[key] for key in keys if key in value}


def _append_log(log_dir: Path, event: Mapping[str, Any]) -> None:
    """Retain at most one previous small JSONL segment; neither raw articles nor secrets enter it."""
    log_dir.mkdir(parents=True, exist_ok=True)
    active, previous = log_dir / "worker.jsonl", log_dir / "worker.jsonl.1"
    try:
        if active.exists() and active.stat().st_size > 512_000:
            os.replace(active, previous)
        with active.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(dict(event), ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n")
    except OSError as exc:
        print(json.dumps({"worker_log_error": type(exc).__name__}), file=sys.stderr, flush=True)


def _health(path: Path, now: dt.datetime | None = None) -> tuple[bool, dict[str, Any]]:
    status = _read_status(path)
    current = now or _now()
    heartbeat = _parse_time(None if status is None else status.get("heartbeat_at"))
    age = None if heartbeat is None else max(0, int((current - heartbeat).total_seconds()))
    healthy = bool(status and status.get("mode") == "resident" and status.get("alive") is True
                   and age is not None and age <= HEALTH_MAX_AGE_SECONDS)
    return healthy, {"healthy": healthy, "status_path": str(path), "heartbeat_age_seconds": age,
                     "worker_state": None if status is None else status.get("state")}


def _next_midnight(now: dt.datetime) -> dt.datetime:
    return dt.datetime.combine(now.date() + dt.timedelta(days=1), dt.time.min, tzinfo=TZ_SHANGHAI)


def _attempt(store: HarvestStore, now: dt.datetime,
             harvest_fn: Callable[..., dict[str, Any]]) -> dict[str, Any]:
    try:
        result = harvest_fn(store, target=10, transport="direct", seed_catalog=ROOT / "seed" / "catalog.json",
                            max_requests=60, now=now)
        return _compact_summary(result)
    except (HarvestError, OSError, RuntimeError, ValueError) as exc:
        return {"day": now.date().isoformat(), "state": "worker_attempt_failed",
                "error": getattr(exc, "code", type(exc).__name__), "message": str(exc)[:240]}


def run_once(*, data_dir: Path | None = None, now: dt.datetime | None = None,
             harvest_fn: Callable[..., dict[str, Any]] = harvest_daily) -> dict[str, Any]:
    """Manual deterministic invocation.  It deliberately does not touch resident liveness."""
    directory = data_dir or _data_dir()
    directory.mkdir(parents=True, exist_ok=True)
    return _attempt(HarvestStore(directory / "harvest.sqlite"), now or _now(), harvest_fn)


def run_worker(*, data_dir: Path | None = None, logs_dir: Path | None = None,
               now_fn: Callable[[], dt.datetime] = _now, sleep_fn: Callable[[float], None] | None = None,
               harvest_fn: Callable[..., dict[str, Any]] = harvest_daily, stop_event: threading.Event | None = None,
               max_cycles: int | None = None, lock_factory: Callable[[Path], _WorkerLock] = _WorkerLock) -> dict[str, Any]:
    """Run PID1 scheduling; bounded injection seams keep timing/network tests deterministic."""
    directory, log_directory = data_dir or _data_dir(), logs_dir or _logs_dir()
    directory.mkdir(parents=True, exist_ok=True)
    store, status_file = HarvestStore(directory / "harvest.sqlite"), _status_path(directory)
    stopper = stop_event or threading.Event()
    worker_lock = lock_factory(directory / "worker.lock")
    if not worker_lock.acquire():
        return {"state": "already_running", "worker_status": str(status_file)}
    previous = _read_status(status_file) or {}
    current = now_fn().astimezone(TZ_SHANGHAI)
    attempts_day = current.date().isoformat() == previous.get("attempt_day")
    attempt_count = int(previous.get("attempt_count", 0)) if attempts_day else 0
    next_due = _parse_time(previous.get("next_due_at"))
    status: dict[str, Any] = {"schema": STATUS_SCHEMA, "mode": "resident", "alive": True, "state": "starting",
        "pid": os.getpid(), "started_at": _iso(current), "heartbeat_at": _iso(current),
        "attempt_day": current.date().isoformat(), "attempt_count": attempt_count,
        "next_due_at": _iso(next_due) if next_due else None, "last_summary": previous.get("last_summary")}
    _write_status(status_file, status)
    cycles = 0
    try:
        while not stopper.is_set():
            current = now_fn().astimezone(TZ_SHANGHAI)
            if status["attempt_day"] != current.date().isoformat():
                status["attempt_day"], status["attempt_count"], next_due = current.date().isoformat(), 0, None
            due = next_due is None or current >= next_due
            if due and int(status["attempt_count"]) < MAX_ATTEMPTS_PER_DAY:
                # Reserve the complete slot *before* any network I/O.  An abrupt
                # Docker kill leaves this checkpoint, so a restart cannot storm
                # Europe PMC by retrying a partially started attempt immediately.
                next_due = current + dt.timedelta(seconds=INTERVAL_SECONDS)
                status["attempt_count"] = int(status["attempt_count"]) + 1
                status.update({"state": "running", "heartbeat_at": _iso(current), "last_attempt_at": _iso(current),
                               "next_due_at": _iso(next_due)})
                _write_status(status_file, status)
                summary = _attempt(store, current, harvest_fn)
                finished = now_fn().astimezone(TZ_SHANGHAI)
                status.update({"state": "waiting", "last_summary": summary, "last_completed_at": _iso(finished),
                               "heartbeat_at": _iso(finished)})
                _append_log(log_directory, {"at": _iso(finished), "event": "attempt", "summary": summary})
                cycles += 1
            elif due:
                next_due = _next_midnight(current)
                status.update({"state": "daily_attempt_limit", "heartbeat_at": _iso(current)})
                _append_log(log_directory, {"at": _iso(current), "event": "daily_attempt_limit"})
            status["next_due_at"] = _iso(next_due)
            status["alive"], status["heartbeat_at"] = True, _iso(now_fn().astimezone(TZ_SHANGHAI))
            _write_status(status_file, status)
            if max_cycles is not None and cycles >= max_cycles:
                break
            while not stopper.is_set():
                current = now_fn().astimezone(TZ_SHANGHAI)
                if current >= next_due:
                    break
                status["heartbeat_at"] = _iso(current)
                _write_status(status_file, status)
                wait_seconds = min(HEARTBEAT_SECONDS, max(0.0, (next_due - current).total_seconds()))
                if sleep_fn is None:
                    stopper.wait(wait_seconds)
                else:
                    sleep_fn(wait_seconds)
    finally:
        try:
            final = now_fn().astimezone(TZ_SHANGHAI)
            status.update({"alive": False, "state": "stopped", "stopped_at": _iso(final), "heartbeat_at": _iso(final)})
            _write_status(status_file, status)
            _append_log(log_directory, {"at": _iso(final), "event": "stopped"})
        finally:
            worker_lock.release()
    return {"state": "stopped", "worker_status": str(status_file), "attempt_count": status["attempt_count"]}


def _install_signal_handlers(stop_event: threading.Event) -> None:
    def stop(_signal: int, _frame: Any) -> None:
        stop_event.set()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Resident omicstat reference acquisition worker")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--once", action="store_true", help="perform one direct bounded harvest without changing worker liveness")
    mode.add_argument("--health", action="store_true", help="read resident heartbeat only")
    args = parser.parse_args(argv)
    if args.health:
        healthy, payload = _health(_status_path())
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), flush=True)
        return 0 if healthy else 1
    if args.once:
        print(json.dumps(run_once(), ensure_ascii=False, separators=(",", ":")), flush=True)
        return 0
    stop_event = threading.Event()
    _install_signal_handlers(stop_event)
    result = run_worker(stop_event=stop_event)
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")), file=sys.stderr, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
