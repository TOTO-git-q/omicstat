# omicstat-py -- the locked Python (scverse) environment of omicstat
# (ENGINEERING_PLAN 10.4 lock 1). Second image next to omicstat-r; the R
# image is unchanged. Build ONLY through env/py/build.sh, which reads every pin
# from env/omicstat-env.json ("python_lane") and passes it here; there are no
# defaults on purpose. Build context = env/ (keeps the context tiny and leaves
# the repository-root .dockerignore of omicstat-r untouched).
#
# Install rule: every file comes from env/py_lock.txt (uv export of
# env/py/uv.lock) with --require-hashes --no-deps, so pip neither resolves nor
# accepts a file whose sha256 is not in the lock. Wheels only, except the
# sdist-only packages the lock itself marks (docrep), which are built with
# --no-build-isolation against the already-installed, hash-locked setuptools.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG PY_ENV_VERSION
ARG PYTHON_VERSION
ARG PYPI_INDEX
ARG PYTORCH_INDEX
LABEL org.omicstat.py_env_version="${PY_ENV_VERSION}" \
      org.omicstat.python_version="${PYTHON_VERSION}" \
      org.omicstat.pytorch_index="${PYTORCH_INDEX}"

# Determinism (ENGINEERING_PLAN 10.4 lock 4): single-threaded BLAS / OpenMP /
# numba; fixed hash seed; no byte-code written into the mounted checkout;
# every cache on a writable tmp path (the container runs as the caller's uid).
ENV OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NUMBA_NUM_THREADS=1 \
    NUMEXPR_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 \
    PYTHONHASHSEED=0 PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PYTHONNOUSERSITE=1 \
    MPLBACKEND=Agg MPLCONFIGDIR=/tmp/omicstat-py/mpl NUMBA_CACHE_DIR=/tmp/omicstat-py/numba \
    XDG_CACHE_HOME=/tmp/omicstat-py/cache \
    LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    OMICSTAT_CONTAINER=1 OMICSTAT_PY_CONTAINER=1 OMICSTAT_ENV_DIR=/opt/omicstat/env \
    PATH=/opt/omicstat/venv-py/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN python -c "import platform, sys; v = platform.python_version(); \
sys.exit(0 if v == '${PYTHON_VERSION}' else 'OS_ENV_PYTHON_VERSION: base image has Python %s, pin is ${PYTHON_VERSION}' % v)"

COPY omicstat-env.json /opt/omicstat/env/omicstat-env.json
COPY r-env.json /opt/omicstat/env/r-env.json
COPY py/py-env.json /opt/omicstat/env/py/py-env.json
COPY py_lock.txt /opt/omicstat/env/py_lock.txt
COPY py/uv.lock py/split_lock.py py/write_py_installed.py /opt/omicstat/env/py/

RUN python -m venv /opt/omicstat/venv-py \
    && python /opt/omicstat/env/py/split_lock.py /opt/omicstat/env/py_lock.txt /opt/omicstat/env/py/uv.lock \
         /tmp/lock_wheels.txt /tmp/lock_sdists.txt \
    && /opt/omicstat/venv-py/bin/pip install --no-cache-dir --disable-pip-version-check \
         --require-hashes --no-deps --only-binary=:all: \
         --index-url "${PYPI_INDEX}" --extra-index-url "${PYTORCH_INDEX}" -r /tmp/lock_wheels.txt \
    && /opt/omicstat/venv-py/bin/pip install --no-cache-dir --disable-pip-version-check \
         --require-hashes --no-deps --no-build-isolation \
         --index-url "${PYPI_INDEX}" -r /tmp/lock_sdists.txt \
    && /opt/omicstat/venv-py/bin/pip check \
    && rm -f /tmp/lock_wheels.txt /tmp/lock_sdists.txt \
    && /opt/omicstat/venv-py/bin/python -m compileall -q /opt/omicstat/venv-py/lib >/dev/null

# Installed-distribution record (copied out by build.sh as env/py/py_installed.csv)
# and the static image self-test (versions == lock, CPU-only torch, threads).
COPY py/selftest_image.py /opt/omicstat/env/py/selftest_image.py
RUN /opt/omicstat/venv-py/bin/python /opt/omicstat/env/py/write_py_installed.py /opt/omicstat/py_installed.csv \
    && /opt/omicstat/venv-py/bin/python /opt/omicstat/env/py/selftest_image.py --static     && rm -rf /tmp/omicstat-py

WORKDIR /omicstat
CMD ["python"]
