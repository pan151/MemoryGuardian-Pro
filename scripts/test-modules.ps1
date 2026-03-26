# ============================================================
# test-modules.ps1 - Test module loading
# ============================================================

$ErrorActionPreference = "Continue"
$ScriptRoot = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Testing Module Loading" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$modules = @(
    @{Path = "$ScriptRoot\src\core\MemoryMonitor.psm1"; Name = "MemoryMonitor"},
    @{Path = "$ScriptRoot\src\ui\AlertPopup.psm1"; Name = "AlertPopup"},
    @{Path = "$ScriptRoot\src\dashboard\Dashboard.psm1"; Name = "Dashboard"}
)

$failed = 0

foreach ($module in $modules) {
    Write-Host "Testing: $($module.Name)..." -ForegroundColor Gray
    
    try {
        Import-Module $module.Path -Force -ErrorAction Stop
        Write-Host "  [OK] $($module.Name) loaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED] $($module.Name)" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "All modules loaded successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed module(s) failed to load" -ForegroundColor Red
    exit 1
}
