$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$root = Join-Path (Get-Location) 'work/tools/ucrt64/share/verilator'
$verilator = Join-Path (Get-Location) 'work/tools/ucrt64/bin/verilator_bin.exe'
$compiler = 'C:\msys64\ucrt64\bin\g++.exe'
if (-not (Test-Path -LiteralPath $verilator)) {
    $suiteRoot = Join-Path (Get-Location) 'work/tools/oss-cad-suite'
    $suiteVerilator = Join-Path $suiteRoot 'bin/verilator_bin.exe'
    if (Test-Path -LiteralPath $suiteVerilator) { $verilator = $suiteVerilator }
}
if (-not (Test-Path -LiteralPath $verilator)) {
    $verilator = (Get-Command verilator_bin -ErrorAction SilentlyContinue).Source
    if (-not $verilator) { $verilator = (Get-Command verilator -ErrorAction SilentlyContinue).Source }
}
if (-not (Test-Path -LiteralPath $root)) { $root = Join-Path $suiteRoot 'share/verilator' }
if (-not (Test-Path -LiteralPath $verilator)) { throw 'BLOCKED: Verilator was not found.' }
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = (Get-Command g++ -ErrorAction SilentlyContinue).Source }
if (-not $compiler) { throw 'BLOCKED: a host C++ compiler was not found.' }
$env:VERILATOR_ROOT = $root
$env:PATH = "$(Join-Path (Get-Location) 'work/tools/ucrt64/bin');C:\msys64\ucrt64\bin;C:\msys64\mingw64\bin;$env:PATH"
$env:TEMP = Join-Path (Get-Location) 'work'
$env:TMP = $env:TEMP
$mdir = 'work/verilator_pair'
New-Item -ItemType Directory -Force -Path $mdir | Out-Null
$sources = @('rtl/reset_sync.sv','rtl/async_fifo.sv','rtl/sync_fifo.sv','rtl/spi_master.sv','rtl/spi_slave.sv','rtl/spi_x_top.sv','tb/tb_spi_x_pair.sv')
& $verilator --cc --timing --Wall --Wno-fatal -Wno-PINCONNECTEMPTY -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --top-module tb_spi_x_pair --Mdir $mdir @sources
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$include = Join-Path $root 'include'
$generated = @(Get-ChildItem -LiteralPath $mdir -Filter '*.cpp' | ForEach-Object FullName)
$runtime = @('verilated.cpp','verilated_timing.cpp','verilated_threads.cpp' | ForEach-Object { Join-Path $include $_ })
$compileArgs = @('-std=c++20','-O1','-mconsole','-DVL_TIME_CONTEXT','-DVM_TIMING=1',"-I$mdir",("-I"+$include),("-I"+(Join-Path $include 'vltstd'))) + $generated + $runtime + @('scripts/verilator_pair_tb_main.cpp','-o','work/verilator_pair/spi_x_pair.exe')
& $compiler @compileArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'work/verilator_pair/spi_x_pair.exe'
exit $LASTEXITCODE
