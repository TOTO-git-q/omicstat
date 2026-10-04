#!/usr/bin/env python3
"""Split env/py_lock.txt into the wheel part and the sdist-only part.

Usage: python split_lock.py <py_lock.txt> <uv.lock> <out_wheels.txt> <out_sdists.txt>

A package is sdist-only when uv.lock records no wheel for it (docrep 0.3.2 is
the only one in 2026.09.1). Both outputs keep every requirement exactly as
exported, hashes included, so `pip install --require-hashes` still refuses any
file that is not in the lock. Standard library only (runs on the bare base
image before the venv exists). ASCII only.
"""
import re
import sys
import tomllib


def entries(text):
    """Requirement blocks of a `uv export` file: (name, block text)."""
    out, cur = [], []
    for line in text.splitlines():
        if re.match(r"^[A-Za-z0-9]", line):
            if cur:
                out.append(cur)
            cur = [line]
        elif cur and line.startswith("    --hash="):
            cur.append(line)
        # comments ("# via ...") and blank lines are dropped
    if cur:
        out.append(cur)
    blocks = []
    for b in out:
        name = re.split(r"[=<>!~ ;\[]", b[0], maxsplit=1)[0].lower().replace("_", "-")
        blocks.append((name, "\n".join(b)))
    return blocks


def sdist_only(uv_lock_path):
    with open(uv_lock_path, "rb") as fh:
        lock = tomllib.load(fh)
    names = set()
    for pkg in lock.get("package", []):
        src = pkg.get("source", {})
        if "virtual" in src or "editable" in src:
            continue
        if not pkg.get("wheels") and pkg.get("sdist"):
            names.add(pkg["name"].lower().replace("_", "-"))
    return names


def main(argv):
    if len(argv) != 4:
        sys.exit(__doc__)
    lock_txt, uv_lock, out_w, out_s = argv
    with open(lock_txt, encoding="utf-8") as fh:
        blocks = entries(fh.read())
    if not blocks:
        sys.exit("OS_INVALID_INPUT: no requirement found in %s" % lock_txt)
    bad = [n for n, b in blocks if "--hash=sha256:" not in b]
    if bad:
        sys.exit("OS_INVALID_INPUT: requirement(s) without a sha256 hash: %s" % ", ".join(bad))
    sd = sdist_only(uv_lock)
    wheels = [b for n, b in blocks if n not in sd]
    sdists = [b for n, b in blocks if n in sd]
    missing = sd - {n for n, _ in blocks}
    if missing:
        sys.exit("OS_INVALID_INPUT: uv.lock sdist-only package(s) absent from %s: %s" % (lock_txt, ", ".join(sorted(missing))))
    for path, part in ((out_w, wheels), (out_s, sdists)):
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(part) + ("\n" if part else ""))
    print("split %d requirements: %d wheel, %d sdist-only (%s)"
          % (len(blocks), len(wheels), len(sdists), ", ".join(sorted(sd)) or "none"))


if __name__ == "__main__":
    main(sys.argv[1:])
