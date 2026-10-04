#!/usr/bin/env python3
"""run_omicstat_selftest_py.py -- entry point of module omicstat-selftest-py.

ASCII only. Structure follows ENGINEERING_PLAN lock 2 (3.2 / 10.4):
1 locate _shared | 2 parse_args (--spec replay) | 3 validate params |
4 validate input (--from-run handoff) | 5 compute (registered calls only) |
6 result object | 7 render (tables, object, figure REQUEST, handoff) | 8 QC |
9 provenance | 10 closing line "N of M rules triggered; read X first".
This module is an ENVIRONMENT SELF-TEST of the Python lane: its "input" is the
running interpreter. Figures are drawn afterwards by the R render step
(skills/_shared/scripts/render_figure_request.R in omicstat-r), which the MCP
shell runs right after this script (ENGINEERING_PLAN 10.5).
"""
import os
import sys

# ---- 1. locate _shared -------------------------------------------------------
HERE = os.path.dirname(os.path.abspath(__file__))
MODULE_DIR = os.path.dirname(HERE)
SUITE = os.path.dirname(os.path.dirname(MODULE_DIR))
sys.path.insert(0, os.path.join(SUITE, "skills", "_shared", "py"))
sys.path.insert(0, HERE)

from ospy import args as A                                    # noqa: E402
from ospy import engine_run, handoff as H, module_kit as K    # noqa: E402
from ospy.errors import OmicstatError, run_entry              # noqa: E402

SP_MODULE = "omicstat-selftest-py"
SEED_DEFAULT = 20260925
JOURNALS = ["nature", "cell", "science", "generic"]   # figure presets of fig_style.R::os_journal()

# ---- 2-3. ONE spec: parsing, typed OS_* errors and --help (_shared/py/ospy/args.py)
SPEC = A.os_arg_spec(
    usage="python run_omicstat_selftest_py.py --outdir <dir> [options]",
    description="Environment self-test of the omicstat Python (scverse) lane (not an analysis).",
    flags=[
        A.os_flag("outdir", "path", required=True, help="output directory"),
        A.os_flag("strict", "bool", help="bare switch: exit non-zero when any blocker or error rule is triggered"),
        A.os_flag("seed", "int", default=SEED_DEFAULT, help="seed of the synthetic fixtures (and of set_seed)"),
        A.os_flag("journal", "enum", default="nature", values=JOURNALS, help="figure preset passed to the R render step"),
        A.os_flag("from-run", "path", must_exist=True, help="upstream omicstat-selftest-py run to continue (handoff check)"),
        A.os_flag("spec", "path", must_exist=True, help="replay the argv of a provenance/resolved_spec.json")])


def main(argv):
    argv = K.spec_argv(argv)
    args = A.os_parse_args(SPEC, argv)
    if args["help"]:
        A.os_print_help(SPEC)
        return 0
    seed, journal, strict = args["seed"], args["journal"], args["strict"]

    # ---- 4. input validation (scientific packages are imported only from here on)
    outdir = args["outdir"]
    os.makedirs(outdir, exist_ok=True)
    if not os.path.isdir(outdir):
        raise OmicstatError("OS_INVALID_PARAMETER", "cannot create --outdir %s" % outdir)
    outdir = os.path.abspath(outdir)
    upstream = None
    if args["from-run"]:
        upstream = H.read_handoff(args["from-run"], expect={"feature_table": "feature_table"}, front_end_ecosystem="scverse")
        if upstream["module"] != SP_MODULE:
            raise OmicstatError("OS_HANDOFF_MISMATCH", "--from-run must be an %s run (got %s)" % (SP_MODULE, upstream["module"]))
    import omicstat_selftest_py_core as core                   # noqa: PLC0415
    import omicstat_selftest_py_qc as qcmod                    # noqa: PLC0415
    import omicstat_selftest_py_report as rep                  # noqa: PLC0415
    # Every warning / logging message of the stages goes to qc/engine_warnings.csv
    # (stage, type, message); warnings are echoed as "OS_ENGINE_WARNING: [stage] ..."
    elog = engine_run.EngineLog(outdir)

    # ---- 5-6. compute -> one result object ----------------------------------
    res = elog.capture("compute", core.compute, SUITE, seed)

    # ---- 7. render: table, AnnData, figure request, handoff -----------------
    rend = elog.capture("render", rep.render, res, outdir, journal, upstream)

    # ---- 8. QC -----------------------------------------------------------------
    qc = elog.capture("qc", qcmod.qc, res, rend, outdir)
    counts = core.counts_of(rend["ft"])

    def reports():
        K.write_qc_results(qc, outdir)
        rep.draft(res, qc, counts, outdir, seed, journal, MODULE_DIR)
        rep.environment_report(res, qc, outdir, rend)
        rep.results_json(res, qc, counts, outdir, rend)
    elog.capture("report", reports)

    # ---- 9. provenance ----------------------------------------------------------
    def provenance():
        pr = res["probe"]
        K.write_provenance(
            outdir, SP_MODULE, core.SP_MODULE_VERSION, K.canonical_argv(SPEC, args),
            entry_script=os.path.basename(__file__), seed=seed, upstream=upstream,
            outputs=["tables/feature_table.csv", "qc/qc_results.csv", "figure_data/figure_request.json",
                     "results/selftest_summary.json"],
            seed_record=res["seed_record"],
            extra={"journal": journal, "strict": strict, "execution_mode": pr["mode"],
                   "py_env_version": pr["py_env_version"], "env_config": pr["env_config_path"],
                   "python_version": pr["python_version"],
                   "fixture": {"source": "omicstat_selftest_py_core.feature_fixture / cell_fixture (random.Random)",
                               "n_features": core.SP_FIXTURE_N, "n_cells": len(res["cells"]["cell"]), "seed": seed}})
    elog.capture("provenance", provenance)

    # ---- 10. closing line -----------------------------------------------------------
    print("%d of %d rules triggered; read environment_report.md first" % (qc["n_triggered"], qc["n_rules"]), flush=True)
    if strict and qc["failed"]:
        raise OmicstatError("OS_ENV_CHECK_FAILED", "--strict and rule(s) %s triggered; see %s"
                            % (", ".join(qc["failed_ids"]), os.path.join(outdir, "environment_report.md")))
    return 0


if __name__ == "__main__":
    run_entry(main)
