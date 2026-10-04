import datetime as dt
import threading
import time
import unittest
from pathlib import Path

from scratch import scratch_directory
from worker import (HEALTH_MAX_AGE_SECONDS, STATUS_SCHEMA, TZ_SHANGHAI, _WorkerLock,
                    _health, _read_status, _status_path, _write_status, run_once, run_worker)


class Clock:
    def __init__(self, current):
        self.current = current
        self.sleeps = []

    def now(self):
        return self.current

    def sleep(self, seconds):
        self.sleeps.append(seconds)
        self.current += dt.timedelta(seconds=seconds)


def success_harvest(store, **kwargs):
    return {"day": kwargs["now"].date().isoformat(), "state": "completed", "collected": 0,
            "daily_total": store.day_count(kwargs["now"].date().isoformat()), "target": kwargs["target"],
            "requests": 0, "route": kwargs["transport"]}


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.directory = Path(self.scratch.__enter__())

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def test_once_uses_direct_and_never_overwrites_resident_heartbeat(self):
        path = _status_path(self.directory)
        original = {"schema": STATUS_SCHEMA, "mode": "resident", "alive": True, "state": "waiting",
                    "heartbeat_at": "2026-09-20T08:00:00+08:00"}
        _write_status(path, original)
        seen = {}
        def capture(store, **kwargs):
            seen.update(kwargs)
            return success_harvest(store, **kwargs)
        answer = run_once(data_dir=self.directory, now=dt.datetime(2026, 9, 20, 9, tzinfo=TZ_SHANGHAI), harvest_fn=capture)
        self.assertEqual(answer["route"], "direct")
        self.assertEqual(seen["transport"], "direct")
        self.assertEqual(_read_status(path), original)

    def test_health_reads_only_recent_resident_heartbeat(self):
        path = _status_path(self.directory)
        now = dt.datetime(2026, 9, 20, 12, tzinfo=TZ_SHANGHAI)
        _write_status(path, {"schema": STATUS_SCHEMA, "mode": "resident", "alive": True, "state": "waiting",
            "heartbeat_at": (now - dt.timedelta(seconds=HEALTH_MAX_AGE_SECONDS - 1)).isoformat()})
        self.assertTrue(_health(path, now)[0])
        _write_status(path, {"schema": STATUS_SCHEMA, "mode": "resident", "alive": True, "state": "waiting",
            "heartbeat_at": (now - dt.timedelta(seconds=HEALTH_MAX_AGE_SECONDS + 1)).isoformat()})
        self.assertFalse(_health(path, now)[0])

    def test_restart_obeys_persisted_due_gate_and_utc8_day(self):
        clock = Clock(dt.datetime(2026, 9, 20, 23, 50, tzinfo=TZ_SHANGHAI))
        due = clock.now() + dt.timedelta(seconds=120)
        _write_status(_status_path(self.directory), {"schema": STATUS_SCHEMA, "mode": "resident", "alive": True,
            "state": "waiting", "attempt_day": "2026-09-20", "attempt_count": 1,
            "next_due_at": due.isoformat(), "heartbeat_at": clock.now().isoformat()})
        calls = []
        def capture(store, **kwargs):
            calls.append(kwargs["now"])
            return success_harvest(store, **kwargs)
        run_worker(data_dir=self.directory, logs_dir=self.directory / "logs", now_fn=clock.now,
                   sleep_fn=clock.sleep, harvest_fn=capture, max_cycles=1)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0], due)
        self.assertTrue(clock.sleeps and max(clock.sleeps) <= 60)

    def test_daily_attempt_cap_prevents_restart_retry_storm(self):
        now = dt.datetime(2026, 9, 20, 10, tzinfo=TZ_SHANGHAI)
        _write_status(_status_path(self.directory), {"schema": STATUS_SCHEMA, "mode": "resident", "alive": True,
            "state": "waiting", "attempt_day": "2026-09-20", "attempt_count": 8,
            "next_due_at": (now - dt.timedelta(seconds=1)).isoformat(), "heartbeat_at": now.isoformat()})
        calls = []
        run_worker(data_dir=self.directory, logs_dir=self.directory / "logs", now_fn=lambda: now,
                   sleep_fn=lambda _: self.fail("cap must stop before sleep"),
                   harvest_fn=lambda *_args, **_kwargs: calls.append(1) or {}, max_cycles=0)
        self.assertEqual(calls, [])
        self.assertEqual(_read_status(_status_path(self.directory))["state"], "stopped")

    def test_shutdown_publishes_non_live_status(self):
        stop = threading.Event()
        stop.set()
        now = dt.datetime(2026, 9, 20, 10, tzinfo=TZ_SHANGHAI)
        run_worker(data_dir=self.directory, logs_dir=self.directory / "logs", now_fn=lambda: now,
                   sleep_fn=lambda _: None, harvest_fn=success_harvest, stop_event=stop)
        status = _read_status(_status_path(self.directory))
        self.assertFalse(status["alive"])
        self.assertEqual(status["state"], "stopped")

    def test_os_lock_singleton_releases_without_sqlite_lease_ttl(self):
        first = _WorkerLock(self.directory / "worker.lock")
        second = _WorkerLock(self.directory / "worker.lock")
        self.assertTrue(first.acquire())
        self.assertFalse(second.acquire())
        first.release()
        self.assertTrue(second.acquire())
        second.release()
        # A pre-existing long SQLite lease from a dead worker is deliberately
        # ignored: the process-owned OS lock is the singleton authority.
        from harvest import HarvestStore
        store = HarvestStore(self.directory / "harvest.sqlite")
        self.assertTrue(store.acquire_lease("worker:resident", "dead", seconds=99_999))
        stopped = threading.Event()
        stopped.set()
        answer = run_worker(data_dir=self.directory, logs_dir=self.directory / "logs",
                            now_fn=lambda: dt.datetime(2026, 9, 20, 10, tzinfo=TZ_SHANGHAI),
                            stop_event=stopped)
        self.assertEqual(answer["state"], "stopped")

    def test_attempt_slot_is_reserved_before_network_work(self):
        now = dt.datetime(2026, 9, 20, 10, tzinfo=TZ_SHANGHAI)
        path = _status_path(self.directory)
        observed = []
        def simulated_crash(_store, **_kwargs):
            observed.append(_read_status(path))
            raise KeyboardInterrupt("simulate abrupt process termination")
        with self.assertRaises(KeyboardInterrupt):
            run_worker(data_dir=self.directory, logs_dir=self.directory / "logs", now_fn=lambda: now,
                       sleep_fn=lambda _: None, harvest_fn=simulated_crash, max_cycles=1)
        checkpoint = observed[0]
        self.assertEqual(checkpoint["state"], "running")
        self.assertEqual(checkpoint["attempt_count"], 1)
        self.assertEqual(checkpoint["next_due_at"], (now + dt.timedelta(hours=3)).isoformat())

    def test_event_wait_wakes_promptly_for_shutdown(self):
        stop = threading.Event()
        now = dt.datetime.now(TZ_SHANGHAI).replace(microsecond=0)
        _write_status(_status_path(self.directory), {"schema": STATUS_SCHEMA, "mode": "resident", "alive": True,
            "state": "waiting", "attempt_day": now.date().isoformat(), "attempt_count": 1,
            "next_due_at": (now + dt.timedelta(minutes=5)).isoformat(), "heartbeat_at": now.isoformat()})
        result = []
        thread = threading.Thread(target=lambda: result.append(run_worker(
            data_dir=self.directory, logs_dir=self.directory / "logs", now_fn=lambda: dt.datetime.now(TZ_SHANGHAI),
            harvest_fn=success_harvest, stop_event=stop)), daemon=True)
        thread.start()
        time.sleep(0.05)
        stop.set()
        thread.join(2)
        self.assertFalse(thread.is_alive())
        self.assertEqual(result[0]["state"], "stopped")
        self.assertFalse(_read_status(_status_path(self.directory))["alive"])


if __name__ == "__main__":
    unittest.main()
