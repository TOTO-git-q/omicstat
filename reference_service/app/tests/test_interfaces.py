"""Interface invariants: v1 reference tool schemas preserved; omicstat entry schemas byte-identical to the omicstat MCP.

omicstat fork: the base checked medstat_entry.py against medstat 55692f7; the fork checks omicstat_entry.py
(reference_service/, outside the image) against the omicstat mcp/server.py of the same checkout."""
import asyncio
import importlib.util
import json
import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENTRY = ROOT.parent / "omicstat_entry.py"
ORIGINAL = Path(os.environ.get("OMICSTAT_ORIGINAL_SERVER", str(ROOT.parent.parent / "mcp" / "server.py")))
EXPECTED_REFERENCE_TOOLS = {"reference_status", "reference_search", "reference_get_record", "reference_advise",
                            "reference_list_candidates", "reference_submit_review", "reference_request_literature",
                            "reference_request_status", "reference_cancel_request", "reference_propose_domain"}
OMICSTAT_TOOLS = {"omicstat_list_modules", "omicstat_describe", "omicstat_run", "omicstat_read", "omicstat_validate_publication"}


def _dump(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


class ReferenceToolSchemaTests(unittest.TestCase):
    def test_ten_tools_and_v1_parameters_unchanged(self):
        from v2fixtures import load_reference_server
        server = load_reference_server()
        tools = {t.name: t for t in asyncio.run(server.mcp.list_tools())}
        self.assertEqual(set(tools), EXPECTED_REFERENCE_TOOLS)
        baseline = json.loads((ROOT / "tests" / "fixtures" / "v1_reference_tool_schemas.json").read_text(encoding="utf-8"))["tools"]
        self.assertEqual(len(baseline), 6)
        for name, old in baseline.items():
            new = tools[name].inputSchema
            old_schema = old["inputSchema"]
            self.assertEqual(new.get("required", []), old_schema.get("required", []), name)
            for prop, spec in old_schema.get("properties", {}).items():
                self.assertEqual(new["properties"][prop], spec, f"{name}.{prop}")
            added = set(new.get("properties", {})) - set(old_schema.get("properties", {}))
            self.assertFalse(added & set(new.get("required", [])), f"{name} added a required parameter")
            self.assertTrue(added <= {"include_discovery", "include_legacy"}, f"{name}: {added}")


class ServerIdentityTests(unittest.TestCase):
    """omicstat fork: the server is omicstat_reference and carries no medstat wording."""
    def test_name_and_instructions(self):
        from v2fixtures import load_reference_server
        server = load_reference_server()
        self.assertEqual(server.mcp.name, "omicstat_reference")
        text = server.mcp.instructions + " ".join(t.description or "" for t in asyncio.run(server.mcp.list_tools()))
        self.assertNotRegex(text.lower(), r"medstat|\b27\b")
        self.assertIn("omicstat", text)


@unittest.skipUnless(ORIGINAL.is_file() and ENTRY.is_file(), "omicstat mcp/server.py or omicstat_entry.py not present (e.g. inside the image)")
class OmicstatEntryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("_pristine_omicstat_for_test", ORIGINAL)
        module = importlib.util.module_from_spec(spec)
        sys.path.insert(0, str(ORIGINAL.parent))
        spec.loader.exec_module(module)
        cls.original = {t.name: t for t in asyncio.run(module.mcp.list_tools())}
        os.environ["OMICSTAT_ORIGINAL_SERVER"] = str(ORIGINAL)
        spec = importlib.util.spec_from_file_location("_omicstat_entry_for_test", ENTRY)
        entry = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(entry)
        cls.entry_module = entry
        cls.entry = {t.name: t for t in asyncio.run(entry.mcp.list_tools())}

    def test_five_tools_with_byte_identical_schemas(self):
        self.assertEqual(set(self.original), OMICSTAT_TOOLS)
        self.assertEqual(set(self.entry), OMICSTAT_TOOLS)
        for name in OMICSTAT_TOOLS:
            a, b = self.original[name], self.entry[name]
            self.assertEqual(_dump(a.inputSchema), _dump(b.inputSchema), name)
            self.assertEqual(_dump(a.outputSchema), _dump(b.outputSchema), name)
            self.assertEqual(_dump(a.annotations.model_dump() if a.annotations else None),
                             _dump(b.annotations.model_dump() if b.annotations else None), name)
            self.assertTrue((b.description or "").startswith(a.description or ""), name)

    def test_guidance_names_the_workflow(self):
        text = self.entry_module.SERVER_INSTRUCTIONS
        for phrase in ("omicstat_reference", "reference_search", "reference_advise", "reference_request_literature",
                       "DO NOT WAIT", "unreviewed_machine_screened", "never contacts the network", "no_curated_evidence_yet"):
            self.assertIn(phrase, text)
        self.assertNotRegex(text.lower(), r"medstat|\b27\b")
        self.assertIn("never waits for literature", self.entry["omicstat_run"].description)
        workflow = (ENTRY.parent / "REFERENCE_WORKFLOW.md").read_text(encoding="utf-8")
        self.assertIn("reference_request_literature", workflow)
        self.assertIn("do not wait", workflow)
        self.assertNotRegex(workflow.lower(), r"medstat|\b27\b")


if __name__ == "__main__":
    unittest.main()
