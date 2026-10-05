"""Grouping refusal and native score-order display regressions on the anchor."""
import json
from sc_smoke_support import load, run, common


def verify(source, args, output, work):
    import pandas as pd
    import scanpy_markers_core as core
    data = load(source)
    data.obs["condition"] = "ctrl"
    data.obs["cell_label"] = data.obs["cluster"].copy()
    fixture = work / "group_fixture.h5ad"
    data.write_h5ad(fixture)
    def invoke(column, name, error=None, extra=()):
        target = work / name
        argv = common(fixture, target, False, "counts") + ["--cluster-col", column, "--expression-layer", "logcounts", "--purpose", "cluster-description", *extra]
        result = run("scanpy-markers", argv, error=error)
        if error:
            assert column in result.stderr and "muscat-pseudobulk" in result.stderr and "speckle-propeller" in result.stderr
            print(result.stderr.strip())
        return target
    invoke("condition", "refused_condition", "OS_PSEUDOREPLICATION")
    invoke("condition", "refused_reference", "OS_PSEUDOREPLICATION", ["--reference", "ctrl"])
    allowed = invoke("cell_label", "allowed_label")
    for name in ("feature_table", "marker_details", "rank_genes_groups_native"):
        assert (output / ("tables/" + name + ".csv")).read_bytes() == (allowed / ("tables/" + name + ".csv")).read_bytes()
    text = (output / "draft/methods_results.md").read_text()
    results = text.split("## Results", 1)[1].split("## Resolved parameters", 1)[0]
    assert "P values are computed with cells as observations on clusters defined from the same data." in results
    assert "n_significant_rows" not in results and "rows met" not in results and "< 0.05" not in results
    native = load(output).uns["omicstat_markers"]
    want = list(dict.fromkeys(str(gene) for cluster in native["names"].dtype.names for gene in native["names"][cluster][:5]))
    dot = pd.read_csv(output / "tables/marker_dot_data.csv")
    assert list(dict.fromkeys(dot["gene"])) == want
    # A single sample allows varying labels but refuses constant condition above.
    core.group_guard(data, {"cluster-col": "cell_label", "sample-col": "sample"}, None)
    del data.obs["sample"]
    core.group_guard(data, {"cluster-col": "cluster", "sample-col": "sample"}, None)
    from ospy.errors import OmicstatError
    try:
        core.group_guard(data, {"cluster-col": "cell_label", "sample-col": "sample"}, None)
    except OmicstatError as exc:
        assert "OS_PSEUDOREPLICATION" in str(exc) and "sample column" in str(exc)
    else:
        raise AssertionError("missing sample alternate grouping must refuse")
    data.write_h5ad(fixture)
    invoke("cluster", "no_sample_own")
    invoke("cell_label", "no_sample_refused", "OS_PSEUDOREPLICATION")
    print("PASS: sample-level grouping/reference refusals, second cell-level label, missing-sample fallback, caution and native score display")
