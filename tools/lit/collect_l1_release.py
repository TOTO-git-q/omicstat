#!/usr/bin/env python3
"""S0 layer L1 from the LOCKED Bioconductor release (ENGINEERING_PLAN 2.2 step 1).

  python3 tools/lit/collect_l1_release.py <module> <pkg,...> <fn,...> [--release 3.23]

Reads the package sources at branch RELEASE_<x_y> of the official Bioconductor git
(git.bioconductor.org/packages/<pkg>), not the web's latest version, and the
rendered vignettes of that release from bioconductor.org/packages/<release>/.
Writes acceptance/exemplars/<module>/L1_bioc<release>/<pkg>/:
  DESCRIPTION, NEWS.txt, vignettes/*.{Rmd,Rnw} + *.rendered.txt (printed values),
  Rd/<fn>.Rd, defaults.tsv (function, argument, default parsed from the Rd \\usage)
and manifest.tsv (file, sha256, package, version, release, git commit).
CRAN packages (e.g. ashr) are not on git.bioconductor.org: they are skipped with a
note and keep their dev-tier L1 export (tools/collect_l1.R).
"""
import argparse
import hashlib
import html
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sh(*cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def html_text(h: str) -> str:
    h = re.sub(r"(?s)<script.*?</script>|<style.*?</style>", "", h)
    h = re.sub(r"<(br|/p|/div|/h[1-6]|/li|/tr|/pre)[^>]*>", "\n", h)
    h = html.unescape(re.sub(r"<[^>]+>", "", h))
    return re.sub(r"\n{3,}", "\n\n", re.sub(r"\n[ \t]+\n", "\n\n", h))


def usage_defaults(rd: str, fn: str):
    """Arguments and defaults of `fn(...)` in the Rd \\usage section (S4 methods:
    \\S4method{fn}{class}(...) counts as fn)."""
    m = re.search(r"\\usage\{(.*?)\n\}", rd, re.S)
    if not m:
        return []
    u = re.sub(r"\\method\{([^}]*)\}\{[^}]*\}|\\S4method\{([^}]*)\}\{[^}]*\}", lambda x: x.group(1) or x.group(2), m.group(1))
    u = re.sub(r"%.*", "", u)
    start = re.search(r"(?<![\w.])" + re.escape(fn) + r"\s*\(", u)
    if not start:
        return []
    i, depth, j = start.end(), 1, start.end()
    while j < len(u) and depth:
        depth += {"(": 1, ")": -1}.get(u[j], 0)
        j += 1
    args, depth, cur = [], 0, ""
    for ch in u[i:j - 1]:
        if ch == "," and depth == 0:
            args.append(cur); cur = ""; continue
        depth += {"(": 1, ")": -1, "[": 1, "]": -1}.get(ch, 0)
        cur += ch
    args.append(cur)
    out = []
    for a in args:
        a = re.sub(r"\s+", " ", a).strip()
        if not a:
            continue
        k, _, v = a.partition("=")
        out.append((k.strip(), v.strip()))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("module"); ap.add_argument("pkgs"); ap.add_argument("fns")
    ap.add_argument("--release", default="3.23")
    a = ap.parse_args()
    branch = "RELEASE_" + a.release.replace(".", "_")
    out = ROOT / "acceptance" / "exemplars" / a.module / f"L1_bioc{a.release}"
    fns = a.fns.split(",")
    found = {f: False for f in fns}
    manifest = ["file\tsha256\tpackage\tversion\trelease\tgit_commit"]
    for pkg in a.pkgs.split(","):
        url = f"https://git.bioconductor.org/packages/{pkg}"
        try:
            commit = sh("git", "ls-remote", url, f"refs/heads/{branch}").split()[0]
        except (subprocess.CalledProcessError, IndexError):
            print(f"SKIP {pkg}: no {branch} on git.bioconductor.org (CRAN package?)")
            continue
        tmp = Path(tempfile.mkdtemp())
        sh("git", "clone", "-q", "--depth", "1", "-b", branch, url, str(tmp / pkg))
        src = tmp / pkg
        pd = out / pkg
        if pd.exists():
            shutil.rmtree(pd)
        (pd / "vignettes").mkdir(parents=True)
        (pd / "Rd").mkdir()
        shutil.copy(src / "DESCRIPTION", pd / "DESCRIPTION")
        version = re.search(r"^Version:\s*(\S+)", (src / "DESCRIPTION").read_text(), re.M).group(1)
        # several NEWS files can coexist (e.g. a frozen NEWS next to a current NEWS.md): take the one
        # whose newest version heading is highest (headings: "CHANGES IN VERSION x.y", "# pkg x.y",
        # "\\section{version x.y}"), else the first that exists
        def newest(path):
            vs = re.findall(r"(?:version|VERSION|^#+\s*\S+)\s*v?(\d+)\.(\d+)(?:\.(\d+))?", path.read_text(errors="replace"), re.M)
            return max((tuple(int(x or 0) for x in v) for v in vs), default=(-1,))
        news_files = [src / n for n in ("NEWS", "NEWS.md", "inst/NEWS", "inst/NEWS.Rd", "inst/NEWS.md") if (src / n).exists()]
        if news_files:
            chosen = max(news_files, key=newest)
            shutil.copy(chosen, pd / "NEWS.txt")
            (pd / "NEWS.source").write_text(f"{chosen.relative_to(src)} (newest heading {'.'.join(map(str, newest(chosen)))})\n", encoding="utf-8")
        for v in sorted((src / "vignettes").glob("*")) if (src / "vignettes").exists() else []:
            if v.suffix in (".Rmd", ".Rnw", ".qmd"):
                shutil.copy(v, pd / "vignettes" / v.name)
                page = f"https://bioconductor.org/packages/{a.release}/bioc/vignettes/{pkg}/inst/doc/{v.stem}.html"
                try:
                    with urllib.request.urlopen(page, timeout=60) as r:
                        (pd / "vignettes" / f"{v.stem}.rendered.txt").write_text(html_text(r.read().decode("utf-8", "replace")), encoding="utf-8")
                except Exception as exc:  # noqa: BLE001 -- no HTML: try the PDF build of the vignette
                    pdf_url = page[:-5] + ".pdf"
                    try:
                        import io
                        import pypdf  # retrieval venv only (tools/lit/README.md)
                        with urllib.request.urlopen(pdf_url, timeout=120) as r:
                            raw = r.read()
                        text = "\n".join((pg.extract_text() or "") for pg in pypdf.PdfReader(io.BytesIO(raw)).pages)
                        (pd / "vignettes" / f"{v.stem}.rendered.txt").write_text(
                            f"[source: {pdf_url} sha256={hashlib.sha256(raw).hexdigest()} (text extracted with pypdf)]\n\n{text}", encoding="utf-8")
                    except Exception as exc2:  # noqa: BLE001 -- recorded, not fatal
                        (pd / "vignettes" / f"{v.stem}.rendered.MISSING").write_text(f"{page}\n{exc}\n{pdf_url}\n{exc2}\n", encoding="utf-8")
        rows = ["function\targument\tdefault"]
        for rd in sorted((src / "man").glob("*.Rd")):
            text = rd.read_text(encoding="utf-8", errors="replace")
            aliases = set(re.findall(r"\\alias\{([^}]*)\}", text))
            for f in fns:
                base = f.split(".")[0] if f not in aliases else f
                if f in aliases or (f"{base}" in aliases and not found[f]):
                    if not found[f]:
                        shutil.copy(rd, pd / "Rd" / f"{f}.Rd")
                    found[f] = True
                    for k, v in usage_defaults(text, base):
                        rows.append(f"{f}\t{k}\t{v}")
        (pd / "defaults.tsv").write_text("\n".join(dict.fromkeys(rows)) + "\n", encoding="utf-8")
        for f in sorted(pd.rglob("*")):
            if f.is_file():
                manifest.append(f"{f.relative_to(out)}\t{hashlib.sha256(f.read_bytes()).hexdigest()}\t{pkg}\t{version}\t{a.release}\t{commit}")
        shutil.rmtree(tmp)
        print(f"{pkg} {version} @ {branch} {commit[:10]}")
    out.mkdir(parents=True, exist_ok=True)
    (out / "manifest.tsv").write_text("\n".join(manifest) + "\n", encoding="utf-8")
    missing = [f for f, ok in found.items() if not ok]
    if missing:
        print("functions without an Rd page in these packages:", ", ".join(missing))


if __name__ == "__main__":
    main()
