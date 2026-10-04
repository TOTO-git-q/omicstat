"""Workspace-scoped synthetic fixture directories with inherited Windows ACLs."""
from contextlib import contextmanager
from pathlib import Path
import shutil
import uuid
import os


@contextmanager
def scratch_directory():
    base = Path(os.environ.get("OMICSTAT_REFERENCE_TEST_SCRATCH", str(Path(__file__).resolve().parents[1] / ".test-scratch"))).resolve()
    target = base / uuid.uuid4().hex
    target.mkdir(parents=True)
    try:
        yield str(target)
    finally:
        resolved = target.resolve()
        if resolved.parent != base or len(resolved.name) != 32:
            raise RuntimeError("refusing cleanup outside isolated test fixture directory")
        shutil.rmtree(resolved)
