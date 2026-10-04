#!/usr/bin/env python3
"""Write the installed-distribution record of the omicstat-py image.

Usage: python write_py_installed.py <out.csv>

Columns: package (normalised name), version, installer. One row per
distribution in the running interpreter's environment, sorted by name; LF
line endings, UTF-8. build.sh copies it out of the image as
env/py/py_installed.csv (the counterpart of env/pkg_lock.csv). ASCII only.
"""
import csv
import importlib.metadata as md
import re
import sys


def norm(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def main(argv):
    if len(argv) != 1:
        sys.exit(__doc__)
    rows = {}
    for dist in md.distributions():
        name = norm(dist.metadata["Name"])
        installer = (dist.read_text("INSTALLER") or "").strip() or "unknown"
        rows[name] = (name, dist.version, installer)
    with open(argv[0], "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["package", "version", "installer"])
        for key in sorted(rows):
            w.writerow(rows[key])
    print("%d distributions recorded in %s" % (len(rows), argv[0]))


if __name__ == "__main__":
    main(sys.argv[1:])
