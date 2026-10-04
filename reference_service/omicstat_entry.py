#!/usr/bin/env python3
"""Reference-first entry point for the existing omicstat stdio MCP.

Copied from medstat-reference v2 ``medstat_entry.py`` (commit 07fdebd); only names,
paths and guidance text differ. This module deliberately imports the installed
omicstat shell instead of reimplementing or wrapping its analysis tools.  The original ``FastMCP``
instance remains the server instance, so the five callable tool functions,
their input schemas, return shapes, and original resources are retained.
Only guidance metadata and one read-only workflow resource are added here.
"""

from __future__ import annotations

import hashlib
import importlib.util
import os
import sys
from pathlib import Path
from types import ModuleType
from typing import Final


# Default: the omicstat MCP of the same checkout (reference_service/../mcp/server.py).
DEFAULT_ORIGINAL_SERVER: Final = str(Path(__file__).resolve().parents[1] / "mcp" / "server.py")
WORKFLOW_URI: Final = "omicstat://reference-workflow"
WORKFLOW_PATH: Final = Path(__file__).with_name("REFERENCE_WORKFLOW.md")

SERVER_INSTRUCTIONS: Final = """omicstat analysis guidance (reference-first workflow; read omicstat://reference-workflow). When the companion omicstat_reference MCP is available: (1) reference_search for the module and the study's method context - results come in three separately labelled columns: curated seed records, reviewed_supplement (curator-promoted) and discovery (unreviewed_machine_screened); never merge them or treat discovery as authority; a module with no curated evidence yet is reported as no_curated_evidence_yet, which is not an error; (2) reference_advise(module, study_contract) to find missing context and cited conditional options; (3) if the evidence is insufficient, file reference_request_literature (module = one of the omicstat modules) with research-method context only and DO NOT WAIT for it - it is queued for the resident collector and returns immediately; (4) then either continue with the existing omicstat module contract while explicitly reporting the evidence gap as reported/queued, or stop and ask the researcher. If no module fits, reference_propose_domain only registers a proposal; it does not create or support a new analysis. Never send count matrices, sample sheets, sample-level or donor/patient data or identifiers to any reference tool. A published parameter value is a study-specific observation, not a default; omicstat defaults come only from each module's PACK. If the reference MCP or GT103 is unavailable, proceed only with the existing omicstat contract and report that the reference check did not happen. omicstat_run itself never contacts the network, never waits for literature and never changes an explicit call because of reference material. These instructions guide analysis but do not block omicstat calls."""

TOOL_GUIDANCE: Final = {
    "omicstat_list_modules": (
        "\n\nReference-first guidance: read omicstat://reference-workflow and use the companion "
        "reference_search / reference_advise before selecting a module when research context is available. "
        "Search columns (curated, reviewed_supplement, discovery=unreviewed_machine_screened) are distinct "
        "evidence states. The reference is conditional research context, not a biological or clinical authority."
    ),
    "omicstat_describe": (
        "\n\nReference-first guidance: before treating documented options as applicable to a "
        "study, consult reference_advise for cited conditional applicability and implementation limits. "
        "Do not turn a published setting into a default; module defaults come from the module PACK. "
        "If evidence is insufficient, reference_request_literature queues a request without waiting; report the gap."
    ),
    "omicstat_run": (
        "\n\nReference-first guidance: normally consult the companion reference MCP before "
        "execution, using research-method context only and never count matrices or sample-level data. This tool never "
        "contacts the network, never waits for literature requests and never changes an explicit call because "
        "of reference material. If evidence was insufficient, run under the existing contract and report "
        "the evidence gap (and any queued request id), or ask the researcher first. Guidance only; calls "
        "without a reference check remain supported."
    ),
}


def _trusted_original_path() -> Path:
    """Resolve the process-configured, administrator-trusted original server path."""
    configured = os.environ.get("OMICSTAT_ORIGINAL_SERVER", DEFAULT_ORIGINAL_SERVER)
    candidate = Path(configured).expanduser()
    try:
        resolved = candidate.resolve(strict=True)
    except OSError as exc:
        raise RuntimeError(
            "OMICSTAT_ORIGINAL_SERVER is unavailable: %r. Set this trusted process "
            "environment variable to the existing omicstat mcp/server.py." % configured
        ) from exc
    if not resolved.is_file() or resolved.suffix.lower() != ".py":
        raise RuntimeError(
            "OMICSTAT_ORIGINAL_SERVER must name the existing omicstat server.py file: %s"
            % resolved
        )
    return resolved


def _import_original_server(path: Path) -> ModuleType:
    """Import an explicit server file without executing its ``__main__`` block."""
    digest = hashlib.sha256(str(path).casefold().encode("utf-8")).hexdigest()[:16]
    module_name = "_omicstat_original_bridge_" + digest
    cached = sys.modules.get(module_name)
    if cached is not None:
        return cached

    parent = str(path.parent)
    if parent not in sys.path:
        # The original server deliberately imports sibling modules such as
        # publication.py. Keep its own directory available for those imports.
        sys.path.insert(0, parent)

    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not construct an import specification for %s" % path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    try:
        spec.loader.exec_module(module)
    except Exception as exc:
        sys.modules.pop(module_name, None)
        raise RuntimeError(
            "failed to import the original omicstat MCP at %s; its analysis tools were not "
            "started or executed" % path
        ) from exc
    return module


def _require_fastmcp(module: ModuleType):
    """Return the existing server instance with a clear failure for wrong sources."""
    server = getattr(module, "mcp", None)
    required = ("list_tools", "list_resources", "resource", "run")
    if server is None or any(not callable(getattr(server, name, None)) for name in required):
        raise RuntimeError(
            "OMICSTAT_ORIGINAL_SERVER did not expose the expected FastMCP instance named 'mcp': %s"
            % getattr(module, "__file__", "<unknown>")
        )
    return server


def _append_tool_guidance(server) -> None:
    """Update only SDK tool descriptions; functions and parameter schemas stay intact."""
    tool_store = getattr(getattr(server, "_tool_manager", None), "_tools", None)
    if not isinstance(tool_store, dict):
        raise RuntimeError("installed MCP SDK does not expose FastMCP tool metadata required by this bridge")
    for name, suffix in TOOL_GUIDANCE.items():
        tool = tool_store.get(name)
        if tool is None:
            raise RuntimeError("original omicstat MCP is missing required tool: %s" % name)
        description = tool.description or ""
        if suffix.strip() not in description:
            tool.description = description + suffix


def _install_reference_metadata(server) -> None:
    """Install SDK 1.28 metadata once on the reused original server instance."""
    if getattr(server, "_omicstat_reference_bridge_installed", False):
        return

    # FastMCP 1.28 exposes server instructions through its low-level Server.
    # This changes initialization metadata only; it does not create wrappers.
    low_level = getattr(server, "_mcp_server", None)
    if low_level is None:
        raise RuntimeError("installed MCP SDK does not expose FastMCP server instructions")
    existing = getattr(low_level, "instructions", None)
    low_level.instructions = (existing + "\n\n" if existing else "") + SERVER_INSTRUCTIONS
    _append_tool_guidance(server)

    @server.resource(
        WORKFLOW_URI,
        name="omicstat reference-first workflow",
        description=(
            "Read-only workflow for consulting the companion research-reference MCP before "
            "analysis: search columns, advice, non-blocking literature requests and domain proposals."
        ),
        mime_type="text/markdown",
    )
    def reference_workflow_resource() -> str:
        try:
            return WORKFLOW_PATH.read_text(encoding="utf-8")
        except OSError as exc:
            raise RuntimeError("reference workflow resource is unavailable: %s" % WORKFLOW_PATH) from exc

    setattr(server, "_omicstat_reference_bridge_installed", True)


original_module = _import_original_server(_trusted_original_path())
mcp = _require_fastmcp(original_module)
_install_reference_metadata(mcp)


if __name__ == "__main__":
    mcp.run(transport="stdio")
