#!/usr/bin/env bash
# omicstat R router for Linux/macOS (the Windows counterpart is omicstat-r-route.ps1).
#   omicstat-r-route.sh <Tool> [args...]      e.g.  omicstat-r-route.sh Rscript run_x.R --help
#   Tool "python" (Python/scverse lane, ENGINEERING_PLAN 10.6) selects the omicstat-py
#   image (OMICSTAT_PY_IMAGE, else python_lane image:image_tag of env/r-env.json)
#   or, natively, the "python" interpreter named in native-env.json; every other Tool
#   is an R tool and uses omicstat-r exactly as before.
#   - OMICSTAT_R_NATIVE=1  -> the isolated native environment created by
#     env/native/setup_native.R (Rscript + library from .omicstat-r/native-env.json,
#     or from the file named by OMICSTAT_NATIVE_ENV; R_PROFILE_USER=the rprofile
#     it names, env/native/Rprofile.omicstat, so no other library is visible);
#     OMICSTAT_CONTAINER / OMICSTAT_IMAGE_ID are unset for the run
#   - otherwise            -> docker run --rm --network none <image> <Tool> [args...], where <image> is
#     OMICSTAT_IMAGE or image:image_tag from env/r-env.json (never a floating tag)
#   - the package is mounted at /omicstat, the working directory at /ws, TMPDIR at its
#     own path; path arguments under those roots are translated
#   - every OMICSTAT_* variable except OMICSTAT_R_* and OMICSTAT_NATIVE_ENV (host-only)
#     is passed into the container
# Arguments are passed as a real argv array (no word splitting, no eval).
# The exit code of <Tool> is the exit code of this script.
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "usage: omicstat-r-route.sh <Tool> [args...]" >&2
    exit 2
fi
tool="$1"; shift

suite="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

is_py=0
case "$tool" in python|python3) is_py=1 ;; esac

if [ "${OMICSTAT_R_NATIVE:-}" = "1" ]; then
    envfile="${OMICSTAT_NATIVE_ENV:-$suite/.omicstat-r/native-env.json}"
    if [ ! -f "$envfile" ]; then
        echo "OS_ENV_MISSING: no native omicstat environment at $envfile; run: Rscript env/native/setup_native.R" >&2
        exit 3
    fi
    if [ "$is_py" = "1" ]; then
        py="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('python') or '')" "$envfile")"
        if [ -z "$py" ] || [ ! -x "$py" ]; then
            echo "OS_ENV_MISSING: $envfile has no usable \"python\" interpreter; run: bash env/py/setup_native.sh" >&2
            exit 3
        fi
        unset OMICSTAT_CONTAINER OMICSTAT_PY_CONTAINER OMICSTAT_IMAGE_ID OMICSTAT_PY_IMAGE_ID
        export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 NUMBA_NUM_THREADS=1                PYTHONHASHSEED=0 PYTHONDONTWRITEBYTECODE=1 PYTHONNOUSERSITE=1 MPLBACKEND=Agg OMICSTAT_PY_NATIVE=1
        exec "$py" "$@"
    fi
    # Tab-separated so that paths containing spaces survive the read.
    IFS=$'\t' read -r rscript lib rprofile < <(python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print(c['rscript'], c['library'], c['rprofile'], sep='\t')" "$envfile")
    # The native branch defines its own environment: a container marker
    # inherited from a surrounding omicstat-r session (e.g. the MCP tests run
    # inside the image) must not relabel this run as a container run.
    unset OMICSTAT_CONTAINER OMICSTAT_IMAGE_ID
    export OMICSTAT_R_LIBS="$lib" R_PROFILE_USER="$rprofile" OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1
    if [ "$tool" = "Rscript" ]; then exec "$rscript" "$@"; fi
    exec "$(dirname "$rscript")/$tool" "$@"
fi

if [ "$is_py" = "1" ]; then
    image="${OMICSTAT_PY_IMAGE:-$(python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print(c['image']+':'+c['image_tag'])" "$suite/env/py/py-env.json")}"
else
    image="${OMICSTAT_IMAGE:-$(python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print(c['image']+':'+c['image_tag'])" "$suite/env/r-env.json")}"
fi

cwd="$(pwd -P)"
tmp="${TMPDIR:-/tmp}"
tmp="$(cd "$tmp" && pwd -P)"

# Translate a host path to its in-container spelling. Most specific root first:
# the package (/omicstat), then the working directory (/ws); TMPDIR is mounted
# at its own path, so it needs no translation.
translate() {
    local p="$1"
    case "$p" in
        "$suite") printf '%s' "/omicstat"; return ;;
        "$suite"/*) printf '%s' "/omicstat/${p#"$suite"/}"; return ;;
    esac
    case "$p" in
        "$cwd") printf '%s' "/ws"; return ;;
        "$cwd"/*) printf '%s' "/ws/${p#"$cwd"/}"; return ;;
    esac
    printf '%s' "$p"
}

docker_args=(run --rm --network none)
# Files written into the mounts stay owned by the calling user.
docker_args+=(--user "$(id -u):$(id -g)")
for key in $(compgen -e); do
    case "$key" in
        OMICSTAT_R_*|OMICSTAT_NATIVE_ENV) ;;
        OMICSTAT_*) docker_args+=(-e "$key") ;;
    esac
done

docker_args+=(-v "$suite:/omicstat" -v "$cwd:/ws" -v "$tmp:$tmp" -w "$(translate "$cwd")")
docker_args+=("$image" "$tool")
for a in "$@"; do
    docker_args+=("$(translate "$a")")
done

exec docker "${docker_args[@]}"
