"""Read-only R archive identity and owner-bounded PPM binary policy.

The policy permits the reviewed noble/2026-09-15 Linux artifacts only.  A
declaration does not prove that the bytes, parent image or runtime are present.
No function in this module downloads, extracts, installs or builds anything.
"""
from __future__ import annotations

import json
import pathlib
import re
import tarfile
import urllib.parse

APPROVED_SNAPSHOT = "https://p3m.dev/cran/__linux__/noble/2026-09-15"
APPROVED_PLATFORM = "linux/amd64"
MAX_ARCHIVE_BYTES = 256 * 1024**2
MAX_MEMBERS = 100000
MAX_UNPACKED_BYTES = 1024**3


def https_url(value):
    if not isinstance(value, str):
        raise ValueError("archive URL must be text")
    u = urllib.parse.urlsplit(value)
    if (u.scheme != "https" or not u.hostname or u.username or u.password
            or u.fragment or u.query or u.port is not None):
        raise ValueError("archive needs HTTPS without credentials, port, query or fragment")
    return value


def record_policy(row):
    """Require an explicit kind; never infer one from a .tar.gz suffix."""
    if row.get("kind") not in ("source", "ppm_binary"):
        raise ValueError("R archive kind must be source or ppm_binary")
    for key in ("package", "version", "filename", "url", "sha256"):
        if not isinstance(row.get(key), str) or not row[key]:
            raise ValueError("unresolved archive field: " + key)
    name = pathlib.PurePosixPath(row["filename"])
    if name.name != row["filename"] or row["filename"] in (".", "..") or "\\" in row["filename"]:
        raise ValueError("flat archive filename required")
    if not re.fullmatch(r"[0-9a-f]{64}", row["sha256"]):
        raise ValueError("archive needs a full locked SHA256")
    https_url(row["url"])
    host = urllib.parse.urlsplit(row["url"]).hostname
    if host == "bioconductor.org" or host.endswith(".bioconductor.org"):
        if row["kind"] != "source":
            raise ValueError("Bioconductor archives must remain source")
    if row["kind"] == "ppm_binary":
        if row.get("ppm_snapshot_url") != APPROVED_SNAPSHOT:
            raise ValueError("PPM binary snapshot must be the owner-approved noble/2026-09-15 snapshot")
        if row.get("platform") != APPROVED_PLATFORM:
            raise ValueError("PPM binary platform must match reviewed linux/amd64 parent")
        if row["url"] != APPROVED_SNAPSHOT + "/src/contrib/" + row["filename"]:
            raise ValueError("PPM binary URL is outside the exact locked snapshot")
    return row


def candidate_policy(manifest, rows, root):
    """Bind binary declarations to the authoritative unchanged parent metadata."""
    for row in rows:
        record_policy(row)
    if not any(row["kind"] == "ppm_binary" for row in rows):
        return None
    policy = manifest.get("r_artifact_policy")
    if not isinstance(policy, dict) or policy.get("schema") != "omicstat.r-artifact-policy.v1":
        raise ValueError("PPM binary needs an explicit parent-bound artifact policy")
    config = json.loads((pathlib.Path(root) / "env/r-env.json").read_text())
    image_id = (pathlib.Path(root) / "env/image_id.txt").read_text().strip()
    # Reviewed candidate parents remain fixed when the production pointer moves.
    # Only repository-recorded baselines may supply historical metadata.
    if manifest.get("base_image") != config["image"] + ":" + config["image_tag"]:
        for path in sorted((pathlib.Path(root) / "env/r-baselines").glob("*.json")):
            baseline = json.loads(path.read_text())
            if manifest.get("base_image") == baseline["image"] + ":" + baseline["image_tag"]:
                config, image_id = baseline, baseline["image_id"]
                break
    if (manifest.get("base_image") != config["image"] + ":" + config["image_tag"]
            or manifest.get("base_image_id") != image_id
            or policy.get("parent_image_id") != image_id):
        raise ValueError("PPM binary parent image identity differs from reviewed baseline")
    if (config.get("cran_repo_linux") != APPROVED_SNAPSHOT
            or config.get("cran_snapshot") != "2026-09-15"
            or policy.get("ppm_snapshot_url") != APPROVED_SNAPSHOT
            or policy.get("platform") != APPROVED_PLATFORM
            or policy.get("distribution") != "noble"):
        raise ValueError("PPM binary parent snapshot/platform policy mismatch")
    if policy.get("r_version") != config.get("r_version"):
        raise ValueError("PPM binary parent R version policy mismatch")
    return policy


def _fields(text):
    fields = {}
    key = None
    for line in text.splitlines():
        if line[:1].isspace() and key:
            fields[key] += " " + line.strip()
        elif ":" in line:
            key, value = line.split(":", 1)
            if key in fields:
                raise ValueError("duplicate DESCRIPTION field: " + key)
            fields[key] = value.strip()
    return fields


def inspect_archive(path, row=None, policy=None):
    """Inspect bounded regular metadata only; never deserialize package.rds."""
    path = pathlib.Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_ARCHIVE_BYTES:
        raise ValueError("archive missing, unsafe or over size bound")
    if row is not None:
        record_policy(row)
    with tarfile.open(path, "r:*") as archive:
        names = set()
        descriptions = []
        binary_markers = []
        native_members = []
        roots = set()
        total = 0
        for i, member in enumerate(archive):
            p = pathlib.PurePosixPath(member.name)
            if (i >= MAX_MEMBERS or p.is_absolute() or ".." in p.parts
                    or "\\" in member.name or member.name in names
                    or member.issym() or member.islnk()
                    or not (member.isfile() or member.isdir())):
                raise ValueError("unsafe or duplicate archive member")
            names.add(member.name)
            if not p.parts:
                raise ValueError("empty archive member")
            roots.add(p.parts[0])
            total += member.size
            if total > MAX_UNPACKED_BYTES:
                raise ValueError("archive exceeds unpacked size bound")
            if re.fullmatch(r"[^/]+/DESCRIPTION", member.name):
                if not member.isfile() or member.size > 1024**2:
                    raise ValueError("archive needs a bounded regular DESCRIPTION")
                descriptions.append(archive.extractfile(member).read().decode("utf-8"))
            if re.fullmatch(r"[^/]+/Meta/package\.rds", member.name):
                binary_markers.append(member.name)
            if (re.search(r"^[^/]+/libs(?:/|$)", member.name, re.I)
                    or re.search(r"\.(?:so(?:\.\d+)*|dll|dylib|a|o)$", member.name, re.I)):
                native_members.append(member.name)
        if len(descriptions) != 1:
            raise ValueError("archive needs one bounded DESCRIPTION")
    fields = _fields(descriptions[0])
    if len(roots) != 1 or roots != {fields.get("Package")}:
        raise ValueError("archive must contain exactly its declared package directory")
    kind = row["kind"] if row else "source"
    if kind == "source":
        if binary_markers or "Built" in fields:
            raise ValueError("installed binary package is not a source archive")
    else:
        if not policy or not binary_markers or "Built" not in fields:
            raise ValueError("PPM binary needs installed metadata and verified parent policy")
        built = [s.strip() for s in fields["Built"].split(";")]
        expected_r = ".".join(policy["r_version"].split(".")[:2])
        # R omits Built's platform for installed pure-R packages. This does
        # not relax the independently locked URL, parent image or runtime.
        pure_r_empty_platform = (len(built) >= 2 and built[1] == ""
                                 and fields.get("NeedsCompilation") == "no"
                                 and not native_members)
        if (len(built) < 4 or not re.fullmatch(r"R " + re.escape(expected_r) + r"\.\d+", built[0])
                or not (pure_r_empty_platform or re.fullmatch(r"x86_64-[A-Za-z0-9_-]+-linux-gnu", built[1]))
                or built[3] != "unix"
                or tuple(map(int, built[0][2:].split("."))) > tuple(map(int, policy["r_version"].split(".")))):
            raise ValueError("PPM binary Built R/platform metadata differs from parent")
    if row and (fields.get("Package") != row["package"] or fields.get("Version") != row["version"]):
        raise ValueError("archive package/version mismatch")
    return fields


def verify_parent_image(image, policy):
    if not policy:
        return
    if (image.get("Id") != policy["parent_image_id"]
            or str(image.get("Os", "")) + "/" + str(image.get("Architecture", "")) != policy["platform"]):
        raise ValueError("actual parent image platform/identity differs from PPM binary policy")


def verify_parent_runtime(runtime, policy):
    if not policy:
        return
    if (runtime.get("cran_repo") != policy["ppm_snapshot_url"]
            or runtime.get("distribution") != policy["distribution"]
            or runtime.get("r_version") != policy["r_version"]
            or not re.fullmatch(r"x86_64-[A-Za-z0-9_-]+-linux-gnu", runtime.get("r_platform", ""))):
        raise ValueError("actual parent runtime snapshot/distribution/R differs from PPM binary policy")


PARENT_PROBE_R = '''os <- readLines("/etc/os-release", warn=FALSE)
d <- sub('^VERSION_CODENAME=', '', os[grepl('^VERSION_CODENAME=', os)])
d <- gsub('"', '', d, fixed=TRUE)
cat(jsonlite::toJSON(list(cran_repo=unname(getOption("repos")[["CRAN"]]),
 distribution=if(length(d)==1L)d else "", r_version=as.character(getRversion()),
 r_platform=R.version$platform), auto_unbox=TRUE))'''
