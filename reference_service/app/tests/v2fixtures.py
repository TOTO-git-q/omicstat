"""Synthetic Europe PMC / JATS fixtures for gate tests (no network). omicstat fork: omics journal and signals."""
from __future__ import annotations

import datetime as dt
import json
import importlib.util
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

TODAY = dt.datetime(2026, 9, 20, 8, tzinfo=dt.timezone.utc)
GENOME_BIOL = {"title": "Genome biology", "issn": "1474-7596", "essn": "1474-760X"}  # whitelisted omics journal, tier A
STAT_MED = GENOME_BIOL  # name kept from the base fixtures
OFF_LIST = {"title": "Some unlisted journal", "issn": "9999-9999"}

# One Methods paragraph that satisfies every omicstat module profile's signal (and require) regex.
ALL_SIGNALS = " ".join([
    "Differential expression was tested with DESeq2 using the Wald test and lfcShrink.",
    "The variance stabilizing transformation was followed by principal component analysis of the DESeq2 object.",
    "A DESeq2 likelihood ratio test (LRT) compared the full and reduced models.",
    "edgeR quasi-likelihood F-tests used glmQLFit and glmQLFTest.",
    "The limma voom method transformed the counts.",
    "Affymetrix microarray intensities were analysed with limma.",
    "The limma duplicateCorrelation function modelled repeated samples.",
    "ComBat_seq corrected the batch effect and svaseq estimated surrogate variables.",
    "clusterProfiler enrichGO performed over-representation analysis.",
    "clusterProfiler gseGO performed gene set enrichment analysis.",
    "clusterProfiler compareCluster compared the groups.",
    "fgsea ranked pathways with fgseaMultilevel.",
    "GSVA gene set variation analysis scored every sample.",
    "The limma camera function tested gene sets.",
    "Seurat quality control removed low-quality cells with high mitochondrial content.",
    "Seurat FindClusters clustering was visualised with UMAP.",
    "Harmony integration was run in Seurat with RunHarmony.",
    "Seurat FindAllMarkers identified marker genes.",
    "Seurat AddModuleScore computed module scores.",
    "scater quality control used perCellQCMetrics and isOutlier.",
    "scran computeSumFactors and modelGeneVar preceded clustering.",
    "batchelor fastMNN performed batch correction.",
    "scran scoreMarkers identified marker genes.",
    "AUCell scored gene-set activity.",
    "Cells were annotated using SingleR.",
    "muscat pseudobulk differential state analysis used aggregateData and pbDS.",
    "The speckle propeller method tested cell type proportions.",
    "CellChat inferred ligand-receptor communication.",
    "monocle3 learn_graph and order_cells estimated pseudotime trajectories.",
    "slingshot inferred lineages and pseudotime.",
    "WGCNA built a weighted gene co-expression network.",
    "maftools summarised somatic mutation data with oncoplot.",
    "immunedeconv estimated immune cell fractions.",
    "scanpy quality control used calculate_qc_metrics.",
    "scanpy Leiden clustering used highly variable genes.",
    "scanpy rank_genes_groups found marker genes with the Wilcoxon test.",
    "scVI latent space integration removed batch effects.",
    "scANVI label transfer performed cell type annotation.",
])

# A synthetic meta-analysis profile: no omicstat module uses the meta_filter path, but the gate code
# for it is retained from the base, so it is exercised with this fixture profile file.
META_PROFILE = {"module": "fixture-meta", "epmc_query": '(METHODS:"random-effects meta-analysis")', "meta": True,
                "signal_regex": "random[- ]effects meta[- ]analys[ie]s",
                "exclude_regex": "(?i)\\bnarrative review\\b", "profile_status": "ok"}


def profiles_with_meta(directory) -> Path:
    """Write discovery_profiles.json plus META_PROFILE into `directory`; return the path."""
    raw = json.loads((Path(__file__).resolve().parents[1] / "discovery_profiles.json").read_text(encoding="utf-8"))
    raw["profiles"] = list(raw["profiles"]) + [META_PROFILE]
    path = Path(directory) / "profiles_with_meta.json"
    path.write_text(json.dumps(raw), encoding="utf-8")
    return path


def result(n: int | str, *, journal=STAT_MED, year="2026", pubtypes=("Journal Article",), title=None, abstract="",
           pmcid=True, first_date=None) -> dict:
    n = str(n)
    item = {"source": "MED", "pmid": n, "doi": f"10.9999/fixture.{n}", "title": title or f"Fixture method paper {n}",
            "journalInfo": {"journal": dict(journal)}, "pubYear": year, "pubTypeList": {"pubType": list(pubtypes)},
            "abstractText": abstract}
    if pmcid:
        item["pmcid"] = "PMC" + n
    if first_date:
        item["firstPublicationDate"] = first_date
    return item


def jats(pmcid: str, *, methods=ALL_SIGNALS, intro="", results="", license_text="Creative Commons Attribution",
         nested=False, permissions=None) -> bytes:
    methods_sec = (f"<sec id='s2'><title>Methods</title><sec id='s2.1'><title>Statistical analysis</title><p>{methods}</p></sec></sec>"
                   if nested else f"<sec id='s2'><title>Methods</title><p>{methods}</p></sec>")
    block = permissions if permissions is not None else "<permissions><license><license-p>" + license_text + "</license-p></license></permissions>"
    return ("<article><front><article-meta><article-id pub-id-type='pmc'>" + pmcid + "</article-id>"
            + block + "</article-meta></front><body>"
            + (f"<sec id='s1'><title>Introduction</title><p>{intro}</p></sec>" if intro else "")
            + methods_sec
            + (f"<sec id='s3'><title>Results</title><p>{results}</p></sec>" if results else "")
            + "</body></article>").encode()


class Fetcher:
    """Routes search vs full-text URLs; search pages come from a callable(query, call_no)."""
    def __init__(self, pages=None, bodies=None, default_body=None):
        self.pages = pages or (lambda query, n: [])
        self.bodies = bodies or {}
        self.default_body = default_body
        self.urls: list[str] = []
        self.search_queries: list[str] = []
        self.fulltext: list[str] = []

    def __call__(self, url: str) -> bytes:
        self.urls.append(url)
        if url.endswith("/fullTextXML"):
            pmcid = url.rsplit("/", 2)[-2]
            self.fulltext.append(pmcid)
            if pmcid in self.bodies:
                return self.bodies[pmcid]
            return (self.default_body or jats)(pmcid)
        query = parse_qs(urlparse(url).query)["query"][0]
        self.search_queries.append(query)
        records = self.pages(query, len(self.search_queries))
        return json.dumps({"hitCount": len(records), "nextCursorMark": "AoE" + str(len(self.search_queries)),
                           "resultList": {"result": records}}).encode()


class UniqueStream:
    """Every search returns `size` never-seen whitelisted results."""
    def __init__(self, size=5, start=100000):
        self.size, self.next = size, start

    def __call__(self, query, n):
        out = [result(self.next + i) for i in range(self.size)]
        self.next += self.size
        return out


RIGHTS = json.loads((Path(__file__).resolve().parent / "fixtures" / "rights_permissions.json").read_text(encoding="utf-8"))


def load_reference_server():
    """Import this fork's server.py by path (the omicstat bridge puts another server.py on sys.path)."""
    name = "_omicstat_reference_server_under_test"
    if name in sys.modules:
        return sys.modules[name]
    path = Path(__file__).resolve().parents[1] / "server.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module
