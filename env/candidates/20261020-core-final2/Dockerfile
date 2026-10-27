ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY env/candidates/20261020-core-final2/sources /candidate/sources
COPY env/candidates/20261020-core-final2/manifest.json env/candidates/20261020-core-final2/sources.lock.json /candidate/
COPY tools/env/install_candidate.R /candidate/install_candidate.R
COPY env/r/write_pkg_lock.R /candidate/write_pkg_lock.R
RUN Rscript /candidate/install_candidate.R
