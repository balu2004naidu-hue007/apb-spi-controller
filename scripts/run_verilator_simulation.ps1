$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$sources = @('rtl/reset_sync.sv','rtl/async_fifo.sv','rtl/sync_fifo.sv','rtl/spi_master.sv','rtl/spi_slave.sv','rtl/spi_x_top.sv','tb/tb_spi_x.sv')
$local = Join-Path (Get-Location) 'work/tools/ucrt64/bin'
$root = Join-Path (Get-Location) 'work/tools/ucrt64/share/verilator'
$verilator = Join-Path $local 'verilator_bin.exe'
$suiteRoot = Join-Path (Get-Location) 'work/tools/oss-cad-suite'
$suiteBin = Join-Path $suiteRoot 'bin'
$compiler = 'C:\msys64\ucrt64\bin\g++.exe'
if (-not (Test-Path -LiteralPath $verilator) -and (Test-Path -LiteralPath (Join-Path $suiteBin 'verilator_bin.exe'))) {
    $verilator = Join-Path $suiteBin 'verilator_bin.exe'
    $root = Join-Path $suiteRoot 'share/verilator'
    $env:YOSYSHQ_ROOT = $suiteRoot
    $env:PATH = "$suiteBin;$(Join-Path $suiteRoot 'lib');$env:PATH"
}
if (-not (Test-Path -LiteralPath $verilator)) { $verilator = (Get-Command verilator -ErrorAction SilentlyContinue).Source }
if (-not $verilator) { throw 'BLOCKED: Verilator was not found.' }
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = (Get-Command g++ -ErrorAction SilentlyContinue).Source }
if (-not $compiler) { throw 'BLOCKED: a host C++ compiler was not found.' }
$env:VERILATOR_ROOT = $root
$env:PATH = "C:\msys64\ucrt64\bin;C:\msys64\mingw64\bin;$env:PATH"
$env:TEMP = Join-Path (Get-Location) 'work'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force -Path 'work/verilator_tb' | Out-Null
& $verilator --cc --timing --trace --Wall -Wno-fatal -Wno-SYNCASYNCNET --top-module tb_spi_x --Mdir work/verilator_tb @sources
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$include = Join-Path $root 'include'
$generated = @(Get-ChildItem -LiteralPath 'work/verilator_tb' -Filter '*.cpp' | ForEach-Object FullName)
$runtime = @('verilated.cpp','verilated_vcd_c.cpp','verilated_timing.cpp','verilated_threads.cpp' | ForEach-Object { Join-Path $include $_ })
$compileArgs = @('-std=c++20','-O1','-mconsole','-DVL_TIME_CONTEXT','-DVM_TIMING=1','-DVM_TRACE=1',"-Iwork/verilator_tb",("-I"+$include),("-I"+(Join-Path $include 'vltstd'))) + $generated + $runtime + @('scripts/verilator_tb_main.cpp','-o','work/verilator_tb/spi_x_verilator_sim.exe')
& $compiler @compileArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'work/verilator_tb/spi_x_verilator_sim.exe'
exit $LASTEXITCODE
