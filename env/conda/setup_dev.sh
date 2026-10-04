#!/usr/bin/env bash
# setup_dev.sh -- build the omicstat DEV tier: a conda (micromamba) R
# environment for building and testing modules on machines that cannot build
# the locked container (e.g. a cloud session without CRAN/Bioconductor).
#
#   bash env/conda/setup_dev.sh [prefix]      default prefix: /opt/mm/env/omicstat-dev
#
# The dev tier is NOT the gold standard. Versions: R 4.5 + Bioconductor 3.22
# (bioconda) versus R 4.6.1 + Bioconductor 3.23 in the locked image
# (env/omicstat-env.json). Golden baselines written in this tier carry its
# environment signature and are regenerated in the container at S5
# (ENGINEERING_PLAN 3.5: a signature mismatch SKIPs the byte check).
#
# Sources, in order:
#   1. conda packages, exact builds: env/conda/omicstat-dev.explicit.txt
#   2. GitHub-only R packages at the SAME commits as env/layers/github_pins.txt
#      (plus NMF >= 0.23 for CellChat from the CRAN mirror on GitHub)
#   3. airway, pasilla, parathyroidSE from the github.com/bioc mirror (kept from
#      the blocked-network build: the deseq2-wald dev-tier golden baseline was
#      written with pasilla from this mirror)
#   4. HDO.db (DOSE / clusterProfiler dependency) from github.com/YuLab-SMU/HDO.db
#   5. OFFICIAL Bioconductor 3.22 annotation data: GO.db, org.Hs.eg.db,
#      org.Mm.eg.db, celldex. Normally installed by step 1 (bioconda post-link
#      download from bioconductor.org, md5-checked); when that did not happen,
#      force-reinstall the bioconda builds, then fall back to the Bioconductor
#      3.22 source tarball checked against the sha256 in env/refdata_registry.json.
#   6. Reference-data caches (dev tier only): msigdbr gene sets (zenodo) and the
#      celldex references for SingleR (gypsum), into the per-user R caches.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREFIX="${1:-/opt/mm/env/omicstat-dev}"
MM_DIR="${MM_DIR:-/opt/mm}"
WORK="${WORK:-$MM_DIR/build}"
export MAMBA_ROOT_PREFIX="$MM_DIR/root"
mkdir -p "$MM_DIR" "$WORK"

# ---- 0. micromamba -----------------------------------------------------------
if [[ ! -x "$MM_DIR/bin/micromamba" ]]; then
  curl -fsSL https://conda.anaconda.org/conda-forge/linux-64/micromamba-2.9.0-0.tar.bz2 -o "$WORK/mm.tar.bz2"
  tar -xjf "$WORK/mm.tar.bz2" -C "$MM_DIR" bin/micromamba
fi
MM="$MM_DIR/bin/micromamba"

# ---- 1. conda packages (exact builds) ----------------------------------------
# Data packages (bioconductor-airway, -pasilla, -org.*, -go.db, -celldex, ...)
# run a post-link download from bioconductor.org; where that host is blocked
# they end up NOT installed (conda still records them), which step 5 repairs.
"$MM" create -y -p "$PREFIX" --file "$ROOT/env/conda/omicstat-dev.explicit.txt" || true
export PATH="$PREFIX/bin:$PATH"
R_LIB="$PREFIX/lib/R/library"

gh_install() {  # <owner/repo> <sha> [subdir]
  local repo="$1" sha="$2" sub="${3:-}" d="$WORK/$(echo "$1" | tr / _)"
  if [[ ! -d "$d/.git" ]]; then git init -q "$d"; git -C "$d" remote add origin "https://github.com/$repo"; fi
  git -C "$d" fetch -q --depth 1 origin "$sha"
  git -C "$d" checkout -q FETCH_HEAD
  R CMD INSTALL --no-build-vignettes --library="$R_LIB" "$d/$sub"
}

# ---- 2. GitHub-only packages (commits = env/layers/github_pins.txt) -------------
gh_install cran/NMF 65d922b77f88c5cf12adeaddcaaa3f4ae35c7e4e           # 0.28; CellChat needs >= 0.23
gh_install cran/ComICS 3e0b1f9fcc5d5b0ce868ce5ae95eedca66f1f840
while read -r layer pkg repo sha; do
  [[ -z "${layer:-}" || "$layer" == \#* ]] && continue
  [[ "$pkg" == "monocle3" ]] && continue   # bioconda r-monocle3 1.4.27 (same version as the pin)
  gh_install "$repo" "$sha"
done < <(grep -v '^[[:space:]]*#' "$ROOT/env/layers/github_pins.txt")

# ---- 3. data packages from the github.com/bioc mirror (see header) -----------
gh_install bioc/airway 54ec911b1c77b020e6211bc2412cb2bb3b994063
gh_install bioc/pasilla 3c91e8df8add3549129e46b7a7a078fda4e2755a
gh_install bioc/parathyroidSE 706aca801efaa656480107c6d53473028e404ed1

# ---- 4. HDO.db ---------------------------------------------------------------
gh_install YuLab-SMU/HDO.db 2b12de09ff7883231e56a10783c79390807009c0

# ---- 5. official annotation data packages (Bioconductor 3.22) -----------------
# The GO.db stand-in of the blocked-network build (GO.db 3.4.0 data, GO 2016)
# is retired: remove it if an old environment still has it.
if [[ -f "$R_LIB/GO.db/DESCRIPTION" ]] && grep -q '^Version: 3.4.0' "$R_LIB/GO.db/DESCRIPTION"; then
  R CMD REMOVE --library="$R_LIB" GO.db
fi
DATA_PKGS="GO.db org.Hs.eg.db org.Mm.eg.db celldex"
have_data() { Rscript -e "quit(status = !all(vapply(strsplit('$DATA_PKGS', ' ')[[1]], requireNamespace, NA, quietly = TRUE)))"; }
if ! have_data; then
  grep -E '/bioconductor-(go\.db|org\.hs\.eg\.db|org\.mm\.eg\.db|celldex)-' "$ROOT/env/conda/omicstat-dev.explicit.txt" \
    | sed '1i @EXPLICIT' > "$WORK/data_pkgs.txt"
  "$MM" install -y -p "$PREFIX" --force-reinstall --file "$WORK/data_pkgs.txt" || true
fi
if ! have_data; then   # fallback: Bioconductor 3.22 source tarballs, sha256 from the registry
  while read -r pkg url sha; do
    Rscript -e "quit(status = !requireNamespace('$pkg', quietly = TRUE))" && continue
    curl -fsSL "$url" -o "$WORK/$(basename "$url")"
    echo "$sha  $WORK/$(basename "$url")" | sha256sum -c -
    R CMD INSTALL --library="$R_LIB" "$WORK/$(basename "$url")"
  done < <(python3 - "$ROOT/env/refdata_registry.json" <<'PY'
import json, sys
for e in json.load(open(sys.argv[1]))["entries"]:
    if e.get("dev_tier_package"):
        print(e["dev_tier_package"], e["url"], e["sha256"])
PY
)
fi

# ---- 6. reference-data caches (dev tier only; see env/conda/README.md) --------
# msigdbr downloads its pinned release (zenodo, md5 checked by msigdbr) into
# tools::R_user_dir("msigdbr", "cache"); celldex fetches its references from
# gypsum into gypsum::cacheDirectory() (GYPSUM_CACHE_DIR). Both then run offline.
Rscript -e 'invisible(msigdbr::msigdbr_collections())' \
  -e 'for (f in c("HumanPrimaryCellAtlasData", "BlueprintEncodeData", "MonacoImmuneData", "MouseRNAseqData", "ImmGenData")) invisible(getExportedValue("celldex", f)())'

# ---- 7. self-check -------------------------------------------------------------
Rscript "$ROOT/env/conda/check_dev.R"
