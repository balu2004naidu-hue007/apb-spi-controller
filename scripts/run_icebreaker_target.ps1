$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$suiteRoot = Join-Path (Get-Location) 'work/tools/oss-cad-suite'
$suiteBin = Join-Path $suiteRoot 'bin'
$suiteYosys = Join-Path $suiteBin 'yosys.exe'
$local = Join-Path (Get-Location) 'work/tools/ucrt64/bin/yosys.exe'
if ((Test-Path -LiteralPath $suiteYosys) -and (Test-Path -LiteralPath (Join-Path $suiteRoot 'lib'))) {
    $env:YOSYSHQ_ROOT = $suiteRoot
    $env:SSL_CERT_FILE = Join-Path $suiteRoot 'etc/cacert.pem'
    $env:PATH = "$suiteBin;$(Join-Path $suiteRoot 'lib');$env:PATH"
    $yosys = $suiteYosys
} elseif (Test-Path -LiteralPath $local) {
    $env:PATH = "$(Join-Path (Get-Location) 'work/tools/ucrt64/bin');C:\msys64\ucrt64\bin;C:\msys64\mingw64\bin;$env:PATH"
    $yosys = $local
} elseif (Get-Command yosys -ErrorAction SilentlyContinue) { $yosys = (Get-Command yosys).Source }
else { throw 'BLOCKED: Yosys is unavailable for iCE40 synthesis.' }
New-Item -ItemType Directory -Force -Path 'work' | Out-Null
$env:TEMP = Join-Path (Get-Location) 'work'
$env:TMP = $env:TEMP
& $yosys -s targets/icebreaker_mcp3008/synth.ys -l work/icebreaker_synth.log
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (Test-Path -LiteralPath $suiteBin) {
    # Use the suite DLLs for nextpnr/icetime only. Prepending them before the
    # separately bundled Yosys can cause Windows DLL entry-point conflicts.
    $env:YOSYSHQ_ROOT = $suiteRoot
    $env:SSL_CERT_FILE = Join-Path $suiteRoot 'etc/cacert.pem'
    $env:PATH = "$suiteBin;$(Join-Path $suiteRoot 'lib');$env:PATH"
}
$pnr = Get-Command nextpnr-ice40 -ErrorAction SilentlyContinue
if (-not $pnr) {
    Write-Warning 'BLOCKED: nextpnr-ice40 is not installed; iCE40 placement/routing and timing were not run.'
    exit 0
}
& $pnr.Source --up5k --package sg48 --json work/icebreaker_mcp3008.json --pcf targets/icebreaker_mcp3008/icebreaker.pcf --freq 12 --asc work/icebreaker_mcp3008.asc --report work/icebreaker_pnr.json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$icetime = Get-Command icetime -ErrorAction SilentlyContinue
if ($icetime) {
    & $icetime.Source -d up5k -mtr work/icebreaker_timing.rpt work/icebreaker_mcp3008.asc
    exit $LASTEXITCODE
}
Write-Warning 'BLOCKED: icetime is not installed; nextpnr route completed but standalone timing report was not generated.'
