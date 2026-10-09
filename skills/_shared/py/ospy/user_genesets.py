"""User-supplied local gene-set collections: the Python counterpart of
skills/_shared/scripts/user_genesets.R (CONVENTIONS.md, "User-supplied gene-set
collections").

omicstat never bundles or downloads KEGG, PanglaoDB, MSigDB or similar content.
A user file (a GMT, or for scanpy-annotate a marker-panel JSON derived for
example from PanglaoDB) is accepted with a provenance JSON or with explicit
--gene-sets-source / --gene-sets-version / --gene-sets-id-type, which are never
guessed. The file is hashed at run time and checked against the provenance
sha256; the identifier type must equal the analysis key type (no silent
conversion), a known species must match, and fewer than 10 % of the set genes
present in the analysed features is refused. The record goes to
provenance/user_gene_sets.json, provenance.json and one Methods sentence.
"""
import json
import re
from pathlib import Path

from . import args as A
from . import module_kit as K
from .errors import OmicstatError

ID_TYPES = ("ENTREZID", "SYMBOL", "ENSEMBL")
MIN_OVERLAP = 0.10
MIN_ID_PATTERN = 0.90
ORIGIN = "user-supplied, not bundled with omicstat"
PROV_KEYS = ("source", "name", "version_or_release", "download_time", "urls", "sha256", "terms", "terms_url", "id_type", "species")
PROV_REQUIRED = ("source", "version_or_release", "sha256", "id_type")
CONTRACT_FLAGS = ("gene-sets-provenance", "gene-sets-source", "gene-sets-version", "gene-sets-id-type",
                  "gene-sets-species", "gene-sets-name", "gene-sets-terms")
FLAG_OF = {"source": "--gene-sets-source", "version_or_release": "--gene-sets-version", "id_type": "--gene-sets-id-type",
           "species": "--gene-sets-species", "name": "--gene-sets-name", "terms": "--gene-sets-terms"}
_SPECIES = {"homo sapiens": "Homo sapiens", "human": "Homo sapiens", "hsa": "Homo sapiens", "9606": "Homo sapiens",
            "mus musculus": "Mus musculus", "mouse": "Mus musculus", "mmu": "Mus musculus", "10090": "Mus musculus",
            "rattus norvegicus": "Rattus norvegicus", "rat": "Rattus norvegicus", "rno": "Rattus norvegicus",
            "10116": "Rattus norvegicus"}


def flags(what="user gene-set file", feature_id_type=True):
    out = [A.os_flag("gene-sets-provenance", "path", must_exist=True,
                     help="provenance JSON of the %s (source, name, version_or_release, download_time, urls, sha256, terms, terms_url, id_type, species)" % what),
           A.os_flag("gene-sets-source", "string", help="source of the %s, e.g. PanglaoDB; required without a provenance JSON" % what),
           A.os_flag("gene-sets-version", "string", help="release or version of the %s; required without a provenance JSON" % what),
           A.os_flag("gene-sets-id-type", "enum", values=ID_TYPES, help="identifier type of the %s; required without a provenance JSON" % what),
           A.os_flag("gene-sets-species", "string", help="species of the %s; checked against --species" % what),
           A.os_flag("gene-sets-name", "string", help="display name of the %s; otherwise the provenance name or the file name" % what),
           A.os_flag("gene-sets-terms", "string", help="terms of use of the %s, recorded in provenance and Methods" % what)]
    if feature_id_type:
        out.append(A.os_flag("feature-id-type", "enum", values=ID_TYPES,
                             help="identifier type of the analysed features; required with a declared %s" % what))
    return out


def given(a, feature=False):
    keys = CONTRACT_FLAGS + (("feature-id-type",) if feature else ())
    return any(a.get(k) is not None for k in keys)


def species_canonical(x):
    if x is None or not str(x).strip():
        return None
    return _SPECIES.get(str(x).strip().replace("_", " ").lower(), str(x).strip())


def id_pattern_fraction(ids, id_type):
    ids = list(ids)
    if not ids:
        return 0.0
    entrez = [bool(re.fullmatch(r"[0-9]+", i)) for i in ids]
    ensembl = [bool(re.fullmatch(r"ENS[A-Z]*G[0-9]+([.][0-9]+)?", i)) for i in ids]
    ok = {"ENTREZID": entrez, "ENSEMBL": ensembl, "SYMBOL": [not e and not s for e, s in zip(entrez, ensembl)]}[id_type]
    return sum(ok) / len(ids)


def _scalar(p, k):
    v = p.get(k)
    if v is None:
        return None
    if isinstance(v, bool) or not isinstance(v, (str, int, float)):
        raise OmicstatError("OS_INVALID_INPUT", "provenance JSON key '%s' must be a single string." % k)
    v = str(v).strip()
    return v or None


def read_provenance(path):
    try:
        p = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise OmicstatError("OS_INVALID_INPUT", "--gene-sets-provenance is not valid JSON (%s)." % exc) from exc
    if not isinstance(p, dict):
        raise OmicstatError("OS_INVALID_INPUT", "--gene-sets-provenance must be a JSON object.")
    out = {k: _scalar(p, k) for k in PROV_KEYS if k != "urls"}
    urls = p.get("urls")
    if urls is not None:
        urls = [urls] if isinstance(urls, str) else urls
        if not isinstance(urls, list) or not all(isinstance(u, str) and u.strip() for u in urls):
            raise OmicstatError("OS_INVALID_INPUT", "provenance JSON key 'urls' must be a string or a list of strings.")
        urls = [u.strip() for u in urls] or None
    out["urls"] = urls
    miss = [k for k in PROV_REQUIRED if out.get(k) is None]
    if miss:
        raise OmicstatError("OS_INVALID_INPUT", "provenance JSON lacks required key(s) %s (required: %s)." % (", ".join(miss), ", ".join(PROV_REQUIRED)))
    out["sha256"] = out["sha256"].lower()
    if not re.fullmatch(r"[0-9a-f]{64}", out["sha256"]):
        raise OmicstatError("OS_INVALID_INPUT", "provenance JSON sha256 must be 64 hexadecimal characters.")
    if out["id_type"] not in ID_TYPES:
        raise OmicstatError("OS_INVALID_INPUT", "provenance JSON id_type '%s' is not one of %s." % (out["id_type"], ", ".join(ID_TYPES)))
    return out


def resolve(path, a, sets, kind="marker-panel file"):
    """Describe a user file whose gene sets (name -> genes) were already parsed."""
    prov_path = a.get("gene-sets-provenance")
    prov = read_provenance(prov_path) if prov_path else None
    explicit = {"source": a.get("gene-sets-source"), "version_or_release": a.get("gene-sets-version"),
                "id_type": a.get("gene-sets-id-type"), "species": a.get("gene-sets-species"),
                "name": a.get("gene-sets-name"), "terms": a.get("gene-sets-terms")}
    if prov is None:
        miss = [k for k in ("source", "version_or_release", "id_type") if explicit[k] is None]
        if miss:
            raise OmicstatError("OS_MISSING_PARAMETER", "a user %s without --gene-sets-provenance needs %s; source, version and identifier type are never guessed."
                                % (kind, ", ".join(FLAG_OF[k] for k in miss)))
        fields = dict(explicit, download_time=None, urls=None, terms_url=None)
        fields_from = "command line (no provenance JSON)"
    else:
        for k, v in explicit.items():
            pv = prov.get(k)
            if v is None or pv is None:
                continue
            same = species_canonical(v) == species_canonical(pv) if k == "species" else str(v).strip() == pv
            if not same:
                raise OmicstatError("OS_CONFLICTING_PARAMETERS", "%s '%s' disagrees with the provenance JSON value '%s'." % (FLAG_OF[k], v, pv))
        fields = dict(prov)
        for k, v in explicit.items():
            if fields.get(k) is None and v is not None:
                fields[k] = v
        fields_from = "provenance JSON"
    sha = K.sha256_file(path)
    if prov is not None and sha != prov["sha256"]:
        raise OmicstatError("OS_REFDATA_MISMATCH", "the %s's sha256 (%s) differs from the provenance JSON sha256 (%s); the file changed after download or the provenance belongs to another file. Supply the matching file and provenance."
                            % (kind, sha, prov["sha256"]))
    members = sorted({g for genes in sets.values() for g in genes})
    frac = id_pattern_fraction(members, fields["id_type"])
    if frac < MIN_ID_PATTERN:
        raise OmicstatError("OS_GENE_SET_ID_MISMATCH", "only %.1f%% of the %d unique gene IDs in the %s have the form of %s identifiers (first IDs: %s); the declared identifier type does not describe this file."
                            % (100 * frac, len(members), kind, fields["id_type"], ", ".join(members[:3])))
    return {"name": fields.get("name") or Path(path).stem, "name_from": fields_from if fields.get("name") else "file name",
            "source": fields["source"], "version_or_release": fields["version_or_release"],
            "download_time": fields.get("download_time"), "urls": fields.get("urls"), "terms": fields.get("terms"),
            "terms_url": fields.get("terms_url"), "id_type": fields["id_type"],
            "species": species_canonical(fields.get("species")), "species_declared": fields.get("species"),
            "sha256": sha, "sha256_verified_against_provenance": prov is not None, "file_kind": kind,
            "gene_set_file": Path(path).name, "provenance_file": Path(prov_path).name if prov_path else None,
            "provenance_sha256": K.sha256_file(prov_path) if prov_path else None, "fields_from": fields_from,
            "n_sets": len(sets), "n_unique_genes": len(members), "id_form_fraction": round(frac, 6),
            "origin": ORIGIN, "bundled_with_omicstat": False,
            "kegg_term_id_exclusion": "not applied: it covers bundled/registered collections only"}


def check(record, sets, key_type, universe, universe_label, key_flag, analysis_species=None):
    if key_type is None:
        raise OmicstatError("OS_MISSING_PARAMETER", "a declared user gene-set file needs %s, the identifier type of the analysed features." % key_flag)
    if record["id_type"] != key_type:
        raise OmicstatError("OS_GENE_SET_ID_MISMATCH", "the user gene sets use %s identifiers but the analysed features are %s (%s); omicstat does not convert identifiers silently. Supply gene sets keyed by %s, or re-key the input and declare it."
                            % (record["id_type"], key_type, key_flag, key_type))
    sp = species_canonical(analysis_species)
    if sp is not None and record["species"] is not None and sp != record["species"]:
        raise OmicstatError("OS_GENE_SET_SPECIES_MISMATCH", "the user gene sets are for %s but the analysis is %s; supply gene sets of the analysed species." % (record["species"], sp))
    genes = sorted({g for v in sets.values() for g in v})
    uni = set(map(str, universe))
    present = sum(g in uni for g in genes)
    frac = present / len(genes) if genes else 0.0
    if frac < MIN_OVERLAP:
        raise OmicstatError("OS_GENE_SET_LOW_OVERLAP", "only %d of %d unique gene-set genes (%.1f%%) are present in %s (%d features); under 10%% usually means the wrong identifiers (type, version suffix or species). Check %s and the identifier type of the user file."
                            % (present, len(genes), 100 * frac, universe_label, len(uni), key_flag))
    out = dict(record)
    out.update(analysis_key_type=key_type, analysis_species=sp or "not declared by the analysis",
               species_check="matched" if sp is not None and record["species"] is not None else "not checked: species unknown on one side",
               overlap={"universe": universe_label, "n_universe": len(uni), "n_set_genes": len(genes), "n_present": present,
                        "fraction": round(frac, 6), "minimum_fraction": MIN_OVERLAP,
                        "n_sets_without_overlap": sum(not any(g in uni for g in v) for v in sets.values())})
    return out


def methods_sentence(rec):
    sp = " (%s)" % rec["species"] if rec.get("species") else ""
    when = " on %s" % rec["download_time"] if rec.get("download_time") else " (retrieval date not stated)"
    terms = ", used under %s" % rec["terms"] if rec.get("terms") else ", terms of use not stated"
    ov = rec.get("overlap")
    tail = "" if not ov else " %d of %d unique set genes (%.1f%%) were present in %s." % (ov["n_present"], ov["n_set_genes"], 100 * ov["fraction"], ov["universe"])
    return ("Gene sets: %s%s, retrieved from %s%s, release %s%s; supplied by the user, not bundled with omicstat. The %s (SHA-256 %s) held %d sets of %s identifiers.%s"
            % (rec["name"], sp, rec["source"], when, rec["version_or_release"], terms, rec.get("file_kind", "gene-set file"), rec["sha256"], rec["n_sets"], rec["id_type"], tail))


def write_record(outdir, rec):
    K.write_json(rec, str(Path(outdir) / "provenance/user_gene_sets.json"))
