# omicstat-r -- the dedicated, self-contained R environment of omicstat.
# Build ONLY through env/build.sh, which reads every pin from
# env/omicstat-env.json and passes it here; there are no defaults on purpose.
# Build context = repository root.
#
# Caching rule: one COPY + RUN per layer, in env_version order; a change to a
# layer file rebuilds that layer and the ones after it, never the ones before.
ARG BASE_IMAGE
ARG ADDON_BASE_IMAGE
FROM ${BASE_IMAGE} AS original_layers

ARG BIOC_VERSION
ARG CRAN_REPO
ARG ENV_VERSION
LABEL org.omicstat.env_version="${ENV_VERSION}" \
      org.omicstat.bioconductor="${BIOC_VERSION}" \
      org.omicstat.cran_repo="${CRAN_REPO}"

# Determinism (ENGINEERING_PLAN 3.1): single-threaded BLAS/OpenMP; UTF-8 text.
ENV OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    LANG=C.UTF-8 LC_ALL=C.UTF-8 OMICSTAT_CONTAINER=1 OMICSTAT_ENV_DIR=/opt/omicstat/env

# System libraries not in the Bioconductor base (HDF5 for zellkonverter/DropletUtils,
# GLPK for igraph/CellChat, GDAL/GEOS/UDUNITS for monocle3's sf/terra stack),
# plus the figure font (Liberation Sans = Arial metrics) and git for pins.
RUN apt-get update && apt-get install -y --no-install-recommends \
      libhdf5-dev libglpk-dev libgsl-dev libgdal-dev libgeos-dev libproj-dev \
      libudunits2-dev cmake git fonts-liberation \
    && rm -rf /var/lib/apt/lists/* && fc-cache -f

# Pin CRAN to the dated snapshot for every later R session (overrides the
# base image's "latest").
RUN printf '%s\n' "options(repos = c(CRAN = '${CRAN_REPO}'))" \
      "options(BiocManager.check_repositories = FALSE)" >> "${R_HOME}/etc/Rprofile.site" \
    && Rscript -e "stopifnot(as.character(BiocManager::version()) == '${BIOC_VERSION}')"

COPY env/omicstat-env.json /opt/omicstat/env/omicstat-env.json
COPY env/r/ /opt/omicstat/env/r/
COPY env/layers/github_pins.txt /opt/omicstat/env/layers/github_pins.txt

COPY env/layers/L0_base.txt /opt/omicstat/env/layers/
RUN Rscript /opt/omicstat/env/r/install_layer.R /opt/omicstat/env L0_base
COPY env/layers/L1_bulk.txt /opt/omicstat/env/layers/
RUN Rscript /opt/omicstat/env/r/install_layer.R /opt/omicstat/env L1_bulk
COPY env/layers/L2_enrichment.txt /opt/omicstat/env/layers/
RUN Rscript /opt/omicstat/env/r/install_layer.R /opt/omicstat/env L2_enrichment
COPY env/layers/L3_sc_seurat.txt /opt/omicstat/env/layers/
RUN Rscript /opt/omicstat/env/r/install_layer.R /opt/omicstat/env L3_sc_seurat
COPY env/layers/L4_sc_bioc.txt /opt/omicstat/env/layers/
RUN Rscript /opt/omicstat/env/r/install_layer.R /opt/omicstat/env L4_sc_bioc
COPY env/layers/L5_sc_downstream.txt /opt/omicstat/env/layers/
RUN Rscript /opt/omicstat/env/r/install_layer.R /opt/omicstat/env L5_sc_downstream
COPY env/layers/L6_network.txt /opt/omicstat/env/layers/
RUN Rscript /opt/omicstat/env/r/install_layer.R /opt/omicstat/env L6_network
COPY env/layers/L7_figures.txt /opt/omicstat/env/layers/
RUN Rscript /opt/omicstat/env/r/install_layer.R /opt/omicstat/env L7_figures

# Reuse the immutable 2026.09.1 image: all L0-L7 filesystem layers and
# installed versions are inherited, without invalidation by new metadata/pins.
FROM ${ADDON_BASE_IMAGE} AS addons
ARG ENV_VERSION
LABEL org.omicstat.env_version="${ENV_VERSION}"
COPY env/omicstat-env.json /opt/omicstat/env/omicstat-env.json
COPY env/layers/github_pins.txt /opt/omicstat/env/layers/github_pins.txt
COPY env/layers/L8_addons.txt /opt/omicstat/env/layers/
RUN Rscript /opt/omicstat/env/r/install_layer.R /opt/omicstat/env L8_addons

# Prebuild at a fixed path accessible to every runtime uid. Fail the build if
# the environment is unavailable; no runtime network fallback is acceptable.
COPY env/basilisk_pkg_lock.txt /opt/omicstat/env/basilisk_pkg_lock.txt
COPY env/r/test_basilisk_nonroot.R /opt/omicstat/env/r/test_basilisk_nonroot.R
ENV BASILISK_EXTERNAL_DIR=/opt/omicstat/basilisk BASILISK_NO_DESTROY=1
ENV LD_LIBRARY_PATH=/opt/omicstat/basilisk/python-3.14.0/lib
# Relocate the already-prebuilt environment from the verified old image.
# Rebuilding it from PyPI would float transitive packages (e.g. msgspec), so
# retain its exact installed Python versions and verify the fixed path.
RUN mkdir -p /opt/omicstat/basilisk && \
    cp -a /root/.cache/R/basilisk/. /opt/omicstat/basilisk/ && \
    Rscript -e "basilisk::obtainEnvironmentPath(zellkonverter:::zellkonverterAnnDataEnv())" && \
    cp -a /root/.pyenv/versions/3.14.0 /opt/omicstat/basilisk/python-3.14.0 && \
    ln -sfn /opt/omicstat/basilisk/python-3.14.0/bin/python3.14 /opt/omicstat/basilisk/1.24.0/zellkonverter/1.22.0/zellkonverterAnnDataEnv-0.12.3/bin/python3.14 && \
    sed -i 's|/root/.pyenv/versions/3.14.0|/opt/omicstat/basilisk/python-3.14.0|g' /opt/omicstat/basilisk/1.24.0/zellkonverter/1.22.0/zellkonverterAnnDataEnv-0.12.3/pyvenv.cfg && \
    chmod -R a+rX /opt/omicstat/basilisk && \
    find /opt/omicstat/basilisk -type f \( -name "*-00LOCK" -o -name "*_dir.expiry" \) -exec chmod a+rw {} + && \
    setpriv --reuid=65534 --regid=65534 --clear-groups env HOME=/tmp \
      /opt/omicstat/basilisk/1.24.0/zellkonverter/1.22.0/zellkonverterAnnDataEnv-0.12.3/bin/python -c 'import anndata; assert anndata.__version__ == "0.12.3"' && \
    setpriv --reuid=65534 --regid=65534 --clear-groups env HOME=/tmp \
      Rscript /opt/omicstat/env/r/test_basilisk_nonroot.R

COPY env/refdata_registry.json /opt/omicstat/env/refdata_registry.json
COPY env/r/fetch_addon_refdata.R /opt/omicstat/env/r/fetch_addon_refdata.R
RUN Rscript /opt/omicstat/env/r/fetch_addon_refdata.R

RUN Rscript /opt/omicstat/env/r/write_pkg_lock.R /opt/omicstat/pkg_lock.csv
WORKDIR /omicstat
CMD ["R", "--no-save"]
