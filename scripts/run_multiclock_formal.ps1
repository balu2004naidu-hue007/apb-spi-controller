$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$suiteRoot = Join-Path (Get-Location) 'work/tools/oss-cad-suite'
$suiteBin = Join-Path $suiteRoot 'bin'
if (Test-Path -LiteralPath $suiteBin) {
    $env:YOSYSHQ_ROOT = $suiteRoot
    $env:SSL_CERT_FILE = Join-Path $suiteRoot 'etc/cacert.pem'
    $env:PATH = "$suiteBin;$(Join-Path $suiteRoot 'lib');$env:PATH"
}
$sby = Get-Command sby -ErrorAction SilentlyContinue
if (-not $sby) { throw 'BLOCKED: SymbiYosys (sby) was not found.' }
New-Item -ItemType Directory -Force -Path 'work' | Out-Null
& $sby.Source -f -d work/formal_async_fifo_multiclock formal/async_fifo_multiclock.sby
exit $LASTEXITCODE
