"""Bind owner-review figures to registered, hash-checked real fixture inputs.

This verifies an executed fixture receipt, canonical input arguments, current
source scripts, numeric outputs and every plotted artifact. It does not fetch
data, run an engine, infer a dataset name, or bless legacy/synthetic figures.
"""
from __future__ import annotations
import hashlib
import json
import pathlib
import re
from .common import load, sha, safe_rel, dump, replay_inventory

REGISTRY = "acceptance/data/owner_review_datasets.json"


def _file(root, relative):
    root = pathlib.Path(root).resolve()
    if not isinstance(relative, str) or not relative:
        raise ValueError("owner-review evidence needs a relative file path")
    relative = safe_rel(relative)
    path = root / relative
    if (not relative or relative == "." or path.is_symlink()
            or any(p.is_symlink() for p in path.parents if p != root and p.is_relative_to(root))
            or not path.is_file() or not path.resolve().is_relative_to(root)):
        raise ValueError("owner-review evidence file missing/unsafe: " + relative)
    return path


def _digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                      ensure_ascii=False, allow_nan=False).encode()).hexdigest()


def dataset(root, module, dataset_id):
    registry_path = _file(root, REGISTRY)
    registry = load(registry_path)
    if registry.get("schema") != "omicstat.owner-review-datasets.v1":
        raise ValueError("unknown owner dataset registry")
    refs = registry.get("registration_files_sha256")
    if not isinstance(refs, dict) or not refs:
        raise ValueError("dataset registration has no source bindings")
    for path, digest in refs.items():
        if sha(_file(root, path)) != digest:
            raise ValueError("official dataset registration changed: " + path)
    matches = [x for x in registry.get("datasets", []) if x.get("id") == dataset_id]
    if len(matches) != 1:
        raise ValueError("dataset must identify one registered official example")
    data = matches[0]
    if data.get("kind") != "registered_real" or module not in data.get("modules", []):
        raise ValueError("synthetic/unregistered dataset or wrong module is not owner-review evidence")
    if not isinstance(data.get("label"), str) or not data["label"].strip():
        raise ValueError("dataset label is required on every owner figure")
    sources = data.get("sources")
    if (not isinstance(sources, list) or not sources
            or len({x.get("key") for x in sources}) != len(sources)):
        raise ValueError("dataset needs unique registered source keys")
    for source in sources:
        if not re.fullmatch(r"[0-9a-f]{64}", source.get("sha256", "")):
            raise ValueError("dataset source SHA256 is not resolved")
    return data, sha(registry_path)


def artifact_hashes(run, records):
    from .figures import inspect_figures
    # The caller may not substitute an unchecked record or omit a plotted panel.
    if records != inspect_figures(run):
        raise ValueError("owner figure inventory differs from current complete inspection")
    figures = {}
    for record in records:
        if not record.get("lint", {}).get("ok"):
            raise ValueError("owner figure has unresolved spec/lint problems")
        for path in (record["path"], record["spec"]):
            figures[path] = sha(_file(run, path))
        if figures[record["path"]] != record["sha256"]:
            raise ValueError("figure changed after inspection")
    tables = {p.relative_to(run).as_posix(): sha(_file(run, p.relative_to(run).as_posix()))
              for p in sorted((pathlib.Path(run) / "tables").glob("*.csv"))}
    if not figures or not tables:
        raise ValueError("owner review needs real plotted artifacts and numeric tables")
    return {**tables, **figures}


def _source_paths(root, module, fixture):
    paths = ["skills/" + module + "/module.json", "skills/" + module + "/tests/acceptance.json"]
    module_doc = load(_file(root, paths[0]))
    paths.append("skills/" + module + "/" + safe_rel(module_doc["entry"]))
    paths.extend("skills/" + module + "/" + safe_rel(x["script"]) for x in fixture.get("prepare", []))
    # Engine entry scripts load local cores and shared implementation. Bind those
    # bytes too, rather than attesting only a thin CLI wrapper.
    for folder in (pathlib.Path(root) / "skills" / module / "scripts",
                   pathlib.Path(root) / "skills/_shared/scripts",
                   pathlib.Path(root) / "skills/_shared/py/ospy"):
        for path in sorted(folder.rglob("*")):
            if path.is_file() and path.suffix in (".R", ".py", ".json"):
                paths.append(path.relative_to(root).as_posix())
    return sorted(set(paths))


def source_hashes(root, module, fixture):
    return {p: sha(_file(root, p)) for p in _source_paths(root, module, fixture)}


def input_snapshot(fixtures, fixture):
    declaration = fixture.get("owner_review")
    if not declaration:
        return None
    receipt_path = _file(fixtures, declaration.get("receipt"))
    receipt = load(receipt_path)
    inputs = receipt.get("prepared_inputs", [])
    if not inputs or len({x.get("path") for x in inputs}) != len(inputs):
        raise ValueError("owner fixture needs unique canonical prepared inputs")
    result = {}
    for item in inputs:
        path = _file(fixtures, item.get("path"))
        digest = sha(path)
        if digest != item.get("sha256") or path.stat().st_size != item.get("bytes"):
            raise ValueError("prepared canonical input changed: " + item["path"])
        result[item["path"]] = digest
    return {"receipt": declaration["receipt"], "receipt_sha256": sha(receipt_path), "inputs_sha256": result}


def _execution(root, module, fixture, execution_root, expected_command, fixtures, run):
    path = _file(execution_root, "canonical_execution.json")
    execution = load(path)
    command = execution.get("command", [])
    runner_argv = execution.get("runner_argv", [])
    if (execution.get("schema") != "omicstat.canonical-execution.v1"
            or execution.get("returncode") != 0 or execution.get("timed_out") is not False
            or not command or command != expected_command
            or runner_argv[-len(command):] != command):
        raise ValueError("owner figures require the successful bound canonical execution")
    log = _file(execution_root, execution.get("log"))
    if (sha(log) != execution.get("log_sha256")
            or not log.read_text().startswith("ARGV " + repr(runner_argv) + "\nRETURN 0\n")):
        raise ValueError("canonical execution log changed or does not show success")
    if execution.get("source_scripts_sha256") != source_hashes(root, module, fixture):
        raise ValueError("source changed after canonical execution")
    if execution.get("input_snapshot") != input_snapshot(fixtures, fixture):
        raise ValueError("prepared inputs/receipt differ from bytes supplied to the actual canonical run")
    if execution.get("artifacts_sha256") != replay_inventory(pathlib.Path(run)):
        raise ValueError("numeric/figure artifacts changed after canonical execution")
    rendered = execution.get("renderer")
    if rendered is not None:
        renderer_log = _file(execution_root, rendered.get("log"))
        if (rendered.get("returncode") != 0 or rendered.get("timed_out") is not False
                or sha(renderer_log) != rendered.get("log_sha256")
                or not renderer_log.read_text().startswith("ARGV " + repr(rendered.get("argv")) + "\nRETURN 0\n")):
            raise ValueError("shared R render execution log changed or failed")
    return execution, sha(path)


def bind_run(root, module, fixtures, run, records, fixture, canonical_argv, input_argv, destination,
             *, execution_root, expected_command):
    """Called only after this Pipeline's canonical engine execution succeeded."""
    declaration = fixture.get("owner_review")
    receipt_file = _file(fixtures, (declaration or {}).get("receipt", ""))
    receipt = load(receipt_file)
    # Bind arguments in separate evidence, never rewrite an executed receipt.
    data, registry_sha = dataset(root, module, (declaration or {}).get("dataset_id"))
    expected_sources = {x["key"]: x["sha256"] for x in data["sources"]}
    if (receipt.get("schema") != "omicstat.owner-dataset-receipt.v1"
            or receipt.get("dataset_id") != data["id"] or receipt.get("kind") != "registered_real"):
        raise ValueError("owner dataset receipt identity differs")
    sources = receipt.get("source_files", [])
    if len(sources) != len(expected_sources) or {x.get("key"): x.get("sha256") for x in sources} != expected_sources:
        raise ValueError("fixture did not verify exactly the registered real source bytes")
    inputs = receipt.get("prepared_inputs", [])
    if not inputs or len({x.get("path") for x in inputs}) != len(inputs):
        raise ValueError("fixture receipt needs unique prepared inputs")
    for item in inputs:
        path = _file(fixtures, item["path"])
        if sha(path) != item.get("sha256") or path.stat().st_size != item.get("bytes"):
            raise ValueError("prepared canonical input changed: " + item["path"])
        if input_argv.get(item["path"]) not in canonical_argv:
            raise ValueError("prepared real input is not bound to the canonical invocation")
    execution, execution_sha = _execution(root, module, fixture, execution_root, expected_command, fixtures, run)
    if canonical_argv != execution["command"][2:]:
        raise ValueError("canonical fixture arguments differ from the actual execution")
    result = {"schema": "omicstat.owner-run-evidence.v1", "module": module,
              "dataset_id": data["id"], "dataset_label": data["label"], "kind": "registered_real",
              "registry_sha256": registry_sha, "dataset_definition_sha256": _digest(data),
              "receipt_sha256": sha(receipt_file), "source_files": sources,
              "prepared_inputs": inputs, "canonical_argv": canonical_argv,
              "canonical_input_argv": input_argv,
              "source_scripts_sha256": execution["source_scripts_sha256"],
              "canonical_execution_sha256": execution_sha,
              "artifacts_sha256": artifact_hashes(pathlib.Path(run), records),
              "figure_datasets": {r["path"]: data["id"] for r in records},
              "visual_review": None, "scientific_anchor_results_certified": False}
    dump(destination, result)
    return result


def verify_run(root, module, fixtures, run, records, fixture, evidence_path,
               *, execution_root, expected_command):
    evidence = load(evidence_path)
    execution, execution_sha = _execution(root, module, fixture, execution_root, expected_command, fixtures, run)
    if (execution_sha != evidence.get("canonical_execution_sha256")
            or evidence.get("canonical_argv") != execution["command"][2:]):
        raise ValueError("owner evidence canonical execution binding differs")
    data, registry_sha = dataset(root, module, evidence.get("dataset_id"))
    if (evidence.get("schema") != "omicstat.owner-run-evidence.v1" or evidence.get("module") != module
            or evidence.get("kind") != "registered_real" or evidence.get("registry_sha256") != registry_sha
            or evidence.get("dataset_definition_sha256") != _digest(data)
            or evidence.get("dataset_label") != data["label"]):
        raise ValueError("owner run evidence identity/registration drift")
    receipt_path = _file(fixtures, fixture["owner_review"]["receipt"])
    receipt = load(receipt_path)
    if sha(receipt_path) != evidence.get("receipt_sha256"):
        raise ValueError("executed owner fixture receipt changed")
    expected_sources = {x["key"]: x["sha256"] for x in data["sources"]}
    sources = receipt.get("source_files", [])
    if (receipt.get("schema") != "omicstat.owner-dataset-receipt.v1"
            or receipt.get("kind") != "registered_real" or receipt.get("dataset_id") != data["id"]
            or fixture["owner_review"].get("dataset_id") != data["id"]
            or len(sources) != len(expected_sources)
            or {x.get("key"): x.get("sha256") for x in sources} != expected_sources):
        raise ValueError("owner receipt does not match registered real source bytes")
    if receipt.get("source_files") != evidence.get("source_files") or receipt.get("prepared_inputs") != evidence.get("prepared_inputs"):
        raise ValueError("owner fixture receipt differs from run binding")
    inputs = evidence.get("prepared_inputs", [])
    if not inputs or len({x.get("path") for x in inputs}) != len(inputs):
        raise ValueError("owner evidence has no unique canonical inputs")
    for item in inputs:
        path = _file(fixtures, item["path"])
        if sha(path) != item.get("sha256") or path.stat().st_size != item.get("bytes"):
            raise ValueError("prepared owner input changed after the run")
        if evidence.get("canonical_input_argv", {}).get(item["path"]) not in evidence.get("canonical_argv", []):
            raise ValueError("real input is not bound to canonical arguments")
    if sorted(evidence.get("source_scripts_sha256", {})) != _source_paths(root, module, fixture):
        raise ValueError("owner evidence omits executed source bindings")
    for path, digest in evidence.get("source_scripts_sha256", {}).items():
        if sha(_file(root, path)) != digest:
            raise ValueError("owner run source script changed")
    if artifact_hashes(pathlib.Path(run), records) != evidence.get("artifacts_sha256"):
        raise ValueError("owner numeric or figure artifact changed after binding")
    if evidence.get("figure_datasets") != {r["path"]: data["id"] for r in records}:
        raise ValueError("each owner figure must identify its registered dataset")
    return data
