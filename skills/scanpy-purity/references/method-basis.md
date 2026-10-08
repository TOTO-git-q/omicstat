# Method basis

Descriptive display workflow, following the supplied coordinator example and the locked APIs. Panel means provide evidence; label-map records the user decision. Neighbour fractions count distinct nonself neighbors. DBSCAN noise and small islands are explicitly flagged. Ingest projects onto a fixed reference representation; agreement is descriptive.

Sources: [Scanpy ingest tutorial](https://scanpy.readthedocs.io/en/stable/tutorials/basics/integrating-data-using-ingest.html), [DBSCAN API](https://scikit-learn.org/stable/modules/generated/sklearn.cluster.DBSCAN.html). Exact installed signatures are recorded in scripts/calls_registry.json.

DBSCAN island detection is performed on cells passing the explicitly requested purity cuts. The exported retained list additionally excludes noise and islands below the explicit minimum size. The source AnnData is never subset by this module.
