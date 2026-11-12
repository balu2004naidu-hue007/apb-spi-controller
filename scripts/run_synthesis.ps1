$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
New-Item -ItemType Directory -Force -Path 'work' | Out-Null
$suiteRoot = Join-Path (Get-Location) 'work/tools/oss-cad-suite'
$suiteBin = Join-Path $suiteRoot 'bin'
$suiteYosys = Join-Path $suiteBin 'yosys.exe'
$local = Join-Path (Get-Location) 'work/tools/ucrt64/bin/yosys.exe'
if ((Test-Path -LiteralPath $suiteYosys) -and (Test-Path -LiteralPath (Join-Path $suiteRoot 'lib'))) {
    $env:YOSYSHQ_ROOT = $suiteRoot
    $env:SSL_CERT_FILE = Join-Path $suiteRoot 'etc/cacert.pem'
    $env:PATH = "$suiteBin;$(Join-Path $suiteRoot 'lib');$env:PATH"
    & $suiteYosys -s synth.ys -l work/yosys.log
} elseif (Test-Path -LiteralPath $local) {
    $env:PATH = "C:\msys64\ucrt64\bin;$env:PATH"
    & $local -s synth.ys -l work/yosys.log
} elseif (Get-Command yosys -ErrorAction SilentlyContinue) {
    yosys -s synth.ys -l work/yosys.log
} else {
    throw 'BLOCKED: yosys was not found on PATH or in work/tools.'
}
exit $LASTEXITCODE
