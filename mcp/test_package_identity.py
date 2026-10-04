from __future__ import annotations

import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import package_identity
import publication


class PackageIdentityTests(unittest.TestCase):
    def temporary_root(self):
        root = os.environ.get("OMICSTAT_TEST_TMP")
        if not root:
            self.fail("OMICSTAT_TEST_TMP must name an isolated writable test directory")
        return tempfile.TemporaryDirectory(dir=root)

    def write_identity(self, root: Path) -> Path:
        payload = root / "mcp" / "server.py"
        payload.parent.mkdir(parents=True, exist_ok=True)
        payload.write_text("trusted bytes\n", encoding="utf-8")
        files = [{"path": "mcp/server.py", "sha256": hashlib.sha256(payload.read_bytes()).hexdigest()}]
        value = {"schema": package_identity.SCHEMA, "source_commit": "a" * 40,
                 "source_tree": "b" * 40, "files": files,
                 "inventory_sha256": hashlib.sha256(package_identity._canonical_files(files)).hexdigest()}
        identity = root / package_identity.IDENTITY_REL
        identity.parent.mkdir(parents=True, exist_ok=True)
        identity.write_text(json.dumps(value), encoding="utf-8")
        return payload

    def test_non_git_identity_is_verified(self) -> None:
        with self.temporary_root() as tmp:
            root = Path(tmp)
            self.write_identity(root)
            value = package_identity.load_and_verify(root)
            self.assertIsNotNone(value)
            self.assertEqual(value["source_commit"], "a" * 40)

    def test_missing_tampered_and_hash_mismatch_fail_closed(self) -> None:
        with self.temporary_root() as tmp:
            root = Path(tmp)
            self.assertIsNone(package_identity.load_and_verify(root))
            payload = self.write_identity(root)
            identity = root / package_identity.IDENTITY_REL
            value = json.loads(identity.read_text(encoding="utf-8"))
            value["inventory_sha256"] = "0" * 64
            identity.write_text(json.dumps(value), encoding="utf-8")
            self.assertIsNone(package_identity.load_and_verify(root))
            self.write_identity(root)
            payload.write_text("changed bytes\n", encoding="utf-8")
            self.assertIsNone(package_identity.load_and_verify(root))

    def test_non_git_identity_is_reobserved_by_publication(self) -> None:
        with self.temporary_root() as tmp:
            root = Path(tmp)
            payload = self.write_identity(root)
            identity = package_identity.load_and_verify(root)
            self.assertIsNotNone(identity)
            supplied = {
                "python": "3.12", "mcp": "1.0", "r": "R", "r_session_info": "R",
                "python_packages": {"mcp": "1.0"}, "r_packages": {"stats": "1.0"},
                "repository": {
                    "commit": identity["source_commit"], "dirty": False,
                    "worktree_identity": None,
                    "package_identity": {
                        "source_tree": identity["source_tree"],
                        "inventory_sha256": identity["inventory_sha256"],
                    },
                },
                "module_entry_script": {
                    "path": "mcp/server.py", "sha256": hashlib.sha256(payload.read_bytes()).hexdigest(),
                },
            }
            with mock.patch.object(publication, "SUITE", str(root)):
                normalized, gaps = publication.normalize_provenance(supplied, "native")
            self.assertNotIn("repository.commit", gaps)
            self.assertNotIn("repository.dirty", gaps)
            self.assertEqual(normalized["repository"]["package_identity"]["source_tree"],
                             identity["source_tree"])


if __name__ == "__main__":
    unittest.main()
