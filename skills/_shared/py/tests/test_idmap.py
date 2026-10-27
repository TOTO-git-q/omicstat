import csv, hashlib, json, pathlib, sys, tempfile, unittest, warnings
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from ospy.idmap import os_idmap, os_ortholog
from ospy.errors import OmicstatError


def fixture(root):
    p=root/"map.tsv";p.write_text("SYMBOL\tENTREZID\tENSEMBL\nA\t2\tE2\nA\t1\tE1\nA\t1\tE1\nB\t3\tE3\n",encoding="utf-8")
    sha=hashlib.sha256(p.read_bytes()).hexdigest()
    entry=dict(id="test_human",version="synthetic-1",species="Homo sapiens",mapping=dict(path="map.tsv",format="tsv",sha256=sha))
    (root/"registry.json").write_text(json.dumps(dict(entries=[entry])))
    return root/"registry.json",entry


class Idmap(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.tmp.name);self.reg,self.entry=fixture(self.root)
    def tearDown(self):self.tmp.cleanup()
    def runmap(self,ids=("A","B"),policy="expand",**kw):
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            return os_idmap(ids,"SYMBOL","ENTREZID","Homo sapiens","test_human",policy=policy,registry=self.reg,**kw)
    def test_policies_and_loss(self):
        self.assertEqual([r["target_id"] for r in self.runmap()["mappings"]],["1","2","3"])
        self.assertEqual([r["target_id"] for r in self.runmap(policy="first")["mappings"]],["1","3"])
        drop=self.runmap(policy="drop",outdir=self.root/"out")
        self.assertEqual(drop["qc"]["loss_fraction"],.5)
        self.assertEqual(drop["report"][0]["status"],"ambiguous_dropped")
        self.assertTrue((self.root/"out/tables/idmap_report.csv").is_file())
        x=self.runmap(("A","missing","missing"));self.assertEqual(x["qc"]["loss_fraction"],.5)
        self.assertEqual([r["query_index"] for r in x["report"]],[1,2,3])
    def test_sha_species_and_policy_refusals(self):
        with self.assertRaisesRegex(OmicstatError,"OS_INVALID_PARAMETER"):self.runmap(policy="arbitrary")
        with self.assertRaisesRegex(OmicstatError,"OS_INVALID_INPUT"):self.runmap((1,))
        (self.root/"map.tsv").write_text("tampered")
        with self.assertRaisesRegex(OmicstatError,"OS_REFDATA_MISMATCH"):self.runmap()
    def test_ortholog(self):
        self.entry.update(id="ortholog_hsapiens_mmusculus",species=["hsapiens","mmusculus"])
        self.reg.write_text(json.dumps(dict(entries=[self.entry])))
        x=os_ortholog(["B"],"hsapiens","mmusculus",policy="expand",registry=self.reg,from_="SYMBOL",to="ENTREZID")
        self.assertEqual(x["mappings"][0]["target_id"],"3")
        with self.assertRaisesRegex(OmicstatError,"OS_REFDATA_MISSING"):
            os_ortholog(["B"],"mmusculus","hsapiens",policy="expand",registry=self.reg)
    def test_parquet(self):
        try:import pyarrow as pa;import pyarrow.parquet as pq
        except ImportError:self.skipTest("pyarrow not installed; TSV path still tested")
        pq.write_table(pa.table({"SYMBOL":["A","B"],"ENTREZID":["1","3"]}),self.root/"map.parquet")
        self.entry["mapping"]=dict(path="map.parquet",format="parquet",sha256=hashlib.sha256((self.root/"map.parquet").read_bytes()).hexdigest())
        self.reg.write_text(json.dumps(dict(entries=[self.entry])))
        self.assertEqual([r["target_id"] for r in self.runmap()["mappings"]],["1","3"])
    def test_no_root_escape(self):
        self.entry["mapping"]["path"]="../outside.tsv";self.reg.write_text(json.dumps(dict(entries=[self.entry])))
        with self.assertRaisesRegex(OmicstatError,"OS_REFDATA_MISSING"):self.runmap()

if __name__=="__main__":unittest.main()
