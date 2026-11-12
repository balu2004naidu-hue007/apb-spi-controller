$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$env:PATH = "$(Join-Path (Get-Location) 'work/tools/ucrt64/bin');C:\msys64\ucrt64\bin;C:\msys64\mingw64\bin;$env:PATH"
$env:TEMP = Join-Path (Get-Location) 'work'
$env:TMP = $env:TEMP
$sources = @('rtl/reset_sync.sv','rtl/async_fifo.sv','rtl/sync_fifo.sv','rtl/spi_master.sv','rtl/spi_slave.sv','rtl/spi_x_top.sv','tb/tb_spi_x.sv')
$suiteRoot = Join-Path (Get-Location) 'work/tools/oss-cad-suite'
$suiteBin = Join-Path $suiteRoot 'bin'
$local = Join-Path (Get-Location) 'work/tools/ucrt64/bin'
$base = Join-Path (Get-Location) 'work/tools/ucrt64/lib/ivl'
$compiler = $null
$runtime = $null
if (Test-Path -LiteralPath $suiteBin) {
    $env:YOSYSHQ_ROOT = $suiteRoot
    $env:SSL_CERT_FILE = Join-Path $suiteRoot 'etc/cacert.pem'
    $env:PATH = "$suiteBin;$(Join-Path $suiteRoot 'lib');$env:PATH"
}
if ((Test-Path -LiteralPath (Join-Path $suiteBin 'iverilog.exe')) -and (Test-Path -LiteralPath (Join-Path $suiteBin 'vvp.exe'))) {
    $compiler = Join-Path $suiteBin 'iverilog.exe'
    $runtime = Join-Path $suiteBin 'vvp.exe'
    $suiteIvl = Join-Path (Get-Location) 'work/tools/oss-cad-suite/lib/ivl'
    if (Test-Path -LiteralPath $suiteIvl) { $base = $suiteIvl } else { $base = $null }
} elseif (Test-Path -LiteralPath (Join-Path $local 'iverilog.exe')) {
    $compiler = Join-Path $local 'iverilog.exe'
    $runtime = Join-Path $local 'vvp.exe'
} elseif ((Get-Command iverilog -ErrorAction SilentlyContinue) -and (Get-Command vvp -ErrorAction SilentlyContinue)) {
    $compiler = (Get-Command iverilog).Source
    $runtime = (Get-Command vvp).Source
}
$simExit = 1
if ($compiler) {
    New-Item -ItemType Directory -Force -Path 'work' | Out-Null
    $image = Join-Path 'work' ('spi_x_tb_' + [guid]::NewGuid().ToString('N') + '.vvp')
    if ($base -and (Test-Path -LiteralPath $base)) {
        & $compiler -g2012 -s tb_spi_x "-B$base" -o $image @sources
    } else {
        & $compiler -g2012 -Wall -s tb_spi_x -o $image @sources
    }
    $compileExit = $LASTEXITCODE
    if (Test-Path -LiteralPath $image) {
        if ($compileExit -ne 0) { Write-Warning "Icarus exited $compileExit after producing this run's unique image; validating the fresh image with VVP." }
        if ($base -and (Test-Path -LiteralPath $base)) { & $runtime "-M$base" $image } else { & $runtime $image }
        $simExit = $LASTEXITCODE
    } else {
        Write-Warning "Icarus produced no fresh image (exit $compileExit). Falling back to a fresh Verilator build."
    }
}
if ($simExit -ne 0) {
    & (Join-Path $PSScriptRoot 'run_verilator_simulation.ps1')
    $simExit = $LASTEXITCODE
}
if ($simExit -ne 0) { exit $simExit }
python scripts/check_waveform.py
exit $LASTEXITCODE
