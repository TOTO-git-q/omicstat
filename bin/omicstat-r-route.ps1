# omicstat R router (Windows: native isolated library, or docker inside WSL).
# The package-local path is authoritative: an installed
# archive must never silently execute a developer checkout.  No param block is
# used because R's flags (for example -e) must pass through verbatim.

$Tool = $args[0]
$Rest = @()
if ($args.Count -gt 1) { $Rest = $args[1..($args.Count - 1)] }

function ConvertTo-WslPath([string]$p) {
    if ($p -match '^([A-Za-z]):[\\/](.*)$') {
        return '/mnt/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/')
    }
    return $p
}

function SingleQuote([string]$s) {
    return "'" + ($s -replace "'", "'\\''") + "'"
}

$suite = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
# Tool "python" = the Python/scverse lane (ENGINEERING_PLAN 10.6): the omicstat-py
# image, or natively the "python" interpreter named in native-env.json.
$IsPy = ($Tool -eq 'python' -or $Tool -eq 'python3')

# Native engine = the isolated omicstat library made by env/native/setup_native.R
# (never a system or other project's R library).
if ($env:OMICSTAT_R_NATIVE -eq '1') {
    # OMICSTAT_NATIVE_ENV names another native-env.json (development/testing).
    $envFile = if ($env:OMICSTAT_NATIVE_ENV) { $env:OMICSTAT_NATIVE_ENV } else { Join-Path $suite '.omicstat-r\native-env.json' }
    if (-not (Test-Path -LiteralPath $envFile)) {
        [Console]::Error.WriteLine('OS_ENV_MISSING: no native omicstat environment; run: Rscript env/native/setup_native.R')
        exit 3
    }
    $native = Get-Content -Raw -LiteralPath $envFile | ConvertFrom-Json
    if ($IsPy) {
        if (-not $native.python -or -not (Test-Path -LiteralPath $native.python)) {
            [Console]::Error.WriteLine('OS_ENV_MISSING: native-env.json has no usable "python" interpreter; run: bash env/py/setup_native.sh')
            exit 3
        }
        foreach ($v in 'OMICSTAT_CONTAINER', 'OMICSTAT_PY_CONTAINER', 'OMICSTAT_IMAGE_ID', 'OMICSTAT_PY_IMAGE_ID') { Remove-Item -Path ('Env:' + $v) -ErrorAction SilentlyContinue }
        $env:OMP_NUM_THREADS = '1'; $env:OPENBLAS_NUM_THREADS = '1'; $env:MKL_NUM_THREADS = '1'; $env:NUMBA_NUM_THREADS = '1'
        $env:PYTHONHASHSEED = '0'; $env:PYTHONDONTWRITEBYTECODE = '1'; $env:PYTHONNOUSERSITE = '1'; $env:MPLBACKEND = 'Agg'; $env:OMICSTAT_PY_NATIVE = '1'
        & $native.python @Rest
        exit $LASTEXITCODE
    }
    $env:OMICSTAT_R_LIBS = $native.library
    $env:R_PROFILE_USER = $native.rprofile
    $env:OMP_NUM_THREADS = '1'; $env:OPENBLAS_NUM_THREADS = '1'; $env:MKL_NUM_THREADS = '1'
    & (Join-Path (Split-Path -Parent $native.rscript) ($Tool + '.exe')) @Rest
    exit $LASTEXITCODE
}

# Container image: OMICSTAT_IMAGE, else image:image_tag from env/omicstat-env.json.
# Python lane: OMICSTAT_PY_IMAGE, else python_lane image:image_tag.
$image = if ($IsPy) { $env:OMICSTAT_PY_IMAGE } else { $env:OMICSTAT_IMAGE }
if (-not $image) {
    $cfg = Get-Content -Raw -LiteralPath (Join-Path $suite $(if ($IsPy) { 'env\py\py-env.json' } else { 'env\r-env.json' })) | ConvertFrom-Json
    if ($IsPy) { $image = $cfg.image + ':' + $cfg.image_tag }
    else { $image = $cfg.image + ':' + $cfg.image_tag }
}

# WSL interop corrupts a script path containing spaces in argv.  Mount the
# package itself at a stable space-free target and translate only that prefix.
$suiteFull = [IO.Path]::GetFullPath($suite).TrimEnd('\\')
function ConvertSuitePath([string]$p) {
    $full = [IO.Path]::GetFullPath($p)
    if ($full.StartsWith($suiteFull, [StringComparison]::OrdinalIgnoreCase)) {
        return '/omicstat' + ($full.Substring($suiteFull.Length) -replace '\\', '/')
    }
    return ConvertTo-WslPath $p
}

$cwd = ConvertSuitePath (Get-Location).Path
if ($cwd -notmatch '^/(mnt|omicstat)(/|$)') { $cwd = '/tmp' }

$parts = @('exec', 'docker', 'run', '--rm', '--network', 'none')
foreach ($entry in [Environment]::GetEnvironmentVariables().GetEnumerator()) {
    if ($entry.Key -like 'OMICSTAT_*' -and $entry.Key -notlike 'OMICSTAT_R_*' -and $entry.Key -ne 'OMICSTAT_NATIVE_ENV') {
        $parts += @('-e', (SingleQuote ($entry.Key + '=' + $entry.Value)))
    }
}
$suiteWsl = ConvertTo-WslPath $suiteFull
$parts += @('-v', '/mnt/c:/mnt/c', '-v', '/mnt/e:/mnt/e',
    '-v', (SingleQuote ($suiteWsl + ':/omicstat')), '-w', (SingleQuote $cwd),
    (SingleQuote $image), (SingleQuote $Tool))
foreach ($a in $Rest) { $parts += (SingleQuote (ConvertSuitePath ([string]$a))) }
$bashCmd = ($parts -join ' ') + "`n"

$scriptName = 'omicstat-r-' + $PID + '-' + ([Guid]::NewGuid().ToString('N').Substring(0, 8)) + '.sh'
$scriptWin = Join-Path $env:TEMP $scriptName
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($scriptWin, $bashCmd, $utf8NoBom)
$scriptWsl = ConvertTo-WslPath $scriptWin
try {
    & wsl -e bash $scriptWsl
    $code = $LASTEXITCODE
} finally {
    Remove-Item -LiteralPath $scriptWin -Force -ErrorAction SilentlyContinue
}
exit $code
