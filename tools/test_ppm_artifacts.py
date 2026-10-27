"""Synthetic metadata/guard tests. No real PPM archives or image installs."""
import copy
import hashlib
import io
import json
import pathlib
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/env"))
import r_artifacts as ra
import prepare_locked_sources as prep
import build_candidate


def archive(path, *, binary=True, built="R 4.6.1; x86_64-pc-linux-gnu; 2026-09-15; unix", extras=(), needs_compilation=None):
    text = "Package: extra\nVersion: 2.0\nDepends: R (>= 4.6)\nImports: base (>= 1.0)\n"
    if binary:
        text += "Built: " + built + "\n"
    if needs_compilation is not None:
        text += "NeedsCompilation: " + needs_compilation + "\n"
    members = [("extra/DESCRIPTION", text.encode())]
    if binary:
        members.append(("extra/Meta/package.rds", b"SYNTHETIC_METADATA_NOT_AN_R_OBJECT"))
    members.extend(extras)
    with tarfile.open(path, "w:gz") as t:
        for name, data in members:
            info = tarfile.TarInfo(name)
            info.size = len(data)
            t.addfile(info, io.BytesIO(data))


class PPMTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.c = self.root / "env/candidates/test"
        self.c.mkdir(parents=True)
        self.cache = self.root / "cache"
        self.cache.mkdir()
        self.path = self.cache / "extra_2.0.tar.gz"
        archive(self.path)
        self.id = "sha256:" + "a" * 64
        self.row = dict(package="extra", version="2.0", filename=self.path.name,
                        kind="ppm_binary", platform="linux/amd64", ppm_snapshot_url=ra.APPROVED_SNAPSHOT,
                        url=ra.APPROVED_SNAPSHOT + "/src/contrib/" + self.path.name,
                        sha256=prep.sha(self.path))
        self.policy = dict(schema="omicstat.r-artifact-policy.v1", parent_image_id=self.id,
                           ppm_snapshot_url=ra.APPROVED_SNAPSHOT, platform="linux/amd64",
                           distribution="noble", r_version="4.6.1")
        self.m = dict(schema="omicstat.env-candidate.v1", id="test", lane="R",
                      base_image="omicstat-r:1", base_image_id=self.id,
                      image_tag="omicstat-r:candidate-test", target_layer="L9_models",
                      target_env_version="2", new_packages=["extra"], state="resolved",
                      install_order=["extra"], sources=[self.row], r_artifact_policy=self.policy,
                      source_preparation_required=True)
        cfg = dict(image="omicstat-r", image_tag="1", r_version="4.6.1",
                   cran_repo_linux=ra.APPROVED_SNAPSHOT, cran_snapshot="2026-09-15")
        (self.root / "env/r-env.json").write_text(json.dumps(cfg))
        (self.root / "env/image_id.txt").write_text(self.id + "\n")
        (self.root / "env/pkg_lock.csv").write_text("package,version\nbase,1.0\n")
        (self.c / "Dockerfile").write_text("ARG BASE_IMAGE\nFROM ${BASE_IMAGE}\nCOPY env/candidates/test/sources /candidate/sources\n")
        self.save()

    def tearDown(self):
        self.tmp.cleanup()

    def save(self):
        (self.c / "manifest.json").write_text(json.dumps(self.m))
        (self.c / "sources.lock.json").write_text(json.dumps({"sources": [self.row]}))

    def test_explicit_binary_metadata_cache_and_readonly_second_check(self):
        before = [(p, p.read_bytes()) for p in (self.c / "manifest.json", self.c / "sources.lock.json")]
        with patch("urllib.request.build_opener", side_effect=AssertionError("network forbidden")):
            result = prep.prepare(self.c, self.root, source_cache=self.cache)
            second = prep.prepare(self.c, self.root)
        self.assertEqual(result["state"], "ready_for_offline_build")
        self.assertEqual(second["state"], "ready_for_offline_build")
        self.assertEqual(result["sources"][0]["state"], "verified_binary")
        self.assertFalse(result["actual_parent_runtime_verified"])
        self.assertFalse(result["installed"])
        self.assertFalse(result["image_built"])
        for p, data in before:
            self.assertEqual(data, p.read_bytes())

    def test_missing_binary_is_blocked_not_fabricated(self):
        r = prep.prepare(self.c, self.root)
        self.assertEqual(r["state"], "blocked")
        self.assertEqual(r["sources"][0]["state"], "missing")
        self.assertFalse((self.c / "sources").exists())

    def test_kind_required_and_enum_strict(self):
        for kind in (None, "binary", "wheel", "PPM_BINARY", False):
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, "kind"):
                ra.record_policy(dict(self.row, kind=kind))

    def test_snapshot_platform_url_hash_are_independent_gates(self):
        variations = [dict(ppm_snapshot_url=ra.APPROVED_SNAPSHOT.replace("09-15", "09-16")),
                      dict(platform="linux/arm64"), dict(url=self.row["url"].replace("p3m.dev", "example.org")),
                      dict(url=self.row["url"].replace("noble", "jammy")),
                      dict(url=self.row["url"].replace("2026-09-15", "latest")),
                      dict(url=self.row["url"] + "?download=1"), dict(sha256="0" * 63),
                      dict(filename="../extra.tar.gz"), dict(url=self.row["url"].replace("https://", "https://u:p@"))]
        for changes in variations:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                ra.record_policy(dict(self.row, **changes))

    def test_bioconductor_cannot_be_reclassified_binary(self):
        with self.assertRaisesRegex(ValueError, "Bioconductor"):
            ra.record_policy(dict(self.row, url="https://bioconductor.org/packages/3.23/bioc/src/contrib/extra.tar.gz"))

    def test_parent_identity_snapshot_and_r_declaration_checked(self):
        changes = [dict(parent_image_id="sha256:" + "b" * 64), dict(distribution="jammy"),
                   dict(platform="linux/arm64"), dict(r_version="4.5.1"), dict(ppm_snapshot_url=ra.APPROVED_SNAPSHOT + "/")]
        for change in changes:
            m = dict(self.m, r_artifact_policy=dict(self.policy, **change))
            with self.subTest(change=change), self.assertRaises(ValueError):
                ra.candidate_policy(m, [self.row], self.root)
        self.assertEqual(ra.candidate_policy(self.m, [self.row], self.root), self.policy)

    def test_parent_actual_image_os_arch_and_id_checked(self):
        image = dict(Id=self.id, Os="linux", Architecture="amd64")
        ra.verify_parent_image(image, self.policy)
        for change in (dict(Id="sha256:" + "b" * 64), dict(Os="windows"), dict(Architecture="arm64"), dict(Os=None)):
            with self.subTest(change=change), self.assertRaises(ValueError):
                ra.verify_parent_image(dict(image, **change), self.policy)

    def test_recorded_parent_survives_production_promotion(self):
        cfg_path = self.root / "env/r-env.json"
        baseline = json.loads(cfg_path.read_text()) | {"image_id": self.id}
        history = self.root / "env/r-baselines/1.json"
        history.parent.mkdir()
        history.write_text(json.dumps(baseline))
        cfg_path.write_text(json.dumps(baseline | {"image_tag": "2"}))
        (self.root / "env/image_id.txt").write_text("sha256:" + "b" * 64)
        self.assertEqual(ra.candidate_policy(self.m, [self.row], self.root), self.policy)
        for change in ({"base_image_id": "sha256:" + "c" * 64}, {"base_image": "omicstat-r:unknown"}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                ra.candidate_policy(dict(self.m, **change), [self.row], self.root)
        history.write_text(json.dumps(baseline | {"cran_snapshot": "2026-09-16"}))
        with self.assertRaisesRegex(ValueError, "snapshot"):
            ra.candidate_policy(self.m, [self.row], self.root)

    def test_parent_actual_runtime_repo_codename_and_r_checked(self):
        runtime = dict(cran_repo=ra.APPROVED_SNAPSHOT, distribution="noble",
                       r_version="4.6.1", r_platform="x86_64-pc-linux-gnu")
        ra.verify_parent_runtime(runtime, self.policy)
        for change in (dict(cran_repo=ra.APPROVED_SNAPSHOT.replace("09-15", "09-16")),
                       dict(distribution="jammy"), dict(r_version="4.5.1"), dict(r_platform="aarch64-unknown-linux-gnu")):
            with self.subTest(change=change), self.assertRaises(ValueError):
                ra.verify_parent_runtime(dict(runtime, **change), self.policy)

    def test_binary_requires_real_installed_metadata(self):
        archive(self.path, binary=False)
        with self.assertRaisesRegex(ValueError, "metadata"):
            ra.inspect_archive(self.path, self.row, self.policy)

    def test_built_metadata_rejects_different_platform_r_and_os(self):
        for built in ("R 4.5.1; x86_64-pc-linux-gnu; 2026-09-15; unix",
                      "R 4.6.1; aarch64-unknown-linux-gnu; 2026-09-15; unix",
                      "R 4.6.1; x86_64-w64-mingw32; 2026-09-15; windows", "malformed"):
            archive(self.path, built=built)
            with self.subTest(built=built), self.assertRaisesRegex(ValueError, "Built"):
                ra.inspect_archive(self.path, self.row, self.policy)

    def test_built_patch_cannot_be_newer_than_parent(self):
        archive(self.path, built="R 4.6.0; x86_64-pc-linux-gnu; 2026-09-15; unix")
        self.assertEqual(ra.inspect_archive(self.path, self.row, self.policy)["Package"], "extra")
        archive(self.path, built="R 4.6.2; x86_64-pc-linux-gnu; 2026-09-15; unix")
        with self.assertRaisesRegex(ValueError, "Built"):
            ra.inspect_archive(self.path, self.row, self.policy)

    def test_explicit_pure_r_empty_platform_is_accepted(self):
        archive(self.path, built="R 4.6.0; ; 2026-04-24 23:43:12 UTC; unix", needs_compilation="no")
        self.assertEqual(ra.inspect_archive(self.path, self.row, self.policy)["NeedsCompilation"], "no")
        self.row["sha256"] = prep.sha(self.path)
        self.save()
        with patch("urllib.request.build_opener", side_effect=AssertionError("network forbidden")):
            result = prep.prepare(self.c, self.root, source_cache=self.cache)
        self.assertEqual(result["sources"][0]["state"], "verified_binary")
        self.assertFalse(result["actual_parent_runtime_verified"])
        self.assertFalse(result["installed"])

    def test_empty_platform_requires_explicit_no_compilation(self):
        for flag in (None, "", "yes", "NO", "false"):
            archive(self.path, built="R 4.6.0; ; 2026-09-15; unix", needs_compilation=flag)
            with self.subTest(flag=flag), self.assertRaisesRegex(ValueError, "Built"):
                ra.inspect_archive(self.path, self.row, self.policy)

    def test_empty_platform_rejects_native_members_even_if_declared_pure(self):
        for path in ("extra/libs/library", "extra/libs/x64/extra.so", "extra/exec/helper.so.1",
                     "extra/extra.DLL", "extra/extra.dylib", "extra/extra.a", "extra/extra.o"):
            archive(self.path, built="R 4.6.0; ; 2026-09-15; unix", needs_compilation="no", extras=[(path, b"native-test-double")])
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, "Built"):
                ra.inspect_archive(self.path, self.row, self.policy)

    def test_pure_r_does_not_permit_foreign_explicit_platform_r_or_os(self):
        for built in ("R 4.6.0; aarch64-unknown-linux-gnu; 2026-09-15; unix",
                      "R 4.5.1; ; 2026-09-15; unix", "R 4.6.2; ; 2026-09-15; unix",
                      "R 4.6.0; ; 2026-09-15; windows", "R 4.6.0; ; 2026-09-15"):
            archive(self.path, built=built, needs_compilation="no")
            with self.subTest(built=built), self.assertRaisesRegex(ValueError, "Built"):
                ra.inspect_archive(self.path, self.row, self.policy)

    def test_compiled_package_still_accepts_only_qualified_platform(self):
        archive(self.path, needs_compilation="yes", extras=[("extra/libs/extra.so", b"native-test-double")])
        self.assertEqual(ra.inspect_archive(self.path, self.row, self.policy)["NeedsCompilation"], "yes")

    def test_pure_r_empty_platform_does_not_bypass_locked_identity_or_hash(self):
        archive(self.path, built="R 4.6.0; ; 2026-09-15; unix", needs_compilation="no")
        with self.assertRaisesRegex(ValueError, "package/version"):
            ra.inspect_archive(self.path, dict(self.row, version="2.1"), self.policy)
        with self.assertRaisesRegex(ValueError, "SHA mismatch"):
            prep.prepare(self.c, self.root, source_cache=self.cache)

    def test_installer_retains_exact_description_version_check(self):
        source = (ROOT / "tools/env/install_candidate.R").read_text()
        self.assertIn('utils::packageDescription(name,fields="Version")', source)
        self.assertNotIn('as.character(utils::packageVersion(name))', source)
        self.assertIn('candidate_built_platform_ok(built[2],R.version$platform,needs_compilation,listed)', source)

    def test_source_kind_does_not_bypass_binary_guard(self):
        with self.assertRaisesRegex(ValueError, "binary package"):
            ra.inspect_archive(self.path, dict(self.row, kind="source"))

    def test_bounded_unique_safe_metadata(self):
        for extra in (("../outside", b"x"), ("extra/DESCRIPTION", b"Package: forged\n"),
                      ("extra/other", b"x")):
            archive(self.path, extras=[extra])
            if extra[0] == "extra/other":
                self.assertEqual(ra.inspect_archive(self.path, self.row, self.policy)["Package"], "extra")
            else:
                with self.assertRaises(ValueError):
                    ra.inspect_archive(self.path, self.row, self.policy)

    def test_hash_mismatch_refuses_before_cache_publication(self):
        self.row["sha256"] = "0" * 64
        self.save()
        with self.assertRaisesRegex(ValueError, "SHA mismatch"):
            prep.prepare(self.c, self.root, source_cache=self.cache)
        self.assertFalse((self.c / "sources" / self.path.name).exists())

    def test_binary_builder_always_prepares_even_if_manifest_flag_false(self):
        self.m["source_preparation_required"] = False
        self.save()
        with patch("build_candidate.inspect", side_effect=AssertionError("Docker forbidden")):
            r = build_candidate.build(self.c, self.root)
        self.assertEqual(r["state"], "blocked")
        self.assertIsNotNone(r["source_preparation"])
        self.assertIn("--check", r["source_preparation_command"])
        self.assertFalse(r["source_download_automatic"])
        self.assertFalse(r["actual_parent_runtime_verified"])

    def test_mock_builder_checks_parent_platform_before_any_run_or_build(self):
        prep.prepare(self.c, self.root, source_cache=self.cache)
        with patch("build_candidate.inspect", return_value=dict(Id=self.id, Os="linux", Architecture="arm64")), \
                patch("build_candidate.command") as command, patch("build_candidate.subprocess.run") as run:
            with self.assertRaisesRegex(ValueError, "platform"):
                build_candidate.build(self.c, self.root, execute=True)
            command.assert_not_called()
            run.assert_not_called()

    def test_mock_builder_checks_actual_runtime_before_tag_lookup_or_build(self):
        prep.prepare(self.c, self.root, source_cache=self.cache)
        runtime = dict(cran_repo=ra.APPROVED_SNAPSHOT, distribution="jammy",
                       r_version="4.6.1", r_platform="x86_64-pc-linux-gnu")
        with patch("build_candidate.inspect", return_value=dict(Id=self.id, Os="linux", Architecture="amd64")), \
                patch("build_candidate.command", return_value=json.dumps(runtime)) as command, \
                patch("build_candidate.subprocess.run") as run:
            with self.assertRaisesRegex(ValueError, "runtime"):
                build_candidate.build(self.c, self.root, execute=True)
            self.assertEqual(command.call_count, 1)
            self.assertIn("--read-only", command.call_args.args)
            run.assert_not_called()

    def test_mixed_top_level_packages_rejected(self):
        archive(self.path, extras=[("other/file", b"synthetic")])
        with self.assertRaisesRegex(ValueError, "package directory"):
            ra.inspect_archive(self.path, self.row, self.policy)

    def test_exact_model_identity_values_remain_reviewed(self):
        rows = prep.sources(ROOT / "env/candidates/20261016-models")
        self.assertEqual(sum(r["kind"] == "ppm_binary" for r in rows), 7)
        self.assertEqual(sum(r["kind"] == "source" for r in rows), 4)
        m = prep.manifest(ROOT / "env/candidates/20261016-models", ROOT)
        ra.candidate_policy(m, rows, ROOT)
        for row in rows:
            ra.record_policy(row)


if __name__ == "__main__":
    unittest.main(verbosity=2)
