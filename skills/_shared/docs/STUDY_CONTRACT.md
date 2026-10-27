# StudyContract byte binding

All declarative R/Python CLI specifications share two optional controls:

- `--study-contract <path>`: local regular JSON file, at most 1 MiB, validated
  against StudyContract v1 and publication semantic rules before computation.
  The engine hashes the exact UTF-8 bytes; formatting changes change the hash.
- `--study-contract-sha256 <string>`: optional assertion on those same bytes,
  never an alternative to the file. Supplying a hash alone is refused.

No flags means legacy behavior. A supplied contract must agree with an upstream
handoff's non-null contract_hash. The validated binding is re-read at handoff
emission; changed bytes or an engine-supplied contradictory hash are refused.
The parser clears the process-local binding at each non-help parse, so one run
cannot inherit another run's contract accidentally. No expected value is inferred.

MCP accepts a contract object, validates it before allocating a run, writes a
canonical sorted-key UTF-8 file, and passes its path to the engine. Supplying
both MCP object and CLI contract flags is a conflict. `omicstat_create_study_contract`
creates only explicit declarations and returns path/sha256/object. It does not
choose design, experimental unit, estimand or exclusions on the user's behalf.

R delegates the same schema/semantic validation to the suite's Python validator;
Python3 is required only when the optional contract is supplied. JSON-schema validation runs on the host/MCP side (jsonschema is pinned in mcp/requirements.txt); inside an engine image a missing jsonschema import only warns and never refuses, while the byte hash binding and semantic checks still run.
Missing dependencies fail closed and must be included in the candidate image,
not silently accepted. Existing sealed files and legacy golden bytes stay frozen.
