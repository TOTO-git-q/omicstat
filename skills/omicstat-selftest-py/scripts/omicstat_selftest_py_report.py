"""omicstat_selftest_py_report.py -- report layer of module omicstat-selftest-py.

Writes the tables, the AnnData object, the figure REQUEST (Python modules do
not draw: the R render step turns figure_data/ into figures/, ENGINEERING_PLAN
10.5), the handoff, the draft, the environment report and the results JSON.
Every file is UTF-8 with LF line endings and without timestamps, so reruns
are byte-identical. ASCII only.
"""
import json
import os

from ospy import feature_table as FT
from ospy import figure_request as FR
from ospy import handoff as H
from ospy import module_kit as K

from omicstat_selftest_py_core import (SP_CLUSTERS, SP_FIXTURE_N, SP_LFC, SP_MODULE, SP_MODULE_VERSION, SP_PADJ)

FIGURES = ("volcano", "umap_clusters")


def write_adata(cells, path):
    """AnnData (cells x genes counts, obs cluster, obsm X_umap) -> .h5ad; None when anndata is missing."""
    try:
        import anndata as ad                                   # noqa: PLC0415
        import numpy as np                                     # noqa: PLC0415
        import pandas as pd                                    # noqa: PLC0415
    except ImportError as exc:
        return {"written": False, "error": "%s" % exc}
    obs = pd.DataFrame({"cluster": pd.Categorical(cells["cluster"], categories=SP_CLUSTERS)},
                       index=pd.Index(cells["cell"], name="cell"))
    var = pd.DataFrame(index=pd.Index(cells["genes"], name="gene"))
    a = ad.AnnData(X=np.asarray(cells["counts"], dtype=np.float32), obs=obs, var=var)
    a.layers["counts"] = a.X.copy()
    a.obsm["X_umap"] = np.column_stack([np.asarray(cells["x"]), np.asarray(cells["y"])])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    a.write_h5ad(path)
    back = ad.read_h5ad(path)
    ok = back.shape == a.shape and list(back.obs["cluster"].cat.categories) == SP_CLUSTERS
    import importlib.metadata as md                             # noqa: PLC0415
    return {"written": True, "shape": list(a.shape), "roundtrip_ok": bool(ok), "anndata": md.version("anndata")}


def render(res, outdir, journal, upstream):
    out = {"feature_table": os.path.join(outdir, "tables", "feature_table.csv"),
           "adata": os.path.join(outdir, "objects", "adata.h5ad")}
    ft = FT.as_feature_table(res["features"])
    FT.write_feature_table(ft, out["feature_table"])
    out["ft"] = ft
    out["adata_info"] = write_adata(res["cells"], out["adata"])
    cells = res["cells"]
    req = FR.FigureRequest(outdir, module=SP_MODULE, module_version=SP_MODULE_VERSION, journal=journal)
    req.add("volcano", "os_volcano", data={"ft": FR.frame(ft)},
            args={"padj_threshold": SP_PADJ, "lfc_threshold": SP_LFC,
                  "contrast_label": "Synthetic fixture: treated vs control",
                  "method_label": "self-test fixture, not an analysis"})
    req.add("umap_clusters", "os_embedding",
            data={"emb": FR.frame({k: cells[k] for k in ("cell", "x", "y", "cluster")},
                                  types={"cluster": "factor"}, levels={"cluster": SP_CLUSTERS})},
            args={"group_col": "cluster", "reduction": "UMAP", "label": True})
    doc = req.to_dict()
    doc["colour_registry_out"] = "objects/colour_registry.json"
    out["request"] = os.path.join(outdir, *FR.REQUEST_REL.split("/"))
    K.write_json(doc, out["request"], sort_keys=False)
    objects = {"feature_table": {"path": out["feature_table"], "type": "feature_table"}}
    if out["adata_info"].get("written"):
        objects["adata"] = {"path": out["adata"], "type": H.ANNDATA_TYPE}
    out["handoff"] = H.write_handoff(outdir, run_id=K.run_id(outdir), module=SP_MODULE,
                                     module_version=SP_MODULE_VERSION, objects=objects, ecosystem="scverse",
                                     state={"selftest": True, "clusters": "synthetic (3)", "seed": res["seed_record"]["seed"]},
                                     upstream_runs=(upstream or {}).get("upstream_runs") or [])
    return out


def _templates(module_dir):
    return K.read_templates(os.path.join(module_dir, "references", "reporting-templates.md"))


def draft(res, qc, counts, outdir, seed, journal, module_dir):
    pr = res["probe"]
    t = _templates(module_dir)
    vals = {"module": SP_MODULE, "module_version": SP_MODULE_VERSION, "py_env_version": pr["py_env_version"] or "unknown",
            "python_version": pr["python_version"], "n_rules": qc["n_rules"], "n_features": "{:,}".format(counts["n_features"]),
            "seed": seed, "journal": journal, "padj": SP_PADJ, "lfc": SP_LFC, "n_cells": len(res["cells"]["cell"]),
            "execution_mode": pr["mode"], "n_triggered": qc["n_triggered"],
            "verdict": "FAIL" if qc["failed"] else "PASS"}
    lines = ["# omicstat-selftest-py: Python-lane environment self-test (not an analysis)", "",
             "This run checked the omicstat Python (scverse) environment. Its table, object and figures come from",
             "a synthetic shape fixture and must never be reported as findings.", "",
             "## Methods", "", K.fill_template(t["methods"], vals), "",
             "## Results", "", K.fill_template(t["results"], vals), ""]
    return K.write_text(lines, os.path.join(outdir, "draft", "methods_results.md"))


def environment_report(res, qc, outdir, rend):
    pr = res["probe"]
    L = ["# omicstat-selftest-py environment report", "",
         "Verdict: **%s** (%d of %d rules triggered)" % ("FAIL" if qc["failed"] else "PASS", qc["n_triggered"], qc["n_rules"]), "",
         "## Rules", "", "| Rule | Check | Severity | Triggered | Message | Action |", "|---|---|---|---|---|---|"]
    for r in qc["table"]:
        cell = lambda s: str(s).replace("|", "\\|")            # noqa: E731
        L.append("| %s | %s | %s | %s | %s | %s |" % (r["id"], r["check"], r["severity"], "yes" if r["triggered"] else "no",
                                                     cell(r["message"]), cell(r["action"])))
    L += ["", "## Session", "",
          "- Python: %s (%s) at %s" % (pr["python_version"], pr["python_implementation"], pr["executable"]),
          "- Pin: Python %s, py_env_version %s (%s)" % (pr["python_pin"], pr["py_env_version"], pr["env_config_path"]),
          "- Execution environment: %s%s" % (pr["mode"], (" (image %s)" % pr["image_id"]) if pr["image_id"] else ""),
          "- Platform: %s" % pr["platform"],
          "- Thread variables: %s; PYTHONHASHSEED=%s" % (", ".join("%s=%s" % kv for kv in pr["threads"].items()), pr["pythonhashseed"]),
          "- torch: %s" % (("%s (cuda=%s)" % (pr["torch"]["version"], pr["torch"]["cuda"])) if pr["torch"]["installed"] else "not installed"),
          "", "## Pinned packages", "", "| Package | Pin | Installed | Importable |", "|---|---|---|---|"]
    for d, v in pr["packages"].items():
        L.append("| %s | %s | %s | %s |" % (d, v["pin"], v["installed"] or "absent", "yes" if v["importable"] else "no"))
    L += ["", "## Outputs", "",
          "- tables/feature_table.csv (synthetic fixture, %d features)" % SP_FIXTURE_N,
          "- objects/adata.h5ad: %s" % ("written, shape %s" % rend["adata_info"]["shape"] if rend["adata_info"].get("written")
                                        else "NOT written (%s)" % rend["adata_info"].get("error")),
          "- figure_data/figure_request.json -> figures/%s (rendered by the R step, see provenance/figure_render.json)"
          % ", figures/".join(FIGURES), ""]
    return K.write_text(L, os.path.join(outdir, "environment_report.md"))


def results_json(res, qc, counts, outdir, rend):
    pr = res["probe"]
    out = dict(counts)
    out.update({"module": SP_MODULE, "module_version": SP_MODULE_VERSION, "py_env_version": pr["py_env_version"],
                "python_version": pr["python_version"], "execution_mode": pr["mode"],
                "environment_ok": not qc["failed"], "n_rules": qc["n_rules"], "n_triggered": qc["n_triggered"],
                "failed_rules": qc["failed_ids"], "n_cells": len(res["cells"]["cell"]),
                "adata_written": bool(rend["adata_info"].get("written")), "figures_requested": list(FIGURES)})
    return K.write_json(out, os.path.join(outdir, "results", "selftest_summary.json"))
