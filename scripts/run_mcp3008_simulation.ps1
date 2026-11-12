$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$env:PATH = "$(Join-Path (Get-Location) 'work/tools/ucrt64/bin');C:\msys64\ucrt64\bin;C:\msys64\mingw64\bin;$env:PATH"
$env:TEMP = Join-Path (Get-Location) 'work'
$env:TMP = $env:TEMP
$root = Join-Path (Get-Location) 'work/tools/ucrt64/share/verilator'
$verilator = Join-Path (Get-Location) 'work/tools/ucrt64/bin/verilator_bin.exe'
$suiteRoot = Join-Path (Get-Location) 'work/tools/oss-cad-suite'
$suiteBin = Join-Path $suiteRoot 'bin'
$compiler = 'C:\msys64\ucrt64\bin\g++.exe'
if (-not (Test-Path -LiteralPath $verilator) -and (Test-Path -LiteralPath (Join-Path $suiteBin 'verilator_bin.exe'))) {
    $verilator = Join-Path $suiteBin 'verilator_bin.exe'
    $root = Join-Path $suiteRoot 'share/verilator'
    $env:YOSYSHQ_ROOT = $suiteRoot
    $env:PATH = "$suiteBin;$(Join-Path $suiteRoot 'lib');$env:PATH"
}
$sources = @('rtl/reset_sync.sv','rtl/async_fifo.sv','rtl/sync_fifo.sv','rtl/spi_master.sv','rtl/spi_slave.sv','rtl/spi_x_top.sv','targets/icebreaker_mcp3008/spi_x_icebreaker_mcp3008.sv','tb/tb_icebreaker_mcp3008.sv')
$mdir = 'work/verilator_mcp3008'
New-Item -ItemType Directory -Force -Path $mdir | Out-Null
$env:VERILATOR_ROOT = $root
& $verilator --cc --timing --trace --Wall -Wno-SYNCASYNCNET --top-module tb_icebreaker_mcp3008 --Mdir $mdir @sources
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$include = Join-Path $root 'include'
$generated = @(Get-ChildItem -LiteralPath $mdir -Filter '*.cpp' | ForEach-Object FullName)
$runtime = @('verilated.cpp','verilated_vcd_c.cpp','verilated_timing.cpp','verilated_threads.cpp' | ForEach-Object { Join-Path $include $_ })
$compileArgs = @('-std=c++20','-O1','-mconsole','-DVL_TIME_CONTEXT','-DVM_TIMING=1','-DVM_TRACE=1',"-I$mdir",("-I"+$include),("-I"+(Join-Path $include 'vltstd'))) + $generated + $runtime + @('scripts/verilator_mcp3008_tb_main.cpp','-o','work/verilator_mcp3008/mcp3008_sim.exe')
& $compiler @compileArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& 'work/verilator_mcp3008/mcp3008_sim.exe'
exit $LASTEXITCODE
