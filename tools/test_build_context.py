"""Actual filesystem context checks with project-invented fixture files only."""
import json
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/env"))
from check_build_context import check, included, ignore_rules, references
from audit_build_contexts import audit, ARCHIVED_SOURCE_CONTEXTS


class ContextTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.df = self.root / "Dockerfile"
        self.df.write_text("FROM base\nCOPY source.txt /app/\n")
        (self.root / "source.txt").write_text("synthetic\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_present_source_is_hashed(self):
        r = check(self.df, self.root)
        self.assertTrue(r["ok"])
        self.assertEqual(len(r["included_files_sha256"]["source.txt"]), 64)
        self.assertFalse(r["docker_build_executed"])

    def test_excluded_file_is_failure(self):
        (self.root / ".dockerignore").write_text("*\n")
        r = check(self.df, self.root)
        self.assertFalse(r["ok"])
        self.assertEqual(r["excluded"], ["source.txt"])

    def test_last_matching_negation_and_ancestors(self):
        (self.root / ".dockerignore").write_text("**\n!env/\n!env/**\n**/*.pyc\n")
        rules = ignore_rules(self.root / ".dockerignore")
        self.assertTrue(included("env/candidates/test/sources/a.tar.gz", rules))
        self.assertFalse(included("env/cache/a.pyc", rules))
        self.assertFalse(included("private/patient.csv", rules))

    def test_missing_reference_is_failure(self):
        (self.root / "source.txt").unlink()
        r = check(self.df, self.root)
        self.assertFalse(r["ok"])
        self.assertEqual(r["missing"], ["source.txt"])

    def test_dockerfile_specific_ignore_has_precedence(self):
        (self.root / ".dockerignore").write_text("**\n")
        self.df.with_name("Dockerfile.dockerignore").write_text("unused\n")
        self.assertTrue(check(self.df, self.root)["ok"])

    def test_json_multiple_sources_and_stage_copy(self):
        self.df.write_text('FROM base AS prep\nCOPY --chown=1:1 ["source.txt", "Dockerfile", "/app/"]\nCOPY --from=prep /app/file /dest\n')
        self.assertEqual(references(self.df), ["source.txt", "Dockerfile"])
        self.assertTrue(check(self.df, self.root)["ok"])

    def test_continuation_glob_and_required_archives(self):
        self.df.write_text("FROM base\nCOPY source* \\\n Dockerfile /app/\n")
        self.assertTrue(check(self.df, self.root)["ok"])
        r = check(self.df, self.root, ["not-fetched.tar.gz"])
        self.assertFalse(r["ok"])
        self.assertIn("not-fetched.tar.gz", r["missing"])

    def test_required_ignored_child_is_not_hidden_by_directory_copy(self):
        d = self.root / "sources"
        d.mkdir()
        (d / "one.tar.gz").write_text("one")
        (d / "two.tar.gz").write_text("two")
        self.df.write_text("FROM base\nCOPY sources /app/\n")
        (self.root / ".dockerignore").write_text("sources/two.tar.gz\n")
        r = check(self.df, self.root, ["sources/one.tar.gz", "sources/two.tar.gz"])
        self.assertFalse(r["ok"])
        self.assertIn("sources/two.tar.gz", r["excluded"])

    def test_remote_dynamic_and_escape_are_fail_closed(self):
        for source in ("../outside", "/outside", "$ARCHIVE", "https://example.org/a"):
            self.df.write_text("FROM base\nADD " + source + " /app/\n")
            with self.subTest(source=source), self.assertRaises(ValueError):
                check(self.df, self.root)

    def test_symlink_is_not_followed(self):
        (self.root / "link").symlink_to(self.root / "source.txt")
        self.df.write_text("FROM base\nCOPY link /app/\n")
        self.assertFalse(check(self.df, self.root)["ok"])

    def test_symlink_ancestor_is_not_hashed_as_a_regular_file(self):
        (self.root / "linked-dir").symlink_to(self.root, target_is_directory=True)
        self.df.write_text("FROM base\nCOPY linked-dir/source.txt /app/\n")
        r = check(self.df, self.root)
        self.assertFalse(r["ok"])
        self.assertEqual(r["included_files_sha256"], {})

    def test_buildkit_bind_sources_checked(self):
        self.df.write_text("FROM base\nRUN --mount=type=bind,source=missing,target=/src true\n")
        self.assertFalse(check(self.df, self.root)["ok"])

    def test_repository_ignore_exposes_all_candidate_contract_paths(self):
        rules = ignore_rules(ROOT / ".dockerignore")
        dockerfiles = sorted((ROOT / "env/candidates").glob("*/Dockerfile")) + sorted((ROOT / "env/py/candidates").glob("*/Dockerfile"))
        self.assertEqual(len(dockerfiles), 10)
        for dockerfile in dockerfiles:
            for source in references(dockerfile):
                with self.subTest(dockerfile=str(dockerfile), source=source):
                    self.assertTrue(included(source, rules))
        for source in ("env/r-env.json", "env/py/py-env.json", "tools/env/install_candidate.R",
                       "tools/env/install_candidate.py", "env/candidates/20261016-models/sources/drc_3.0-1.tar.gz"):
            self.assertTrue(included(source, rules))
        self.assertFalse(included("acceptance/data/private.csv", rules))

    def test_partial_directory_copy_fails_missing_inventoried_bytes(self):
        self.df.write_text("FROM base\nCOPY . /app/\n")
        r = check(self.df, self.root, expected_files=["source.txt", "not-recovered.json"])
        self.assertFalse(r["ok"])
        self.assertIn("not-recovered.json", r["missing"])
        self.assertTrue(r["expected_inventory_supplied"])

    def test_inventoried_excluded_runtime_cache_is_not_required(self):
        self.df.write_text("FROM base\nCOPY . /app/\n")
        (self.root / ".dockerignore").write_text("logs\n")
        self.assertTrue(check(self.df, self.root, expected_files=["source.txt", "logs/runtime.log"])["ok"])

    def test_unregistered_dockerfile_fails_instead_of_guessing_context(self):
        r = audit(self.root, ["Dockerfile"])
        self.assertFalse(r["ok"])
        self.assertIn("unregistered Dockerfile context", r["results"][0]["errors"][0])

    def test_python_base_uses_env_not_repository_context(self):
        env = self.root / "env"
        (env / "py").mkdir(parents=True)
        (env / "py/Dockerfile").write_text("FROM base\nCOPY pinned.json /app/\n")
        (env / "pinned.json").write_text("{}\n")
        (self.root / ".dockerignore").write_text("**\n")
        r = audit(self.root, ["env/py/Dockerfile", "env/pinned.json"])
        self.assertTrue(r["ok"])
        self.assertEqual(r["results"][0]["registered_context"], "env")

    def archive_fixture(self, name, sources):
        directory = self.root / "reference" / name
        directory.mkdir(parents=True)
        (directory / "Dockerfile").write_text("FROM fixture\n" + sources)
        return directory

    def test_only_two_explicit_archive_contexts_are_registered(self):
        self.assertEqual(set(ARCHIVED_SOURCE_CONTEXTS), {
            "reference/medstat-docker/Dockerfile", "reference/medstat-reference/Dockerfile"})
        self.archive_fixture("unreviewed", "COPY . /app/\n")
        r = audit(self.root, ["reference/unreviewed/Dockerfile"])
        self.assertFalse(r["ok"])
        self.assertIn("unregistered Dockerfile context", r["results"][0]["errors"][0])

    def test_archived_R_copy_inputs_use_their_own_source_directory(self):
        d = self.archive_fixture("medstat-docker", "COPY install_packages.R /tmp/\nCOPY install_packages2.R /tmp/\n")
        for p in ("install_packages.R", "install_packages2.R"):
            (d / p).write_text("# synthetic static input; never run\n")
        (self.root / ".dockerignore").write_text("**\n")
        inventory = [(d / p).relative_to(self.root).as_posix() for p in ("Dockerfile", "install_packages.R", "install_packages2.R")]
        r = audit(self.root, inventory)
        self.assertTrue(r["ok"])
        result = r["results"][0]
        self.assertEqual(result["registered_context"], "reference/medstat-docker")
        self.assertEqual(result["context_scope"], "archived_repository_source_only")
        self.assertFalse(result["build_entrypoint_verified"])
        self.assertEqual(set(result["included_files_sha256"]), {"install_packages.R", "install_packages2.R"})
        self.assertFalse(r["docker_build_executed"])
        self.assertFalse(r["deployment_accessed"])

    def test_archived_service_context_honors_its_local_ignore(self):
        d = self.archive_fixture("medstat-reference", "COPY requirements.txt ./\nCOPY . /app\n")
        (d / "requirements.txt").write_text("# synthetic\n")
        (d / "worker.py").write_text("# synthetic\n")
        (d / ".dockerignore").write_text("logs\n")
        (self.root / ".dockerignore").write_text("**\n")
        inventory = [(d / p).relative_to(self.root).as_posix() for p in ("Dockerfile", "requirements.txt", "worker.py", ".dockerignore", "logs/absent.log")]
        r = audit(self.root, inventory)
        self.assertTrue(r["ok"])
        result = r["results"][0]
        self.assertEqual(result["registered_context"], "reference/medstat-reference")
        self.assertEqual(result["context_scope"], "archived_repository_source_only")
        self.assertTrue(result["build_entrypoint_verified"])
        self.assertNotIn("logs/absent.log", result["included_files_sha256"])

    def test_missing_archived_copy_source_still_fails(self):
        self.archive_fixture("medstat-docker", "COPY install_packages.R /tmp/\n")
        r = audit(self.root, ["reference/medstat-docker/Dockerfile", "reference/medstat-docker/install_packages.R"])
        self.assertFalse(r["ok"])
        self.assertIn("install_packages.R", r["results"][0]["missing"])

    def test_excluded_archived_copy_source_still_fails(self):
        d = self.archive_fixture("medstat-docker", "COPY install_packages.R /tmp/\n")
        (d / "install_packages.R").write_text("# synthetic\n")
        (d / ".dockerignore").write_text("install_packages.R\n")
        r = audit(self.root, ["reference/medstat-docker/Dockerfile", "reference/medstat-docker/install_packages.R"])
        self.assertFalse(r["ok"])
        self.assertIn("install_packages.R", r["results"][0]["excluded"])

    def test_archived_copy_dot_requires_all_inventoried_bytes(self):
        self.archive_fixture("medstat-reference", "COPY . /app/\n")
        r = audit(self.root, ["reference/medstat-reference/Dockerfile", "reference/medstat-reference/worker.py"])
        self.assertFalse(r["ok"])
        self.assertIn("worker.py", r["results"][0]["missing"])

    def test_archived_symlink_input_still_fails(self):
        d = self.archive_fixture("medstat-docker", "COPY install_packages.R /tmp/\n")
        (d / "install_packages.R").symlink_to(self.root / "source.txt")
        r = audit(self.root, ["reference/medstat-docker/Dockerfile", "reference/medstat-docker/install_packages.R"])
        self.assertFalse(r["ok"])
        self.assertTrue(any("symlink" in x for x in r["results"][0]["errors"]))

    def test_archive_audit_reads_without_writing_or_executing(self):
        from unittest.mock import patch
        d = self.archive_fixture("medstat-docker", "COPY install_packages.R /tmp/\n")
        (d / "install_packages.R").write_text("# synthetic\n")
        files = [p for p in self.root.rglob("*") if p.is_file()]
        before = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in files}
        with patch("subprocess.Popen", side_effect=AssertionError("no child process allowed")):
            r = audit(self.root, [p for p in before if p.startswith("reference/")])
        after = {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(before, after)
        self.assertTrue(r["ok"])
        self.assertFalse(r["docker_build_executed"])
        self.assertFalse(r["deployment_accessed"])

    def test_nine_missing_candidate_caches_are_not_exempted(self):
        names = ["env/candidates/20261016-" + n for n in ("annotation", "epigenomics", "sc-activity", "sc-qc", "spatial", "survival")]
        names += ["env/py/candidates/20261016-py-" + n for n in ("activity", "spatial", "velocity")]
        inventory = []
        for name in names:
            directory = self.root / name
            directory.mkdir(parents=True)
            (directory / "Dockerfile").write_text("FROM fixture\nCOPY " + name + "/sources /sources/\n")
            (directory / "manifest.json").write_text("{}\n")
            (directory / "sources.lock.json").write_text(json.dumps({"sources": [{"filename": "missing-exact.tar.gz"}]}))
            inventory += [name + "/" + p for p in ("Dockerfile", "manifest.json", "sources.lock.json")]
        r = audit(self.root, inventory)
        self.assertEqual(r["dockerfile_count"], 9)
        self.assertFalse(r["ok"])
        self.assertEqual(sum(not x["ok"] for x in r["results"]), 9)
        for result in r["results"]:
            self.assertTrue(any(p.endswith("missing-exact.tar.gz") for p in result["missing"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
