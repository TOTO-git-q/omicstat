#!/usr/bin/env bash
# Owner freeze: empty string also disables legacy nzchar() write gates.
export OMICSTAT_WRITE_GOLDEN=
# Run every omicstat test. Inside the omicstat-r image (env/test.sh) all of
# them must PASS; elsewhere a test whose R packages are missing is reported as
# SKIP (never silently passed).
# Usage: bash tools/run_tests.sh   (needs Rscript; python3 with mcp==1.28.0)
set -u
cd "$(dirname "$0")/.."
fail=0; skipped=0; test_index=0
log="${TMPDIR:-/tmp}/omicstat_test.$$.log"
# Packages of the acceptance data layer (acceptance/data/acceptance_lib_lock.csv,
# built by acceptance/data/install_acceptance_lib.R) count as present when the
# layer holds them: installed ones on .omicstat-acceptance/library, extracted
# ones as their unpacked tarball.
have_r_pkgs() { Rscript -e '
acc <- ".omicstat-acceptance"; lock <- "acceptance/data/acceptance_lib_lock.csv"
if (dir.exists(file.path(acc, "library"))) .libPaths(c(.libPaths(), file.path(acc, "library")))
ext <- character(0)
if (file.exists(lock)) { l <- utils::read.csv(lock, stringsAsFactors = FALSE)
  if ("mode" %in% names(l)) ext <- l$package[l$mode == "extracted" & dir.exists(file.path(acc, "extracted", l$package))] }
p <- commandArgs(TRUE)
q(status = as.integer(!all(p %in% ext | vapply(p, requireNamespace, logical(1), quietly = TRUE))))' "$@" >/dev/null 2>&1; }
run() {
  local command_rc=0
  echo "== $*"
  if "$@" > "$log" 2>&1; then tail -1 "$log"; else command_rc=$?; grep -v '^PASS' "$log" | tail -20; fail=1; fi
  if [ -n "${OMICSTAT_TEST_LOG_DIR:-}" ]; then
    test_index=$((test_index + 1))
    mkdir -p "$OMICSTAT_TEST_LOG_DIR"
    cp "$log" "$OMICSTAT_TEST_LOG_DIR/$(printf '%03d' "$test_index").log"
    printf '%03d\t%s\n' "$test_index" "$*" >> "$OMICSTAT_TEST_LOG_DIR/index.tsv"
    printf '%03d\t%s\t%s\n' "$test_index" "$command_rc" "$*" >> "$OMICSTAT_TEST_LOG_DIR/status.tsv"
  fi
}
run_r() {  # run_r <script> [required R packages...]
  local script="$1"; shift
  if [ "$#" -gt 0 ] && ! have_r_pkgs "$@"; then
    echo "== Rscript $script"; echo "SKIP: needs R package(s) $* (omicstat-r image + acceptance data layer)"; skipped=$((skipped + 1)); return
  fi
  run Rscript "$script"
}
run python3 env/test_env_config.py
run_r env/r/test_layer_lib.R jsonlite
run_r skills/_shared/tests/test_figures.R ggplot2 ggrepel patchwork ragg svglite jsonlite digest
run_r skills/_shared/tests/test_figures_ext.R ggplot2 ggrepel patchwork ragg svglite jsonlite digest MASS
run_r skills/_shared/tests/test_model_io.R jsonlite digest
run_r skills/_shared/tests/test_figures_standardization.R ragg ggplot2 patchwork systemfonts jsonlite digest
run_r skills/_shared/tests/test_standardization_render.R ragg ggplot2 patchwork systemfonts jsonlite digest
run_r skills/_shared/tests/test_qc_stage_semantics.R ggplot2 patchwork jsonlite digest
run_r skills/seurat-qc/tests/test_synthetic_stage.R Seurat SeuratObject Matrix ggplot2 patchwork jsonlite digest
run_r skills/_shared/tests/test_idmap.R jsonlite digest
run_r skills/_shared/tests/test_idmap_parity.R jsonlite digest
run_r skills/_shared/tests/test_readers_io.R jsonlite digest
run python3 skills/_shared/py/tests/test_idmap.py
run_r skills/_shared/tests/test_contract_registry.R jsonlite digest
run_r skills/_shared/tests/test_omics_shared.R jsonlite digest
run_r skills/_shared/tests/test_user_genesets.R jsonlite digest
run_r skills/_shared/tests/test_scientific_refusals.R SingleCellExperiment SeuratObject rhdf5 jsonlite digest ggplot2
run_r skills/_shared/tests/test_convert.R SeuratObject Seurat SingleCellExperiment zellkonverter basilisk rhdf5 jsonlite digest
run_r skills/_shared/tests/test_effect_table.R
run_r skills/_shared/tests/test_render.R gt
run_r skills/_shared/tests/test_engine_contract.R
run_r tools/test_calls_wrapper_sites.R jsonlite
run_r tools/test_s4_call_defaults.R jsonlite
# Python lane (ENGINEERING_PLAN part 10): config/lock consistency, the shared
# Python layer (standard library only), the lock-3 checker, and the R render
# step with its cross-lane byte parity. The image-level tests of omicstat-py
# run in that image: env/py/test.sh (tools/run_tests_py.sh).
run python3 env/py/test_py_env_config.py
run python3 skills/_shared/py/tests/test_ospy.py
run python3 skills/_shared/py/tests/test_user_genesets.py
run python3 tools/test_check_calls.py
run python3 tools/test_new_module_py.py
run python3 tools/test_build_contracts.py
run_r skills/_shared/tests/test_render_figure_request.R ggplot2 ggrepel patchwork ragg svglite jsonlite digest
run python3 tools/test_tools.py
run python3 tools/sync_registry.py --check
run python3 tools/test_flag_docs.py
run python3 tools/lint_contracts.py
run python3 tools/test_contracts.py
run python3 tools/test_calls_registry_nulls.py
run python3 tools/test_test_runner_status.py
run python3 tools/test_summarize_test_run.py
# test_acceptance.py and scanpy-qc test_stage_report.py need pandas/PIL: they run in the omicstat-py suite (tools/run_tests_py.sh)
run python3 tools/test_candidate_reentry.py
run python3 tools/test_study_contract.py
run python3 mcp/test_study_contract.py
run python3 tools/lint_r.py
run python3 tools/check_skill_frontmatter.py
# A module smoke test lists its R packages in a header line
# "# requires: pkg1 pkg2 ..."; without that line the figure layer's are assumed.
for smoke in skills/*/tests/run_smoke_test.R; do
  [ -f "$smoke" ] || continue
  req="$(grep -m1 '^# requires:' "$smoke" | sed 's/^# requires://; s/,/ /g')"
  # shellcheck disable=SC2086
  run_r "$smoke" ${req:-ggplot2 jsonlite digest}
done
# Canonical golden for modules whose own smoke test has no golden checker (added
# after the original sealing): the canonical acceptance run and its --spec replay
# must reproduce tests/golden_manifest.csv byte for byte (tools/canonical_golden.py).
for gdir in skills/*/; do
  gmod="${gdir%/}"; gmod="${gmod##*/}"
  [ -f "$gdir"tests/acceptance.json ] && [ -f "$gdir"tests/golden_manifest.csv ] || continue
  ls "$gdir"scripts/run_*.R >/dev/null 2>&1 || continue
  if grep -qE 'os_golden_check|golden_check' "$gdir"tests/*.R "$gdir"tests/*.py 2>/dev/null; then continue; fi
  if have_r_pkgs ggplot2 jsonlite digest; then
    # fixed evidence path: proc-roc hashes the absolute input paths into its estimand (model_spec_hash)
    gout="${OMICSTAT_TEST_TMP:-/tmp}/canonical-golden-fixed/$gmod"; rm -rf "$gout"; mkdir -p "$gout"
    run python3 tools/canonical_golden.py "$gmod" --native --check --out "$gout"
  fi
done
run_r skills/dropletutils-emptydrops/tests/test_contracts.R Matrix SingleCellExperiment jsonlite digest
# Processed and genuine BGZF/tabix paths use project-generated artificial data only.

if have_r_pkgs DropletUtils BiocParallel SingleCellExperiment ggplot2 jsonlite digest; then
  run python3 skills/dropletutils-emptydrops/tests/run_native_variants.py
else
  echo "== python3 skills/dropletutils-emptydrops/tests/run_native_variants.py"
  echo "SKIP: needs native DropletUtils/BiocParallel dependency closure"; skipped=$((skipped + 1))
fi
# Candidate model source tests run with explicit package prerequisites.
for module in drc-dose lme4-lmm emmeans-contrast drc-calibrate nlme-dose; do
  pkg="${module%%-*}"; [ "$module" != drc-calibrate ] || pkg=drc
  run_r "skills/$module/tests/run_development_test.R" "$pkg" jsonlite digest
 done
run_r skills/emmeans-contrast/tests/run_serialized_handoff_test.R lme4 emmeans lmerTest pbkrtest jsonlite digest
run_r skills/emmeans-contrast/tests/run_adjustment_audit_test.R lme4 emmeans jsonlite digest
run_r skills/drc-calibrate/tests/run_unit_scope_test.R drc jsonlite digest
run_r skills/nlme-dose/tests/run_unit_scope_test.R nlme jsonlite digest
# Python-lane smoke tests: the engine part runs on any python3 (outside
# omicstat-py the environment verdict is not asserted; see the test header).
for smoke in skills/*/tests/run_smoke_test.py; do
  [ -f "$smoke" ] || continue
  run python3 "$smoke"
done
# Default consistency (--help vs calls_registry.json vs SKILL.md/references)
# for every module with an entry script; --help needs the module's R deps.
for mod in skills/*/; do
  set -- "$mod"scripts/run_*.py
  if [ -f "$1" ]; then run python3 tools/check_defaults.py "${mod%/}"; run python3 tools/check_flag_docs.py "${mod%/}"; run python3 tools/check_calls_py_static.py "${mod%/}"; continue; fi   # Python imports/defaults are asserted in omicstat-py.
  set -- "$mod"scripts/run_*.R
  [ -f "$1" ] || continue
  if have_r_pkgs ggplot2 jsonlite digest; then
    run python3 tools/check_defaults.py "${mod%/}"
    run python3 tools/check_flag_docs.py "${mod%/}"
    run Rscript tools/check_calls.R "${mod%/}"
  else
    echo "== python3 tools/check_defaults.py ${mod%/}"; echo "SKIP: --help needs R package(s) ggplot2 jsonlite digest"; skipped=$((skipped + 1))
  fi
done
run python3 skills/_shared/publication/test_publication_rules.py
run python3 mcp/test_package_identity.py
run python3 mcp/test_lane_image.py
run python3 mcp/test_publication.py
run python3 mcp/test_client.py
rm -f "$log"
echo "== done: $([ $fail -eq 0 ] && echo ALL PASSED || echo FAILURES) ($skipped skipped for missing packages)"
exit $fail
