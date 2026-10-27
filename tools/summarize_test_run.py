#!/usr/bin/env python3
"""Summarize completed suite commands without treating internal SKIP messages as runner skips.

The ledger records process exit codes, not individual scientific assertions or
production acceptance. Log contents are deliberately excluded from the JSON.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re


def summarize(folder: Path) -> dict:
    folder = Path(folder)
    output = (folder / "output.log").read_text(encoding="utf-8")
    lines = output.splitlines()
    terminal = [line for line in lines if line.startswith("== done:")]
    if len(terminal) != 1 or terminal[0] != next((line for line in reversed(lines) if line.strip()), ""):
        raise ValueError("Expected one terminal runner result at the end of output.log")
    r_result = re.fullmatch(r"== done: (ALL PASSED|FAILURES) \((\d+) skipped for missing packages\)", terminal[0])
    py_result = re.fullmatch(r"== done: (ALL PASSED|FAILURES) \((\d+) commands\)", terminal[0])
    if not r_result and not py_result:
        raise ValueError("Unrecognized runner result; no counts inferred")
    records = []
    seen = set()
    for line in (folder / "logs/status.tsv").read_text(encoding="utf-8").splitlines():
        index, exit_code, command = line.split("\t", 2)
        if not re.fullmatch(r"\d{3,}", index) or int(index) in seen:
            raise ValueError("Invalid or duplicate command index")
        seen.add(int(index))
        code = int(exit_code)
        if not 0 <= code <= 255 or not command:
            raise ValueError("Invalid process result")
        log_path = folder / "logs" / (index + ".log")
        raw = log_path.read_bytes()
        records.append({"index": int(index), "exit_code": code, "command": command,
                        "log": "logs/" + index + ".log", "log_sha256": hashlib.sha256(raw).hexdigest(),
                        "internal_skip_messages": sum(x.startswith("SKIP:") for x in raw.decode("utf-8", errors="replace").splitlines())})
    if [r["index"] for r in records] != list(range(1, len(records) + 1)):
        raise ValueError("Command ledger is not complete and contiguous")
    index_lines = (folder / "logs/index.tsv").read_text(encoding="utf-8").splitlines()
    expected = [f'{r["index"]:03d}\t{r["command"]}' for r in records]
    if index_lines != expected:
        raise ValueError("Command index differs from exit-code ledger")
    nonzero = sum(r["exit_code"] != 0 for r in records)
    result = r_result or py_result
    assert result is not None
    if (result[1] == "FAILURES") != bool(nonzero):
        raise ValueError("Runner verdict disagrees with command exit codes")
    if py_result and int(py_result[2]) != len(records):
        raise ValueError("Python runner command count disagrees with ledger")
    return {
        "schema": "omicstat.developer-command-summary.v1",
        "lane": "R" if r_result else "py",
        "runner_verdict": result[1],
        "executed_commands": len(records),
        "commands_exit_zero": len(records) - nonzero,
        "commands_nonzero": nonzero,
        "runner_missing_package_skips": int(r_result[2]) if r_result else 0,
        "output_skip_messages": sum(line.startswith("SKIP:") for line in lines),
        "internal_command_skip_messages": sum(r["internal_skip_messages"] for r in records),
        "counts_are_scientific_assertions": False,
        "production_acceptance": "not_verified",
        "log_contents_included": False,
        "output_log_sha256": hashlib.sha256((folder / "output.log").read_bytes()).hexdigest(),
        "commands": records,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = summarize(args.folder)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
