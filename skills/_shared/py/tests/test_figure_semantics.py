"""Synthetic adversarial tests; no real person, paper pixel or native estimator."""
import copy
import json
import math
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ospy import figure_semantics as S
from ospy.errors import OmicstatError


def fixture():
    source = dict(id=["z", "a", "q"], person=["P1", "P2", "P1"], value=[.2, .3, None], flag=[True, False, True])
    lay = S.layer("observations", source, ["id"], "observed", "probability", "fraction", source["person"], "people", population_id="synthetic")
    st = S.statistic("raw", [0, .053, None], source["id"], "raw_p", method="supplied t", adjustment="none", family_id="three", family_size=3, threshold=.05)
    return S.definition("probability", "visit", "people", "fraction", dict(status="known", ids=source["id"], rule="all invented rows"), dict(status="known", ids=source["id"], rule="all invented rows"), "none", [lay], statistics=[st])


class SemanticsTest(unittest.TestCase):
    def bad(self, f, *args, **kwargs):
        with self.assertRaises(OmicstatError): f(*args, **kwargs)

    def test_ids_and_hash(self):
        a=dict(id=["b", "a"], number=[1., -0.], text=["σ", "a:b"])
        h=S.table_sha256(a, a["id"])
        b={k:list(reversed(v)) for k,v in reversed(list(a.items()))}
        self.assertEqual(h, S.table_sha256(b, b["id"]))
        self.assertNotEqual(h, S.table_sha256(dict(a, number=[1., None]), a["id"]))
        self.bad(S.source_ids,dict(id=[1,2]),["id"])
        self.bad(S.source_ids,dict(id=["a","a"]),["id"])
        self.assertEqual(S.source_ids(dict(a=["a|b","a"],b=["c","b|c"]),["a","b"]), ['["a|b","c"]','["a","b|c"]'])

    def test_integer_binary64_contract(self):
        for value in (2**53 + 1, -(2**53 + 1), 2**1024, -(2**1024), 10**400):
            with self.subTest(rejected=value):
                table = dict(id=["a"], number=[value])
                self.bad(S.table_sha256, table, table["id"])
                self.bad(S.layer, "large", table, ["id"], "observed", "value", "unknown")
        for value in (0, 2**53 - 1, 2**53, 2**53 + 2, -(2**53 + 2), 2**100, ((2**53 - 1) << 971)):
            with self.subTest(exact=value):
                table = dict(id=["a"], number=[value])
                self.assertEqual(S.table_sha256(table, table["id"]), S.table_sha256(dict(id=["a"], number=[float(value)]), table["id"]))

    def test_metadata_tamper(self):
        d=fixture(); S.validate_definition(json.loads(json.dumps(d,sort_keys=True)))
        for mutation in [lambda x:x["layers"][0]["raw_source"]["value"].__setitem__(0,.9),
                         lambda x:x["layers"][0].__setitem__("n_independent",3),
                         lambda x:x["layers"][0].__setitem__("n_observations",2),
                         lambda x:x["layers"][0]["states"]["source_id"].__setitem__(0,"alien"),
                         lambda x:x["statistics"][0]["decision"].__setitem__("q","not_below_threshold"),
                         lambda x:x["statistics"][0].__setitem__("n_zero",0),
                         lambda x:x["subset"]["ids"].append("alien")]:
            v=copy.deepcopy(d); mutation(v); self.bad(S.validate_definition,v)
        self.assertEqual(d["layers"][0]["n_independent"],2)
        self.assertEqual(d["statistics"][0]["decision"]["q"],"unknown")

    def test_unknown_and_roles(self):
        d=fixture(); source=d["layers"][0]["raw_source"]
        l=S.layer("grid",source,["id"],"model_grid","probability","fraction")
        self.assertEqual(l["n_observations"],0);self.assertIsNone(l["n_independent"])
        self.bad(S.layer,"bad",source,["id"],"fitted", "q","unknown")
        self.bad(S.layer,"bad",source,["id"],"observed","q","unknown",["a","b","a"])

    def test_nonfinite_roundtrip(self):
        d=fixture();d["statistics"]=[];d["layers"]=[S.layer("inf",dict(id=["p","n","m"],value=[math.inf,-math.inf,None]),["id"],"reference","value","unknown")]
        S.validate_definition(json.loads(json.dumps(d,allow_nan=False)))
        v=copy.deepcopy(d);v["layers"][0]["nonfinite_cells"][0]["kind"]="negative_infinity";self.bad(S.validate_definition,v)
        v=copy.deepcopy(d);v["layers"][0]["nonfinite_cells"].append(v["layers"][0]["nonfinite_cells"][0]);self.bad(S.validate_definition,v)

    def test_uncertainty(self):
        rows=dict(source_id=["a"],lower=[.1],estimate=[.2],upper=[1.05])
        u=S.uncertainty("probability","CI","supplied Wald","pointwise","unknown","available",rows,.95,domain=[0,1])
        self.assertEqual(u["out_of_domain_ids"],["a"]); self.assertEqual(u["rows"]["upper"],[1.05])
        self.bad(S.uncertainty,"q","CI","supplied","pointwise","unknown","available",rows)
        self.bad(S.uncertainty,"q","SD","supplied","distribution","unknown","available",rows,.95)
        self.bad(S.uncertainty,"q","CI","supplied","simultaneous_grid","unknown","available",rows,.95)
        v=copy.deepcopy(u);v["rows"]["estimate"]=[2];self.bad(S.validate_uncertainty,v,["a"])
        v=copy.deepcopy(u);v["rows"]["source_id"]=["alien"];self.bad(S.validate_uncertainty,v,["a"])
        self.bad(S.uncertainty,"q","none","none","not_applicable","not_applicable","unavailable")
        S.uncertainty("q","none","none","not_applicable","not_applicable","unavailable",reason="not computed")

    def test_ratios(self):
        a=S.ratio("localization",[str(i) for i in range(320)],[str(i) for i in range(467)],"people","people",320/467)
        b=S.ratio("same_visit",[str(i) for i in range(137)],[str(i) for i in range(320)],"people","people",137/320)
        self.assertNotEqual(a["quantity"],b["quantity"])
        self.bad(S.ratio,"bad",["a"],["b"],"people","people",1)
        self.bad(S.ratio,"zero",[],[],"people","people",0)
        self.assertIsNone(S.ratio("zero",[],[],"people","people",None)["estimate"])
        self.bad(S.ratio,"rounded",["a"],["a","b","c"],"p","p",.33)

    def test_statistics(self):
        for kind in S.STATISTICS:
            self.assertEqual(S.statistic("a",[0,.053,1,None],["1","2","3","4"],kind)["statistic_kind"],kind)
        self.bad(S.statistic,"a",[-.1],["1"],"raw_p")
        self.bad(S.statistic,"a",[math.inf],["1"],"qvalue")
        self.bad(S.statistic,"a",[.1],["1"],"raw_p",adjustment="BH")
        self.bad(S.statistic,"a",[.1,.2],["1","2"],"adjusted_p",family_size=1)
        # Input rows with explicit unavailable results need not be members of
        # the native adjustment family. They remain in the source universe.
        s = S.statistic("native",[.1,None,.2,None],["1","2","3","4"],"adjusted_p",family_size=2)
        self.assertEqual((s["n_reported"],s["n_finite"],s["n_missing"],s["family_size"]),(4,2,2,2))
        self.bad(S.statistic,"native",[.1,None,.2,None],["1","2","3","4"],"adjusted_p",family_size=1)
        self.assertEqual(S.statistic("none",[None,None],["1","2"],"adjusted_p",family_size=0)["n_finite"],0)

    def test_transforms(self):
        d=S.display_transform([25000],"log",unit="seconds",ticks=[25000],reference=[1])
        self.assertAlmostEqual(d["display"][0],10.126631103850338)
        self.assertEqual(d["display"],d["ticks_display"]);self.assertEqual(d["reference_display"],[0])
        raw=[.2,.8,0,-1];d=S.display_transform(raw,"log",invalid="missing")
        self.assertEqual(d["raw"],raw); self.assertEqual(d["state"][2:],["out_of_domain"]*2)
        self.bad(S.analysis_values,d); self.assertEqual(S.analysis_values(d["raw"]),raw)
        self.bad(S.display_transform,[1],"log",source_scale="log")
        self.bad(S.display_transform,[1],"inverse_logit",source_scale="latent")
        self.assertEqual(S.display_transform([0],"exp",source_scale="log_link")["display"],[1])
        d=S.display_transform([.5,2],"folded_ratio");self.assertEqual(d["display"],[2,2]);self.assertFalse(d["definition"]["direction_preserved"])

    def test_shared_population_and_true_zero(self):
        d=fixture();other=copy.deepcopy(d["layers"][0]);other["id"]="other"
        other["independent_ids"]["z"]="other_person";other["n_independent"]=3
        d["layers"].append(other);self.bad(S.validate_definition,d)
        raw=dict(id=["a"],value=[1])
        states=dict(source_id=["a"],state=["true_zero"],reason=["declared"],source_column=["value"])
        self.bad(S.layer,"bad",raw,["id"],"observed","q","unknown",states=states)
        raw["value"]=[0];self.assertEqual(S.layer("ok",raw,["id"],"observed","q","unknown",states=states)["n_observations"],1)

    def test_joint_source(self):
        joint=dict(kind="covariance",parameter_ids=["A","B"],weights=dict(A=1,B=-1),source_sha256="a"*64,supplied_covariance=[[1,.8],[.8,1]],paired_draws=None,draw_ids=None,contrast_variance=.4,interval_computed=False)
        rows=dict(source_id=["a"],lower=[.1],estimate=[.2],upper=[.4])
        S.uncertainty("q","CI","supplied","simultaneous_grid","people","available",rows,.95,joint_source=joint)
        bad=copy.deepcopy(joint);bad["supplied_covariance"]=[[1,2],[2,1]]
        self.bad(S.uncertainty,"q","CI","supplied","simultaneous_grid","people","available",rows,.95,joint_source=bad)
        self.bad(S.uncertainty,"q","CI","supplied","simultaneous_grid","people","available",rows,.95,joint_source={"kind":"declared"})

    def test_value_columns_and_requests(self):
        self.bad(S.layer,"prob",dict(id=["a"],value=[1.2]),["id"],"observed","probability","fraction",value_columns=["value"])
        self.assertEqual(S.layer("latent",dict(id=["a"],value=[-2]),["id"],"model_grid","latent score","unknown",value_columns=["value"])["value_columns"],["value"])
        from ospy.figure_request import FigureRequest,frame,validate_request
        with tempfile.TemporaryDirectory() as root:
            request=FigureRequest(root,"synthetic","0")
            self.bad(request.add,"bad","os_diag_xy",dict(df=frame(dict(id=["a"],value=[1]))),evidence_refs=[dict(family="test",status="accepted")])
            self.assertEqual(request.figures,[])
            d=fixture();request.add("ok","os_diag_xy",dict(df=frame(d["layers"][0]["raw_source"])),definition=d)
            path=request.write();self.assertEqual(validate_request(root),[])
            changed=json.loads(Path(path).read_text());changed["figures"][0]["definition"]["layers"][0]["raw_source"]["value"][0]=999
            Path(path).write_text(json.dumps(changed));self.assertTrue(validate_request(root))

    def test_evidence(self):
        r=dict(record_id="0242",path="record.json",independent_figure_key="one",sha256="a"*64,source_ref="pinned",support="transferable_design_only",eligible_for_family=True)
        entry=dict(family="test",status="pending",records=[r],independent_records=0)
        S.validate_evidence_refs([entry])
        entry["independent_records"]=1;self.bad(S.validate_evidence_refs,[entry])
        entry["independent_records"]=0;entry["status"]="sufficient_design_evidence";self.bad(S.validate_evidence_refs,[entry])
        entry["status"]="pending";r["path"]="../outside";self.bad(S.validate_evidence_refs,[entry])


if __name__ == "__main__":
    if len(sys.argv)>1 and sys.argv[1]=="--fixture":
        Path(sys.argv[2]).write_text(json.dumps(fixture(),ensure_ascii=False,sort_keys=True,allow_nan=False,indent=2)+"\n")
    else: unittest.main()
