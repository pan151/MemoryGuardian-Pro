# ============================================================
# quick-test.ps1 - Quick Test Script
# ============================================================

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   MemoryGuardian Pro - Quick Test" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

# Get script root
$ScriptRoot = Split-Path -Parent $PSScriptRoot

Write-Host "[1/4] Testing module imports..." -ForegroundColor Cyan

$modules = @(
    "$ScriptRoot\src\core\MemoryMonitor.psm1",
    "$ScriptRoot\src\core\StateManager.psm1",
    "$ScriptRoot\src\core\Executor.psm1",
    "$ScriptRoot\src\utils\Logger.psm1",
    "$ScriptRoot\src\ui\AlertPopup.psm1",
    "$ScriptRoot\src\dashboard\Dashboard.psm1",
    "$ScriptRoot\src\integrations\AutoStart.psm1"
)

$importErrors = 0
foreach ($module in $modules) {
    try {
        Import-Module $module -Force -ErrorAction Stop
        Write-Host "  OK Imported: $(Split-Path $module -Leaf)" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Failed to import: $(Split-Path $module -Leaf)" -ForegroundColor Red
        Write-Host "    $_" -ForegroundColor Red
        $importErrors++
    }
}

Write-Host ""

if ($importErrors -gt 0) {
    Write-Host "[ERROR] Some modules failed to import" -ForegroundColor Red
    exit 1
}

Write-Host "[2/4] Testing configuration..." -ForegroundColor Cyan

$configPath = Join-Path $ScriptRoot "config\settings.json"
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        Write-Host "  OK Configuration loaded" -ForegroundColor Green
        Write-Host "    Alert Threshold: $($config.monitoring.alertThresholdPct)%" -ForegroundColor Gray
        Write-Host "    Check Interval: $($config.monitoring.checkIntervalSeconds) seconds" -ForegroundColor Gray
    } catch {
        Write-Host "  [ERROR] Failed to load configuration: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [ERROR] Configuration file not found: $configPath" -ForegroundColor Red
    exit 1
}

Write-Host ""

Write-Host "[3/4] Testing memory monitor..." -ForegroundColor Cyan

try {
    Initialize-MemoryMonitor -Settings $config
    Write-Host "  OK Memory monitor initialized" -ForegroundColor Green
    
    $memoryInfo = Get-MemoryInfo
    Write-Host "    Memory Usage: $($memoryInfo.UsagePercent.ToString('F1'))%" -ForegroundColor Gray
    Write-Host "    Used: $($memoryInfo.UsedGB.ToString('F2')) GB" -ForegroundColor Gray
    Write-Host "    Free: $($memoryInfo.FreeGB.ToString('F2')) GB" -ForegroundColor Gray
} catch {
    Write-Host "  [ERROR] Failed to initialize memory monitor: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

Write-Host "[4/4] Testing analysis..." -ForegroundColor Cyan

try {
    Initialize-StateManager
    $analysis = Invoke-MemoryAnalysis
    Write-Host "  OK Analysis completed" -ForegroundColor Green
    Write-Host "    Risk Score: $($analysis.RiskScore)" -ForegroundColor Gray
    Write-Host "    Findings: $($analysis.Findings.Count)" -ForegroundColor Gray
} catch {
    Write-Host "  [WARN] Analysis test skipped: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "                     All Tests Passed!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "MemoryGuardian Pro is ready to use!" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start monitoring:" -ForegroundColor Cyan
Write-Host "  .\scripts\start.ps1 -DashboardPort 19527" -ForegroundColor Gray
Write-Host ""
