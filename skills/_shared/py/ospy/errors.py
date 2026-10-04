"""errors.py -- typed OS_* errors of the Python lane (CONVENTIONS.md sec 3).

Every error a caller may act on programmatically is an OmicstatError whose
message starts with its code, exactly like the R side's
stop("OS_<CODE>: ...", call. = FALSE):

    raise os_error("OS_INVALID_PARAMETER", "--alpha: expected a finite number, got 'x'")
    -> str(exc) == "OS_INVALID_PARAMETER: --alpha: expected a finite number, got 'x'"

run_entry(main) is the Python counterpart of the R entry-script line
options(error = function() { cat(geterrmessage(), file = stderr()); quit(status = 1) }):
an OmicstatError prints its message (and nothing else) to stderr and exits 1;
any other exception prints its traceback and exits 1. Standard library only.
ASCII only.
"""
import re
import sys
import traceback

CODE_RE = re.compile(r"^OS_[A-Z0-9_]+$")


class OmicstatError(Exception):
    """An error with a machine-readable OS_* code (exc.code)."""

    def __init__(self, code, message):
        if not CODE_RE.match(code):
            raise ValueError("error codes must look like OS_[A-Z0-9_]+, got %r" % code)
        self.code = code
        self.detail = message
        super().__init__("%s: %s" % (code, message))


def os_error(code, message):
    """Build an OmicstatError (use as: raise os_error(...))."""
    return OmicstatError(code, message)


def run_entry(main, argv=None):
    """Run an entry point; map exceptions to exit status 1 with a typed message."""
    try:
        rc = main(sys.argv[1:] if argv is None else argv)
    except OmicstatError as exc:
        sys.stdout.flush()
        sys.stderr.write(str(exc) + "\n")
        sys.stderr.flush()
        sys.exit(1)
    except SystemExit:
        raise
    except BaseException:                                      # noqa: BLE001
        sys.stdout.flush()
        traceback.print_exc(file=sys.stderr)
        sys.stderr.flush()
        sys.exit(1)
    sys.exit(int(rc or 0))
