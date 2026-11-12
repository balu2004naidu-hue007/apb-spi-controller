$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
New-Item -ItemType Directory -Force -Path 'work' | Out-Null
$sources = @('rtl/reset_sync.sv','rtl/async_fifo.sv','rtl/sync_fifo.sv','rtl/spi_master.sv','rtl/spi_slave.sv','rtl/spi_x_top.sv')
$suiteRoot = Join-Path (Get-Location) 'work/tools/oss-cad-suite'
$suiteBin = Join-Path $suiteRoot 'bin'
$local = Join-Path (Get-Location) 'work/tools/ucrt64/bin/verilator_bin.exe'
if (Test-Path -LiteralPath $local) {
    $env:PATH = "C:\msys64\ucrt64\bin;C:\msys64\mingw64\bin;$(Join-Path (Get-Location) 'work/tools/ucrt64/bin');$env:PATH"
    $env:VERILATOR_ROOT = Join-Path (Get-Location) 'work/tools/ucrt64/share/verilator'
    & $local --lint-only --Wall --timing --top-module spi_x_top --Mdir work/verilator_lint @sources
} elseif (Test-Path -LiteralPath (Join-Path $suiteBin 'verilator_bin.exe')) {
    $env:YOSYSHQ_ROOT = $suiteRoot
    $env:VERILATOR_ROOT = Join-Path $suiteRoot 'share/verilator'
    $env:PATH = "$suiteBin;$(Join-Path $suiteRoot 'lib');$env:PATH"
    & (Join-Path $suiteBin 'verilator_bin.exe') --lint-only --Wall --timing --top-module spi_x_top --Mdir work/verilator_lint @sources
} elseif (Get-Command verilator -ErrorAction SilentlyContinue) {
    verilator --lint-only --Wall --timing --top-module spi_x_top @sources
} else {
    throw 'BLOCKED: verilator was not found on PATH or in work/tools.'
}
exit $LASTEXITCODE
