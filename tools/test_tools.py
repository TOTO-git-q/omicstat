#!/usr/bin/env python3
"""Tests for tools/check_defaults.py and tools/lint_r.py (small temp fixtures).

Usage: python tools/test_tools.py   (stdlib only; one test runs Rscript when present)
"""
import json, os, pathlib, shutil, subprocess, sys, tempfile, unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import check_defaults as cdf  # noqa: E402
import lint_r  # noqa: E402

HELP = """Usage: Rscript run_x_y.R --outdir <dir> [options]
test module
Options:
  --outdir <path>                   required           output directory
  --seed <int>                      default: 20260925  random seed
  --alpha <num in [0, 1]>           default: 0.05      FDR level
  --journal <nature|cell|generic>   default: nature    figure preset
  --strict <switch>                 default: off       fail on blockers
  --from-run <path>                 default: none      upstream run
  --help <switch>                   default: off       show this help and exit
Mutually exclusive: --input, --from-run
"""

PARAMS = """# parameters -- x-y

| Flag | Default | Allowed | Why |
|---|---|---|---|
| `--outdir` | (required) | dir | run directory |
| `--seed` | 20260925 | integer | seed |
| `--alpha` | `0.05` | (0, 1] | FDR |
| `--journal` | nature | nature, cell | preset |
| `--strict` | off (bare switch) | present / absent | fail |
| `--from-run` | -- | run dir | chain |
| `--help` | -- | -- | help |

| Other | Value |
|---|---|
| `--seed` | 1 |
"""

REPORT = """# reporting-templates -- x-y

Genes were called at adjusted P < <!-- default --alpha -->0.05<!-- /default --> (seed
<!-- default --seed -->20260925<!-- /default -->). Example only: `<!-- default --alpha -->0.9<!-- /default -->`.
"""

REGISTRY = {"module": "x-y", "package_versions": {},
            "flag_defaults": {"--seed": 20260925, "strict": False},
            "calls": [{"fn": "pkg::fit", "args": {"alpha": {"value": 0.05, "flag": "--alpha"},
                                                    "method": {"value": "BH"}}}]}


class ModuleFixture:
    def __init__(self, params=PARAMS, report=REPORT, registry=REGISTRY, skill="# x-y\n"):
        self.dir = pathlib.Path(tempfile.mkdtemp(prefix="omicstat_tools_test_")) / "x-y"
        (self.dir / "references").mkdir(parents=True)
        (self.dir / "scripts").mkdir()
        (self.dir / "SKILL.md").write_text(skill, encoding="utf-8")
        (self.dir / "references" / "parameters.md").write_text(params, encoding="utf-8")
        (self.dir / "references" / "reporting-templates.md").write_text(report, encoding="utf-8")
        (self.dir / "scripts" / "calls_registry.json").write_text(json.dumps(registry), encoding="utf-8")

    def check(self, help_text=HELP):
        return cdf.check(self.dir, help_text)[0]

    def cleanup(self):
        shutil.rmtree(self.dir.parent, ignore_errors=True)


class CheckDefaults(unittest.TestCase):
    def setUp(self):
        self.fx = ModuleFixture()

    def tearDown(self):
        self.fx.cleanup()

    def test_consistent_module_passes(self):
        self.assertEqual(self.fx.check(), [])
        _, n_help, n_compared = cdf.check(self.fx.dir, HELP)
        self.assertEqual(n_help, 6)          # --help itself is ignored
        self.assertEqual(n_compared, 6)      # every flag is in the params table too

    def test_optional_override_preserves_native_default(self):
        reg = json.loads(json.dumps(REGISTRY))
        reg['calls'][0]['args']['alpha'].update(value=0.05, cli_default=None,
                                              function_default='0.05')
        fx = ModuleFixture(registry=reg, params=PARAMS.replace('`0.05`', 'none'),
                           report=REPORT.replace('-->0.05<!--', '-->none<!--'))
        try:
            self.assertEqual(fx.check(HELP.replace('default: 0.05', 'default: none')), [])
            self.assertTrue(any('MISMATCH --alpha' in p for p in fx.check()))
            self.assertEqual(reg['calls'][0]['args']['alpha']['function_default'], '0.05')
        finally:
            fx.cleanup()

    def test_normalisation(self):
        self.assertEqual(cdf.norm("`20260925`"), cdf.norm(20260925))
        self.assertEqual(cdf.norm("20260925L"), "20260925")
        self.assertEqual(cdf.norm("0.050"), cdf.norm(0.05))
        self.assertEqual(cdf.norm("5e-2"), cdf.norm("0.05"))
        self.assertEqual(cdf.norm("off (bare switch)"), "off")
        self.assertEqual(cdf.norm(False), "off")
        self.assertEqual(cdf.norm("(required)"), "required")
        self.assertEqual(cdf.norm("--"), "none")
        self.assertEqual(cdf.norm(None), "none")
        self.assertNotEqual(cdf.norm("Nature"), cdf.norm("nature"))   # enum values are case-sensitive

    def test_params_table_mismatch(self):
        fx = ModuleFixture(params=PARAMS.replace("| 20260925 |", "| 20260926 |"))
        try:
            probs = fx.check()
        finally:
            fx.cleanup()
        self.assertEqual(len(probs), 1)
        self.assertTrue(probs[0].startswith("MISMATCH --seed"), probs)
        self.assertIn("references/parameters.md", probs[0])

    def test_help_mismatch(self):
        probs = self.fx.check(HELP.replace("default: nature ", "default: cell   "))
        self.assertTrue(any(p.startswith("MISMATCH --journal") for p in probs), probs)

    def test_registry_mismatch(self):
        reg = json.loads(json.dumps(REGISTRY))
        reg["calls"][0]["args"]["alpha"]["value"] = 0.1
        fx = ModuleFixture(registry=reg)
        try:
            probs = fx.check()
        finally:
            fx.cleanup()
        self.assertEqual(len(probs), 1)
        self.assertIn("MISMATCH --alpha", probs[0])
        self.assertIn("pkg::fit(alpha)", probs[0])

    def test_registry_flag_defaults_bool(self):
        reg = json.loads(json.dumps(REGISTRY))
        reg["flag_defaults"]["strict"] = True
        fx = ModuleFixture(registry=reg)
        try:
            probs = fx.check()
        finally:
            fx.cleanup()
        self.assertTrue(any(p.startswith("MISMATCH --strict") for p in probs), probs)

    def test_marker_mismatch_and_code_span_ignored(self):
        fx = ModuleFixture(report=REPORT.replace("-->0.05<!--", "-->0.01<!--"))
        try:
            probs = fx.check()
        finally:
            fx.cleanup()
        self.assertEqual(len(probs), 1, probs)          # the `0.9` example in a code span is not read
        self.assertIn("(marker)", probs[0])

    def test_skill_table_is_read(self):
        skill = "# x-y\n\n| Flag | Default | Effect |\n|---|---|---|\n| `--journal` | cell | preset |\n"
        fx = ModuleFixture(skill=skill)
        try:
            probs = fx.check()
        finally:
            fx.cleanup()
        self.assertTrue(any("MISMATCH --journal" in p and "SKILL.md" in p for p in probs), probs)

    def test_unknown_flag_in_docs(self):
        fx = ModuleFixture(params=PARAMS + "\n| Flag | Default |\n|---|---|\n| `--lfc` | 1 |\n")
        try:
            probs = fx.check()
        finally:
            fx.cleanup()
        self.assertTrue(any(p.startswith("UNKNOWN --lfc") for p in probs), probs)

    def test_nonconforming_help_line(self):
        probs = self.fx.check(HELP.replace("  --seed <int>                      default: 20260925  random seed",
                                           "  --seed      random seed (default 20260925)"))
        self.assertTrue(any(p.startswith("NONCONFORMING") for p in probs), probs)
        self.assertIn("no --help line follows the os_help() convention", self.fx.check("Usage: nothing\n"))

    def test_cli_with_help_file(self):
        hf = self.fx.dir / "help.txt"
        hf.write_text(HELP, encoding="utf-8")
        out = subprocess.run([sys.executable, str(HERE / "check_defaults.py"), str(self.fx.dir), "--help-file", str(hf)],
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        hf.write_text(HELP.replace("0.05 ", "0.10 "), encoding="utf-8")
        out = subprocess.run([sys.executable, str(HERE / "check_defaults.py"), str(self.fx.dir), "--help-file", str(hf)],
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 1, out.stdout)

    @unittest.skipUnless(shutil.which("Rscript"), "needs Rscript")
    def test_real_rscript_help_from_args_spec(self):
        shared = HERE.parent / "skills" / "_shared" / "scripts" / "args.R"
        run = self.fx.dir / "scripts" / "run_x_y.R"
        run.write_text(
            'source("%s")\n' % shared.as_posix()
            + 'SPEC <- os_arg_spec("Rscript run_x_y.R --outdir <dir>", list(\n'
            + '  os_flag("outdir", "path", required = TRUE, help = "output directory"),\n'
            + '  os_flag("seed", "int", default = 20260925L, help = "random seed"),\n'
            + '  os_flag("alpha", "num", default = 0.05, range = c(0, 1), help = "FDR level"),\n'
            + '  os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "generic"), help = "preset"),\n'
            + '  os_flag("strict", "bool", help = "fail on blockers"),\n'
            + '  os_flag("from-run", "path", help = "upstream run")))\n'
            + 'a <- os_parse_args(SPEC, commandArgs(trailingOnly = TRUE))\n'
            + 'if (isTRUE(a$help)) os_print_help(SPEC)\n', encoding="utf-8")
        out = subprocess.run([sys.executable, str(HERE / "check_defaults.py"), str(self.fx.dir)], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        self.assertIn("6 flag(s) in --help", out.stdout)


class LintR(unittest.TestCase):
    def rules(self, src):
        return [p.split(": ")[1].split(" ")[0] for p in lint_r.lint_text(src, "t.R")]

    def test_clean_code(self):
        src = ('run <- function(args, seed) {\n'
               '  set.seed(seed)\n'
               '  x <- rnorm(10)\n'
               '  idx <- sample(10)\n'
               '  f <- function() runif(1)   # enclosing function is seeded\n'
               '  v <- suppressWarnings(as.numeric("1"))\n'
               '  withr::with_seed(args$seed, sample(3))\n'
               '}\n'
               'g <- function(a) { set.seed(a[["seed"]]); sample.int(4) }\n'
               'h <- function() os_with_seed(seed, rnorm(1))\n'
               '# rnorm(3) in a comment and "sample(3)" in a string are ignored\n'
               'msg <- "options(warn = -1)"\n'
               'resample(1); x$sample(2); my_runif(3)\n')
        self.assertEqual(lint_r.lint_text(src, "t.R"), [])

    def test_lr01_warn_negative(self):
        self.assertEqual(self.rules("options(warn = -1)\n"), ["LR01"])
        self.assertEqual(self.rules("old <- options(digits = 3, warn=-2)\n"), ["LR01"])
        self.assertEqual(self.rules("options(warn = 1)\n"), [])

    def test_lr02_suppress_stage(self):
        self.assertEqual(self.rules("suppressWarnings({\n  fit()\n})\n"), ["LR02"])
        self.assertEqual(self.rules("res <- suppressWarnings(mod_x_compute(args))\n"), ["LR02"])
        self.assertEqual(self.rules("suppressWarnings(os_engine_capture(f(), 's', log))\n"), ["LR02"])
        self.assertEqual(self.rules("x <- suppressWarnings(fit(a,\n  b))\n"), ["LR02"])
        self.assertEqual(self.rules("x <- suppressWarnings(as.integer(y))\n"), [])

    def test_lr03_seed_source(self):
        self.assertEqual(self.rules("set.seed(42)\n"), ["LR03"])
        self.assertEqual(self.rules("set.seed(Sys.time())\n"), ["LR03"])
        self.assertEqual(self.rules("set.seed(NULL)\n"), ["LR03"])
        self.assertEqual(self.rules("set.seed(seed)\nset.seed(args$seed)\nset.seed(args[[\"seed\"]], kind = \"Mersenne-Twister\")\n"), [])

    def test_lr04_unseeded_rng(self):
        self.assertEqual(self.rules("f <- function(n) rnorm(n)\n"), ["LR04"])
        self.assertEqual(self.rules("f <- function(n) {\n  x <- sample(n)\n  set.seed(n)\n}\n"), ["LR04"])   # seeded AFTER use
        # a set.seed inside a sibling function does not seed this one
        self.assertEqual(self.rules("a <- function(s) { set.seed(s) }\nb <- function() {\n  a2 <- 1\n  stats::runif(1)\n}\n"),
                         ["LR04"])

    def test_lr04_seeding_helper(self):
        src = ('fx_rng <- function(seed) set.seed(seed, kind = "Mersenne-Twister")\n'
               'fx <- function(n, seed) { fx_rng(seed); rnorm(n) }\n')
        self.assertEqual(lint_r.lint_text(src, "t.R"), [])

    def test_pragma(self):
        self.assertEqual(self.rules("x <- sample(3)  # lint-ok LR04: permutation order is irrelevant here\n"), [])
        self.assertEqual(self.rules("x <- sample(3)  # lint-ok LR01: wrong rule\n"), ["LR04"])

    def test_cli_and_allowlist(self):
        tmp = pathlib.Path(tempfile.mkdtemp(prefix="omicstat_lint_test_"))
        try:
            (tmp / "scripts").mkdir()
            (tmp / "tests" / "fixtures").mkdir(parents=True)
            (tmp / "scripts" / "bad.R").write_text("options(warn = -1)\n", encoding="utf-8")
            (tmp / "tests" / "fixtures" / "fx.R").write_text("x <- rnorm(3)\n", encoding="utf-8")
            out = subprocess.run([sys.executable, str(HERE / "lint_r.py"), str(tmp)], capture_output=True, text=True)
            self.assertEqual(out.returncode, 1)
            self.assertIn("LR01", out.stdout)
            self.assertIn("1 file(s) scanned", out.stdout)       # the fixture file is allowlisted
            (tmp / "scripts" / "bad.R").write_text("options(warn = 1)\n", encoding="utf-8")
            out = subprocess.run([sys.executable, str(HERE / "lint_r.py"), str(tmp)], capture_output=True, text=True)
            self.assertEqual(out.returncode, 0, out.stdout)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_repository_is_clean(self):
        out = subprocess.run([sys.executable, str(HERE / "lint_r.py")], capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=1)
