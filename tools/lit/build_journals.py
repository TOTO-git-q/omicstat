#!/usr/bin/env python3
"""Verify journals_seed.json against Europe PMC and write journals.json.

A journal is admitted only when a live Europe PMC query ISSN:"<issn>" returns
records whose journalInfo echoes a title matching the seed's 'match' regex, and
the echoed ISSN / eISSN include the queried ISSN. The echo (title, NLM
abbreviation, issn, essn, nlmid, hitCount) is stored as the verification record.
  /opt/retrieval-venv/bin/python tools/lit/build_journals.py
"""
import datetime as dt
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import omlit  # noqa: E402

HERE = Path(__file__).resolve().parent
seed = json.loads((HERE / "journals_seed.json").read_text(encoding="utf-8"))
client = omlit.epmc_client()
today = dt.date.today().isoformat()
admitted, rejected = [], []
for j in seed["journals"]:
    echoes = []
    for issn in j["issn"]:
        doc = client.search(f'ISSN:"{issn}"', result_type="core", page_size=1)
        res = ((doc.get("resultList") or {}).get("result") or [{}])[0]
        info = (res.get("journalInfo") or {}).get("journal") or {}
        echoes.append({"query_issn": issn, "hitCount": doc.get("hitCount", 0), "title": info.get("title"),
                       "medline_abbreviation": info.get("medlineAbbreviation"), "iso_abbreviation": info.get("isoabbreviation"),
                       "issn": info.get("issn"), "essn": info.get("essn"), "nlmid": info.get("nlmid")})
    ok = []
    for e in echoes:
        names = " | ".join(str(x) for x in (e["medline_abbreviation"], e["iso_abbreviation"], e["title"]) if x)
        issn_echoed = e["query_issn"] in {str(e["issn"]).upper(), str(e["essn"]).upper()}
        if e["hitCount"] and issn_echoed and any(re.search(j["match"], n) for n in names.split(" | ")):
            ok.append(e)
    if ok:
        issns = sorted({i for e in ok for i in (e["issn"], e["essn"]) if i and omlit.ISSN_RE.match(str(i).upper())})
        admitted.append({"name": j["name"], "nlm_abbreviation": ok[0]["medline_abbreviation"], "issn": issns, "tier": j["tier"],
                         "nlm_id": ok[0]["nlmid"], "verified_on": today,
                         "verified_via": "; ".join(f"Europe PMC ISSN:\"{e['query_issn']}\" echoed '{e['medline_abbreviation']}' issn={e['issn']} essn={e['essn']} nlmid={e['nlmid']} hitCount={e['hitCount']}" for e in ok)})
        print(f"ADMIT  {j['tier']} {j['name']:45} {issns}")
    else:
        rejected.append({"name": j["name"], "echoes": echoes})
        print(f"REJECT   {j['name']:45} {[(e['query_issn'], e['medline_abbreviation'], e['issn'], e['essn'], e['hitCount']) for e in echoes]}")
out = {"schema": "omicstat.lit.journals.v1",
       "note": "Whitelist gate of the S0 literature layer. Built by build_journals.py from journals_seed.json; every ISSN was echoed by a live Europe PMC query on verified_on. Tier A: L3 exemplars + L4; tier B: L4 breadth only.",
       "tiers": {"A": "flagship / top omics journal (L3-eligible)", "B": "high-quality journal, L4 breadth only"},
       "journals": admitted, "rejected_candidates": rejected}
(HERE / "journals.json").write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"{len(admitted)} admitted, {len(rejected)} rejected")
