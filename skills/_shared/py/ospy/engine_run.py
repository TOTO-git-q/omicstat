"""engine_run.py -- capture every warning and message an engine stage raises.

Python counterpart of skills/_shared/scripts/engine_run.R (CONVENTIONS.md
sec 15):

    elog = EngineLog(outdir)                         # -> <outdir>/qc/engine_warnings.csv
    res = elog.capture("compute", compute, adata, seed=seed)
    elog.capture("render", render, res, outdir)
    # or:  with elog.stage("qc"): ...

Inside a stage
  warning  (warnings.warn, including library DeprecationWarning/FutureWarning;
           the "always" filter is used so repeats are not lost) recorded,
           echoed to stderr as "OS_ENGINE_WARNING: [<stage>] <msg>" (the MCP
           console scan picks up the OS_ prefix) and not printed a second
           time. When the process runs with warnings as errors (python -W
           error / PYTHONWARNINGS=error, the counterpart of R options(warn = 2))
           the warning is recorded and still raised as the caller asked.
  message  logging records (level INFO and above) of the root logger and of
           the scverse loggers (scanpy, anndata, scvi, lightning, ...) are
           recorded; they keep printing as their own handlers decide.
  error    recorded and the CSV flushed, then the exception propagates
           unchanged: errors are never swallowed or converted.
The CSV (columns stage, type, message; every field quoted, LF) is rewritten
after every stage and on error, so it exists even when the run dies; with no
conditions it holds the header only. Standard library only. ASCII only.
"""
import contextlib
import logging
import os
import re
import sys
import warnings

MESSAGE_LOGGERS = ("", "scanpy", "anndata", "scvi", "lightning", "lightning.pytorch", "pytorch_lightning",
                   "lightning.fabric", "py.warnings")


def _one_line(x):
    return re.sub(r"\s+", " ", str(x).strip())


def _warnings_are_errors():
    opts = list(sys.warnoptions) + [o for o in os.environ.get("PYTHONWARNINGS", "").split(",") if o]
    return any(o.split(":")[0] == "error" for o in opts)


class _Recorder(logging.Handler):
    def __init__(self, log, stage):
        super().__init__(level=logging.INFO)
        self.log, self.stage = log, stage

    def emit(self, record):
        try:
            self.log._add(self.stage, "message", record.getMessage())
        except Exception:                                      # noqa: BLE001
            pass


class EngineLog:
    def __init__(self, outdir=None, filename="engine_warnings.csv"):
        self.rows = []
        self.path = None if outdir is None else os.path.join(outdir, "qc", filename)
        self._last_error = None

    def _add(self, stage, type_, msg):
        self.rows.append((stage, type_, _one_line(msg)))

    def counts(self):
        return {t: sum(1 for r in self.rows if r[1] == t) for t in ("warning", "message", "error")}

    def write(self):
        if self.path is None:
            return None
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        q = lambda s: '"' + s.replace('"', '""') + '"'           # noqa: E731
        lines = [",".join(q(c) for c in ("stage", "type", "message"))]
        lines += [",".join(q(c) for c in r) for r in self.rows]
        with open(self.path, "wb") as fh:
            fh.write(("\n".join(lines) + "\n").encode("utf-8"))
        return self.path

    @contextlib.contextmanager
    def stage(self, stage):
        as_error = _warnings_are_errors()
        handlers = []
        for name in MESSAGE_LOGGERS:
            h = _Recorder(self, stage)
            logging.getLogger(name).addHandler(h)
            handlers.append((name, h))
        old_show = warnings.showwarning

        def show(message, category, filename, lineno, file=None, line=None):
            msg = "%s: %s" % (category.__name__, message)
            self._add(stage, "warning", msg)
            sys.stderr.write("OS_ENGINE_WARNING: [%s] %s\n" % (stage, _one_line(msg)))
            sys.stderr.flush()

        try:
            with warnings.catch_warnings():
                if as_error:
                    warnings.simplefilter("error")
                else:
                    warnings.simplefilter("always")
                warnings.showwarning = show
                try:
                    yield self
                except Warning as w:
                    if as_error:
                        self._add(stage, "warning", "%s: %s" % (type(w).__name__, w))
                    raise
        except BaseException as exc:
            if exc is not self._last_error:
                self._last_error = exc
                self._add(stage, "error", "%s: %s" % (type(exc).__name__, exc))
                self.write()
            raise
        finally:
            warnings.showwarning = old_show
            for name, h in handlers:
                logging.getLogger(name).removeHandler(h)
            self.write()

    def capture(self, stage, fn, *args, **kwargs):
        with self.stage(stage):
            return fn(*args, **kwargs)
