#!/usr/bin/env python3
"""Convert the exact R mapping export to parquet; retain source and output SHA.

No registry update or network access. Every identifier stays a string, including
numeric-looking Entrez identifiers. pyarrow is an explicit offline dependency.
"""
import argparse,csv,hashlib,json,pathlib

def export(source, output, refdata_id):
    import pyarrow as pa
    import pyarrow.parquet as pq
    source,output=pathlib.Path(source),pathlib.Path(output)
    if output.exists():raise ValueError("output already exists")
    with source.open(encoding="utf-8",newline="") as f:
        reader=csv.DictReader(f,delimiter="\t");columns=reader.fieldnames;rows=list(reader)
    if not columns or len(columns)<2 or len(set(columns))!=len(columns):raise ValueError("at least two unique identifier columns required")
    table=pa.table({c:pa.array([r[c] or None for r in rows],type=pa.string()) for c in columns})
    output.parent.mkdir(parents=True,exist_ok=True);pq.write_table(table,output,compression="zstd")
    result=dict(refdata_id=refdata_id,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                mapping=dict(path=output.name,format="parquet",sha256=hashlib.sha256(output.read_bytes()).hexdigest()),columns=columns,n_rows=len(rows))
    output.with_suffix(output.suffix+".manifest.json").write_text(json.dumps(result,indent=2)+"\n")
    return result

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("source");p.add_argument("output");p.add_argument("refdata_id")
    a=p.parse_args();print(json.dumps(export(a.source,a.output,a.refdata_id)))
