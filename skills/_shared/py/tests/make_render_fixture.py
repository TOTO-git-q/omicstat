#!/usr/bin/env python3
"""Fixture writer for skills/_shared/tests/test_render_figure_request.R.

Usage: python make_render_fixture.py <dir>
Writes, with the Python lane's shared layer only (standard library):
  <dir>/run/            a Python-lane run: figure_data/*.csv + figure_request.json
                        (volcano, embedding + colour_registry_out, feature
                        embedding from a vector, heatmap from a matrix),
                        tables/feature_table.csv, objects/adata.h5ad (stand-in
                        bytes) + objects/handoff.json (ecosystem scverse)
  <dir>/parity/         help_py.txt (os_help of PARITY_SPEC), ft_values.json +
                        ft_py.csv, qc_values.json + qc_py.csv
The R test rebuilds the parity objects with the R functions and compares bytes.
Deterministic (random.Random(20260925)). ASCII only.
"""
import json
import math
import os
import pathlib
import random
import sys
import warnings

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))
from ospy import args as A, feature_table as FT, figure_request as FR, handoff as H, module_kit as K  # noqa: E402

PARITY_SPEC = A.os_arg_spec(
    usage="python run_parity.py --outdir <dir> [options]",
    description="Cross-lane help parity fixture.",
    flags=[A.os_flag("outdir", "path", required=True, help="output directory"),
           A.os_flag("seed", "int", default=20260925, help="random seed"),
           A.os_flag("resolution", "num", default=0.5, range=(0.01, 10), help="Leiden resolution"),
           A.os_flag("min-genes", "int", default=200, range=(0, 100000), help="minimum genes per cell"),
           A.os_flag("tiny", "num", default=1e-08, help="a small number"),
           A.os_flag("flavor", "enum", default="seurat_v3", values=["seurat", "seurat_v3", "cell_ranger"], help="HVG flavour"),
           A.os_flag("layer", "string", help="counts layer"),
           A.os_flag("from-run", "path", must_exist=True, help="upstream run directory"),
           A.os_flag("input", "path", must_exist=True, help="input h5ad"),
           A.os_flag("strict", "bool", help="bare switch: exit non-zero on a blocker")],
    exclusive=[("input", "from-run")])


def feature_rows(rng, n=240):
    rows = []
    for i in range(n):
        lfc = rng.gauss(0, 1.2) + (2.5 if i < 20 else (-2.5 if i < 40 else 0))
        p = min(1.0, math.exp(-abs(lfc) * rng.uniform(0.5, 6)))
        rows.append({"feature_id": "ENSG%011d.%d" % (i + 1, 1 + i % 3), "symbol": "GENE%d" % (i + 1),
                     "contrast": "condition: treated vs control", "base_mean": rng.uniform(5, 5000),
                     "log2fc": lfc, "log2fc_se": rng.uniform(0.1, 0.8), "stat": lfc / 0.3, "pvalue": p,
                     "padj": None if i % 37 == 5 else min(1.0, p * 3.3), "method": "fixture Wald",
                     "shrinkage": "none", "n_group1": 3, "n_group2": 3,
                     "filtered_reason": "independent_filtering" if i % 37 == 5 else ""})
    rows.append({"feature_id": "TINY", "contrast": "condition: treated vs control", "log2fc": 1.23456789012345e-12,
                 "pvalue": 1e-300, "padj": 2.5e-298, "method": "fixture Wald", "n_group1": 3, "n_group2": 3,
                 "base_mean": 123456.789012345, "symbol": 'Q"UOTE'})
    return rows


def main(out):
    out = pathlib.Path(out)
    rng = random.Random(20260925)
    run, parity = out / "run", out / "parity"
    parity.mkdir(parents=True, exist_ok=True)

    # ---- parity objects
    (parity / "help_py.txt").write_text("\n".join(A.os_help(PARITY_SPEC)) + "\n", encoding="utf-8", newline="\n")
    rows = feature_rows(rng)
    (parity / "ft_values.json").write_text(json.dumps(rows), encoding="utf-8")
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        ft = FT.as_feature_table(rows)
        FT.write_feature_table(ft, str(parity / "ft_py.csv"))
    qc_rows = [dict(id="PQ-02", check="second", triggered=True, severity="warning", message='says "hi", twice', action="look"),
               dict(id="PQ-01", check="first", triggered=False, severity="blocker", message="fine", action="ignored"),
               dict(id="PQ-03", check="third", triggered=True, severity="error", message="bad", action="fix", evidence="n=3")]
    (parity / "qc_values.json").write_text(json.dumps(qc_rows), encoding="utf-8")
    qc = K.qc_finalize([K.qc_rule(**r) for r in qc_rows], read_first="draft/x.md")
    K.write_qc_results(qc, str(parity / "qcdir"))
    os.replace(parity / "qcdir" / "qc" / "qc_results.csv", parity / "qc_py.csv")

    # ---- a Python-lane run
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        FT.write_feature_table(ft, str(run / "tables" / "feature_table.csv"))
    emb = {"cell": [], "x": [], "y": [], "cluster": []}
    centres = {"B cells": (-4.0, 1.0), "T cells": (3.0, 3.0), "Monocytes": (0.5, -4.0)}
    for k in range(600):
        name = list(centres)[k % 3]
        cx, cy = centres[name]
        emb["cell"].append("cell%04d" % k)
        emb["x"].append(cx + rng.gauss(0, 1.0))
        emb["y"].append(cy + rng.gauss(0, 1.0))
        emb["cluster"].append(name)
    expr = [max(0.0, rng.gauss(2.0 if c == "T cells" else 0.2, 0.6)) for c in emb["cluster"]]
    genes = ["CD3E", "MS4A1", "LYZ", "NKG7"]
    clusters = ["B cells", "Monocytes", "T cells"]
    mat = [[round(rng.gauss(0, 1), 6) for _ in clusters] for _ in genes]
    req = FR.FigureRequest(str(run), module="render-fixture", module_version="0.1.0", journal="nature")
    req.add("volcano", "os_volcano", data={"ft": FR.frame(ft)},
            args={"padj_threshold": 0.05, "lfc_threshold": 1, "label_n": 5, "contrast_label": "treated vs control"})
    req.add("umap_clusters", "os_embedding",
            data={"emb": FR.frame(emb, types={"cluster": "factor"}, levels={"cluster": clusters})},
            args={"group_col": "cluster", "reduction": "UMAP", "label": True})
    req.add("umap_cd3e", "os_feature_embedding",
            data={"emb": FR.frame({k: emb[k] for k in ("cell", "x", "y")}), "values": FR.vector(expr, names=emb["cell"])},
            args={"feature": "CD3E", "reduction": "UMAP", "value_title": "log-normalised expression"})
    req.add("marker_heatmap", "os_heatmap", data={"mat": FR.matrix(mat, genes, clusters)},
            args={"value_title": "z-score", "scale_type": "diverging", "cluster_rows": False, "cluster_cols": False},
            formats=("pdf", "png"))
    d = req.to_dict()
    d["colour_registry_out"] = "objects/colour_registry.json"
    req_path = run / "figure_data" / "figure_request.json"
    K.write_json(d, str(req_path), sort_keys=False)
    (run / "objects").mkdir(parents=True, exist_ok=True)
    (run / "objects" / "adata.h5ad").write_bytes(b"stand-in bytes for an AnnData file")
    H.write_handoff(str(run), "py-run-1", "render-fixture", "0.1.0",
                    {"adata": {"path": str(run / "objects" / "adata.h5ad"), "type": "AnnData"},
                     "feature_table": {"path": str(run / "tables" / "feature_table.csv"), "type": "feature_table"}},
                    ecosystem="scverse", state={"clusters": "leiden_res0.5", "seed": 20260925})
    print("fixture written to", out)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
