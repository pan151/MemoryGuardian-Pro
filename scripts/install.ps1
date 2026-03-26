# ============================================================
# install.ps1 - Installation Script
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   MemoryGuardian Pro - Installation Wizard" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "[WARN] Not running as administrator, some features may be limited" -ForegroundColor Yellow
    Write-Host "      It is recommended to run this script as administrator" -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Continue? (Y/N)"
    if ($response -ne "Y" -and $response -ne "y") {
        exit 0
    }
}

# Get script root directory
$ScriptRoot = Split-Path -Parent $PSScriptRoot

# Check required files
Write-Host "[1/6] Checking installation files..." -ForegroundColor Cyan

$requiredFiles = @(
    "MemoryGuardian.ps1",
    "config\settings.json",
    "config\rules.json",
    "src\core\MemoryMonitor.psm1",
    "src\ui\AlertPopup.psm1",
    "src\dashboard\Dashboard.psm1"
)

$allExists = $true
foreach ($file in $requiredFiles) {
    $path = Join-Path $ScriptRoot $file
    if (-not (Test-Path $path)) {
        Write-Host "  [MISSING] $file" -ForegroundColor Red
        $allExists = $false
    }
}

if (-not $allExists) {
    Write-Host "[ERROR] Missing required files, installation aborted" -ForegroundColor Red
    exit 1
}

Write-Host "  OK All required files ready" -ForegroundColor Green
Write-Host ""

# Create necessary directories
Write-Host "[2/6] Creating data directories..." -ForegroundColor Cyan

$dirs = @(
    "C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\data",
    "C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\logs"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  OK Created: $dir" -ForegroundColor Green
    }
}

Write-Host ""

# Parse parameters
$EnableAutoStart = $false
$AutoStartMethod = "TaskScheduler"
$CreateShortcut = $true

foreach ($arg in $args) {
    if ($arg -eq "-EnableAutoStart") {
        $EnableAutoStart = $true
    }
    elseif ($arg -like "-AutoStartMethod:*") {
        $AutoStartMethod = $arg.Split(":")[1]
    }
    elseif ($arg -eq "-NoShortcut") {
        $CreateShortcut = $false
    }
}

# Configure desktop shortcut
if ($CreateShortcut) {
    Write-Host "[3/6] Creating desktop shortcut..." -ForegroundColor Cyan
    
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "MemoryGuardian-Pro.lnk"
    
    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptRoot\scripts\start.ps1`" -DashboardPort 19527"
        $Shortcut.WorkingDirectory = $ScriptRoot
        $Shortcut.Description = "MemoryGuardian Pro - Memory Optimization and Monitoring"
        $Shortcut.IconLocation = "C:\Windows\System32\shell32.dll,21"
        $Shortcut.Save()
        
        Write-Host "  OK Desktop shortcut created" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Failed to create shortcut: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "[3/6] Skipping desktop shortcut creation..." -ForegroundColor Cyan
}

Write-Host ""

# Configure auto-startup
Write-Host "[4/6] Configuring auto-startup..." -ForegroundColor Cyan

if ($EnableAutoStart) {
    try {
        # Import AutoStart module
        Import-Module "$ScriptRoot\src\integrations\AutoStart.psm1" -Force
        
        if ($AutoStartMethod -eq "Registry") {
            Enable-AutoStartRegistry
        } elseif ($AutoStartMethod -eq "TaskScheduler") {
            Enable-AutoStartTaskScheduler
        } else {
            Enable-AutoStartRegistry
            Enable-AutoStartTaskScheduler
        }
        
        Write-Host "  OK Auto-startup enabled ($AutoStartMethod)" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Failed to configure auto-startup: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [INFO] Auto-startup not enabled" -ForegroundColor Gray
    Write-Host "  You can enable it later: Set-AutoStart -Action Enable" -ForegroundColor Gray
}

Write-Host ""

# Test run (only in interactive mode)
if (-not $EnableAutoStart) {
    Write-Host "[5/6] Test run..." -ForegroundColor Cyan
    
    $response = Read-Host "Start MemoryGuardian Pro now? (Y/N)"
    
    if ($response -eq "Y" -or $response -eq "y") {
        Write-Host "  Starting MemoryGuardian Pro..." -ForegroundColor Gray
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptRoot\scripts\start.ps1`" -DashboardPort 19527"
        Write-Host "  OK Started" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Access Dashboard: http://localhost:19527" -ForegroundColor Cyan
    } else {
        Write-Host "  [INFO] Test run skipped" -ForegroundColor Gray
        Write-Host "  You can start it later: .\scripts\start.ps1" -ForegroundColor Gray
    }
} else {
    Write-Host "[5/6] Skipping test run (non-interactive mode)..." -ForegroundColor Cyan
}

Write-Host ""

# Installation summary
Write-Host "[6/6] Installation summary..." -ForegroundColor Cyan
Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "                     Installation Complete!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Quick Start:" -ForegroundColor Cyan
Write-Host "  1. Double-click desktop shortcut" -ForegroundColor Gray
Write-Host "  2. Or run: .\scripts\start.ps1" -ForegroundColor Gray
Write-Host "  3. Access http://localhost:19527 to view Dashboard" -ForegroundColor Gray
Write-Host ""
Write-Host "Common Commands:" -ForegroundColor Cyan
Write-Host "  Start monitoring: .\scripts\start.ps1" -ForegroundColor Gray
Write-Host "  Quick cleanup: .\scripts\quick-cleanup.ps1" -ForegroundColor Gray
Write-Host "  Configure auto-start: Set-AutoStart -Action Enable" -ForegroundColor Gray
Write-Host "  Uninstall: .\scripts\uninstall.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Data Directories:" -ForegroundColor Cyan
Write-Host "  Config file: config\settings.json" -ForegroundColor Gray
Write-Host "  Log files: C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\logs\" -ForegroundColor Gray
Write-Host "  State data: C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\data\" -ForegroundColor Gray
Write-Host ""
Write-Host "Thank you for using MemoryGuardian Pro!" -ForegroundColor Green
Write-Host ""
