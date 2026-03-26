# ============================================================
# Memory Guardian Pro - Main Entry Point
# ============================================================

param(
    [switch]$Dashboard,
    [switch]$AutoKill,
    [switch]$NoAlert,
    [switch]$Quiet,
    [int]$IntervalSeconds,
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# Get script root directory
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ============================================================
# Install/Uninstall
# ============================================================
if ($Install) {
    & "$ScriptRoot\scripts\install.ps1"
    exit
}

if ($Uninstall) {
    & "$ScriptRoot\scripts\uninstall.ps1"
    exit
}

# ============================================================
# Load Modules
# ============================================================
Import-Module "$ScriptRoot\src\core\MemoryMonitor.psm1" -Force
Import-Module "$ScriptRoot\src\ui\AlertPopup.psm1" -Force
Import-Module "$ScriptRoot\src\dashboard\Dashboard.psm1" -Force

# ============================================================
# Initialization
# ============================================================
$configPath = "$ScriptRoot\config\settings.json"
$rulesPath = "$ScriptRoot\config\rules.json"

if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] Config file not found: $configPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $rulesPath)) {
    Write-Host "[ERROR] Rules file not found: $rulesPath" -ForegroundColor Red
    exit 1
}

# Load config and allow overrides
$settings = Get-Content $configPath | ConvertFrom-Json
if ($IntervalSeconds -gt 0) {
    $settings.monitoring.intervalSeconds = $IntervalSeconds
}

# Initialize monitor
$guardianState = Initialize-MemoryMonitor -ConfigPath $configPath -RulesPath $rulesPath

# Update settings
if ($AutoKill) {
    $settings.autoOptimization.autoKill = $true
}

if (-not $Dashboard) {
    $settings.dashboard.enabled = $false
}

if ($NoAlert) {
    $settings.notifications.enabled = $false
}

# Save back to global variables
$script:Settings = $settings
$script:GuardianState = $guardianState

# ============================================================
# Start Dashboard
# ============================================================
if ($settings.dashboard.enabled) {
    $dashboardHtml = "$ScriptRoot\src\dashboard\index.html"
    $dataPath = "C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\data\guardian_state.json"

    Start-DashboardServer -HtmlPath $dashboardHtml -DataPath $dataPath -Port $settings.dashboard.port -AutoOpen:$settings.dashboard.autoOpen
}

# ============================================================
# System Tray - Currently Disabled
# ============================================================
# Tray icon functionality requires additional Windows Forms modules
# To enable system tray, install required dependencies or use Dashboard instead
$trayIcon = $null

# Dashboard is available at http://localhost:$($settings.dashboard.port)

# ============================================================
# Define Callback Functions
# ============================================================
$script:OnAlert = {
    param($Finding)

    if (-not $NoAlert -and $settings.notifications.enabled) {
        Show-AlertPopup -Finding $Finding -DashboardUrl "http://localhost:$($settings.dashboard.port)"
    }

    # Show system tray notification
    if ($settings.notifications.enabled) {
        Show-TrayNotification -Title "Memory Alert" -Message "$($Finding.Name) uses $($Finding.MemMB) MB`n$($Finding.Reason)" -Icon "Warning"
    }
}

$script:OnCritical = {
    param($Mem)

    if (-not $NoAlert -and $settings.notifications.enabled) {
        Show-TrayNotification -Title "Critical Alert" -Message "System memory critical: $($Mem.UsedPct)%" -Icon "Error"
    }
}

# ============================================================
# Start Monitoring
# ============================================================
Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "           Memory Guardian Pro v1.0.0" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Gray
Write-Host "  Monitor Interval: $($settings.monitoring.intervalSeconds) seconds" -ForegroundColor Gray
Write-Host "  Alert Threshold: $($settings.monitoring.alertThresholdPct)%" -ForegroundColor Gray
Write-Host "  Critical Threshold: $($settings.monitoring.criticalThresholdPct)%" -ForegroundColor Gray
Write-Host "  Auto Kill: $($settings.autoOptimization.autoKill)" -ForegroundColor Gray
Write-Host "  Dashboard: $(if($settings.dashboard.enabled){'Enabled'}else{'Disabled'})" -ForegroundColor Gray
Write-Host ""

if ($settings.dashboard.enabled) {
    Write-Host "Dashboard: http://localhost:$($settings.dashboard.port)" -ForegroundColor Green
    Write-Host ""
}

Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor Yellow
Write-Host ""

# Start monitoring loop
try {
    Start-MonitoringLoop -OnAlert $script:OnAlert -OnCritical $script:OnCritical
} catch {
    Write-Host "[ERROR] Monitoring loop error: $_" -ForegroundColor Red
} finally {
    # Cleanup resources
    Stop-DashboardServer
    if ($trayIcon) {
        $trayIcon.Dispose()
    }
    Write-Host ""
    Write-Host "Memory Guardian Pro stopped" -ForegroundColor Yellow
}
