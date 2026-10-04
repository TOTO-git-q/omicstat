"""Real MCP stdio smoke: omicstat_entry.py vs the untouched omicstat mcp/server.py.

Copied from medstat-reference v2 tests/smoke_medstat_entry.py. Starts both over stdio, lists tools, and requires the five omicstat tools to have
byte-identical input/output schemas and annotations (descriptions may only gain
an appended guidance suffix). Also checks the workflow resource and instructions.
No analysis is executed.
"""
import asyncio
import json
import os
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

PROJECT = Path(__file__).resolve().parents[1]
ORIGINAL = Path(os.environ.get("OMICSTAT_ORIGINAL_SERVER", str(PROJECT.parent / "mcp" / "server.py")))
TOOLS = {"omicstat_list_modules", "omicstat_describe", "omicstat_run", "omicstat_read", "omicstat_validate_publication"}


def dump(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


async def listing(script: Path):
    params = StdioServerParameters(command=sys.executable, args=[str(script)], env={**os.environ, "OMICSTAT_ORIGINAL_SERVER": str(ORIGINAL)})
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            init = await session.initialize()
            tools = (await session.list_tools()).tools
            resources = (await session.list_resources()).resources
            workflow = None
            if any(str(r.uri) == "omicstat://reference-workflow" for r in resources):
                workflow = (await session.read_resource("omicstat://reference-workflow")).contents[0].text
            return init.instructions, {t.name: t for t in tools}, {str(r.uri) for r in resources}, workflow


async def main():
    _, original, original_resources, _ = await listing(ORIGINAL)
    instructions, entry, entry_resources, workflow = await listing(PROJECT / "omicstat_entry.py")
    assert set(original) == TOOLS, sorted(original)
    assert set(entry) == TOOLS, sorted(entry)
    checks = []
    for name in sorted(TOOLS):
        a, b = original[name], entry[name]
        same_input = dump(a.inputSchema) == dump(b.inputSchema)
        same_output = dump(a.outputSchema) == dump(b.outputSchema)
        same_annotations = dump(a.annotations.model_dump() if a.annotations else None) == dump(b.annotations.model_dump() if b.annotations else None)
        prefix = (b.description or "").startswith(a.description or "")
        assert same_input and same_output and same_annotations and prefix, name
        checks.append({"tool": name, "input_schema_bytes": len(dump(a.inputSchema)), "byte_identical_input": same_input,
                       "byte_identical_output": same_output, "annotations_identical": same_annotations,
                       "description_is_original_plus_suffix": prefix})
    assert original_resources <= entry_resources and "omicstat://reference-workflow" in entry_resources
    guided = {"omicstat_list_modules", "omicstat_describe", "omicstat_run"}
    for name in sorted(TOOLS):
        extended = (entry[name].description or "") != (original[name].description or "")
        assert extended == (name in guided), ("guidance suffix", name)
    assert "reference_request_literature" in instructions and "DO NOT WAIT" in instructions
    assert workflow and "reference_request_literature" in workflow
    print(json.dumps({"status": "passed", "tools": checks, "added_resources": sorted(entry_resources - original_resources)}, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
