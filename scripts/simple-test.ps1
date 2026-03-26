# Simple test
$ErrorActionPreference = "Stop"

Write-Host "Testing module imports..." -ForegroundColor Cyan

# Import modules
Import-Module ".\src\core\MemoryMonitor.psm1" -Force
Import-Module ".\src\core\StateManager.psm1" -Force
Import-Module ".\src\core\Executor.psm1" -Force
Import-Module ".\src\utils\Logger.psm1" -Force
Import-Module ".\src\dashboard\Dashboard.psm1" -Force

Write-Host "  All modules loaded successfully!" -ForegroundColor Green

# Initialize
Write-Host "Initializing components..." -ForegroundColor Cyan
Initialize-Logger -LogToConsole $true -LogLevel INFO

$configPath = ".\config\settings.json"
$rulesPath = ".\config\rules.json"
Initialize-MemoryMonitor -ConfigPath $configPath -RulesPath $rulesPath
Write-Host "  MemoryMonitor initialized" -ForegroundColor Green

Initialize-StateManager -HistoryRetentionHours 168
Write-Host "  StateManager initialized" -ForegroundColor Green

Initialize-Executor
Write-Host "  Executor initialized" -ForegroundColor Green

# Test functions
Write-Host "Testing functions..." -ForegroundColor Cyan
$memInfo = Get-MemoryInfo
Write-Host "  Memory: $($memInfo.UsagePercent.ToString('F1'))%" -ForegroundColor Green

$topProcs = Get-TopMemoryProcesses -Count 5
Write-Host "  Top 5 processes loaded" -ForegroundColor Green

$analysis = Invoke-MemoryAnalysis -MemoryInfo $memInfo -TopProcs $topProcs
Write-Host "  Analysis: Risk Score = $($analysis.RiskScore)" -ForegroundColor Green

Write-Host ""
Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
Write-Host "Ready to start with: .\scripts\start.ps1 -DashboardPort 19527" -ForegroundColor Cyan
