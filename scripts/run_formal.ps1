$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$suiteRoot = Join-Path (Get-Location) 'work/tools/oss-cad-suite'
$suiteBin = Join-Path $suiteRoot 'bin'
$local = Join-Path (Get-Location) 'work/tools/ucrt64/bin/yosys.exe'
if ((Test-Path -LiteralPath (Join-Path $suiteBin 'yosys.exe')) -and (Test-Path -LiteralPath (Join-Path $suiteRoot 'lib'))) {
    $env:YOSYSHQ_ROOT = $suiteRoot
    $env:SSL_CERT_FILE = Join-Path $suiteRoot 'etc/cacert.pem'
    $env:PATH = "$suiteBin;$(Join-Path $suiteRoot 'lib');$env:PATH"
    $yosys = Join-Path $suiteBin 'yosys.exe'
} elseif (Test-Path -LiteralPath $local) {
    $env:PATH = "C:\msys64\ucrt64\bin;C:\msys64\mingw64\bin;$env:PATH"
    $yosys = $local
} elseif (Get-Command yosys -ErrorAction SilentlyContinue) {
    $yosys = (Get-Command yosys).Source
} else {
    throw 'BLOCKED: Yosys was not found.'
}
New-Item -ItemType Directory -Force -Path 'work' | Out-Null
$script = 'read_verilog -formal -sv rtl/async_fifo.sv formal/async_fifo_formal.sv; prep -top async_fifo_formal -flatten; async2sync; chformal -lower; sat -seq 12 -set-init-zero -prove-asserts -verify'
& $yosys -p $script -l work/formal_fifo.log
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$syncScript = 'read_verilog -formal -sv -DSYNTHESIS rtl/sync_fifo.sv formal/sync_fifo_formal.sv; prep -top sync_fifo_formal -flatten; async2sync; chformal -lower; sat -seq 12 -set-init-zero -prove-asserts -verify'
& $yosys -p $syncScript -l work/formal_sync_fifo.log
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& (Join-Path $PSScriptRoot 'run_multiclock_formal.ps1')
exit $LASTEXITCODE
