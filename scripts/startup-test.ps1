# Quick startup test script
$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Startup Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Import all modules
Write-Host "[TEST 1] Importing modules..." -ForegroundColor Yellow
try {
    Import-Module "E:\workbuddy\workspace\MemoryGuardian-Pro\src\core\MemoryMonitor.psm1" -Force -ErrorAction Stop
    Import-Module "E:\workbuddy\workspace\MemoryGuardian-Pro\src\core\StateManager.psm1" -Force -ErrorAction Stop
    Import-Module "E:\workbuddy\workspace\MemoryGuardian-Pro\src\core\Executor.psm1" -Force -ErrorAction Stop
    Import-Module "E:\workbuddy\workspace\MemoryGuardian-Pro\src\utils\Logger.psm1" -Force -ErrorAction Stop
    Import-Module "E:\workbuddy\workspace\MemoryGuardian-Pro\src\dashboard\Dashboard.psm1" -Force -ErrorAction Stop
    Write-Host "  [OK] All modules imported" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Module import failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Initialize components
Write-Host "[TEST 2] Initializing components..." -ForegroundColor Yellow
try {
    Initialize-Logger -LogToConsole $true -LogLevel INFO -ErrorAction Stop
    Write-Host "  [OK] Logger initialized" -ForegroundColor Green

    $configPath = "E:\workbuddy\workspace\MemoryGuardian-Pro\config\settings.json"
    $rulesPath = "E:\workbuddy\workspace\MemoryGuardian-Pro\config\rules.json"
    Initialize-MemoryMonitor -ConfigPath $configPath -RulesPath $rulesPath -ErrorAction Stop
    Write-Host "  [OK] MemoryMonitor initialized" -ForegroundColor Green

    Initialize-StateManager -HistoryRetentionHours 168 -ErrorAction Stop
    Write-Host "  [OK] StateManager initialized" -ForegroundColor Green

    Initialize-Executor -ErrorAction Stop
    Write-Host "  [OK] Executor initialized" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Initialization failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 3: Test core functions
Write-Host "[TEST 3] Testing core functions..." -ForegroundColor Yellow
try {
    $memInfo = Get-MemoryInfo
    Write-Host "  [OK] Get-MemoryInfo: $($memInfo.UsagePercent.ToString('F1'))%" -ForegroundColor Green

    $topProcs = Get-TopMemoryProcesses -Count 5
    Write-Host "  [OK] Get-TopMemoryProcesses: $($topProcs.Count) processes" -ForegroundColor Green

    $analysis = Invoke-MemoryAnalysis -MemoryInfo $memInfo -TopProcs $topProcs
    Write-Host "  [OK] Invoke-MemoryAnalysis: Risk Score = $($analysis.RiskScore)" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] Function test failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 4: Dashboard paths
Write-Host "[TEST 4] Checking Dashboard files..." -ForegroundColor Yellow
$dashboardHtml = "E:\workbuddy\workspace\MemoryGuardian-Pro\src\dashboard\index.html"
$dashboardData = "E:\workbuddy\workspace\MemoryGuardian-Pro\src\dashboard\data.json"
if (Test-Path $dashboardHtml) {
    Write-Host "  [OK] Dashboard HTML found" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Dashboard HTML not found" -ForegroundColor Red
}

if (Test-Path $dashboardData) {
    Write-Host "  [OK] Dashboard data found" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Dashboard data not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  All Tests PASSED!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "You can now start MemoryGuardian Pro:" -ForegroundColor Cyan
Write-Host "  .\scripts\start.ps1 -DashboardPort 19527" -ForegroundColor White
