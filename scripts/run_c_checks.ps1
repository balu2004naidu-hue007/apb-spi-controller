$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
New-Item -ItemType Directory -Force -Path 'work' | Out-Null
$compiler = Get-Command clang -ErrorAction SilentlyContinue
if (-not $compiler) { $compiler = Get-Command gcc -ErrorAction SilentlyContinue }
$targetOnly = $false
$compilerPath = $null
if (-not $compiler) {
    foreach ($candidate in @('C:\msys64\ucrt64\bin\clang.exe','C:\msys64\ucrt64\bin\gcc.exe')) {
        if (Test-Path -LiteralPath $candidate) { $compilerPath = $candidate; break }
    }
}
if (-not $compiler -and -not $compilerPath) {
    $candidate = 'C:\Espressif\tools\esp-clang\esp-21.1.3_20260408\esp-clang\bin\clang.exe'
    if (Test-Path -LiteralPath $candidate) { $compilerPath = $candidate; $targetOnly = $true }
}
if (-not $compiler -and -not $compilerPath) { throw 'BLOCKED: no C compiler was found.' }
if (-not $compilerPath) { $compilerPath = $compiler.Source }
if ($compilerPath.StartsWith('C:\msys64\', [System.StringComparison]::OrdinalIgnoreCase)) {
    $env:PATH = "C:\msys64\ucrt64\bin;C:\msys64\mingw64\bin;$env:PATH"
}
$env:TEMP = Join-Path (Get-Location) 'work'
$env:TMP = $env:TEMP
$common = @('-std=c11','-Wall','-Wextra','-Werror','-pedantic','-I','sw/include')
& $compilerPath @common -c sw/src/demo.c -o work/demo.o
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $compilerPath @common -c tests/test_driver.c -o work/test_driver.o
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($targetOnly) {
    Write-Host 'PASS: Embedded C demo and driver check compile to target objects.'
    Write-Host 'BLOCKED: host execution of test_driver.c requires a host compiler/runtime.'
} else {
    & $compilerPath @common tests/test_driver.c -o work/test_driver.exe
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & .\work\test_driver.exe
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host 'PASS: Embedded C object build and host driver API test.'
}
