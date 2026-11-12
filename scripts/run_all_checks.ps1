$ErrorActionPreference = 'Continue'
Set-Location (Split-Path -Parent $PSScriptRoot)
$checks = @(
    'run_python_tests.ps1',
    'run_c_checks.ps1',
    'run_lint.ps1',
    'run_simulation.ps1',
    'run_system_integration.ps1',
    'run_formal.ps1',
    'run_synthesis.ps1',
    'run_icebreaker_target.ps1',
    'run_mcp3008_simulation.ps1'
)
$failed = [System.Collections.Generic.List[string]]::new()
foreach ($check in $checks) {
    Write-Host "`n=== $check ==="
    & (Join-Path $PSScriptRoot $check)
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        $failed.Add("$check (exit $code)")
        Write-Host "FAIL: $check (exit $code)" -ForegroundColor Red
    } else {
        Write-Host "PASS: $check" -ForegroundColor Green
    }
}
if ($failed.Count -gt 0) {
    Write-Error ("Validation failures: " + ($failed -join ', '))
    exit 1
}
Write-Host "`nPASS: all project validation scripts completed successfully." -ForegroundColor Green
exit 0
