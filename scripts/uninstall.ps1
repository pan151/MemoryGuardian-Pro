# ============================================================
# uninstall.ps1 - Uninstallation Script
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "   MemoryGuardian Pro - Uninstallation Wizard" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

# Get script root directory
$ScriptRoot = Split-Path -Parent $PSScriptRoot

# Confirm uninstallation
Write-Host "[WARN] This will uninstall MemoryGuardian Pro" -ForegroundColor Yellow
Write-Host "  - Remove auto-startup configuration" -ForegroundColor Yellow
Write-Host "  - Remove desktop shortcut" -ForegroundColor Yellow
Write-Host "  - Keep data files (logs, state)" -ForegroundColor Yellow
Write-Host ""

$response = Read-Host "Proceed with uninstallation? (Y/N)"

if ($response -ne "Y" -and $response -ne "y") {
    Write-Host "Uninstallation cancelled" -ForegroundColor Gray
    exit 0
}

Write-Host ""
Write-Host "[1/4] Disabling auto-startup..." -ForegroundColor Cyan

try {
    Import-Module "$ScriptRoot\src\integrations\AutoStart.psm1" -Force
    
    Disable-AutoStartRegistry | Out-Null
    Disable-AutoStartTaskScheduler | Out-Null
    
    Write-Host "  OK Auto-startup disabled" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] Failed to disable auto-startup: $_" -ForegroundColor Yellow
}

Write-Host ""

Write-Host "[2/4] Removing desktop shortcut..." -ForegroundColor Cyan

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "MemoryGuardian-Pro.lnk"

if (Test-Path $shortcutPath) {
    try {
        Remove-Item $shortcutPath -Force
        Write-Host "  OK Desktop shortcut removed" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Failed to remove shortcut: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [INFO] Desktop shortcut not found" -ForegroundColor Gray
}

Write-Host ""

Write-Host "[3/4] Stopping running processes..." -ForegroundColor Cyan

# Find and stop MemoryGuardian processes
$processes = Get-Process -Name "powershell" -ErrorAction SilentlyContinue | 
             Where-Object { $_.CommandLine -like "*MemoryGuardian*" }

if ($processes) {
    $count = 0
    foreach ($process in $processes) {
        try {
            Stop-Process -Id $process.Id -Force
            $count++
        } catch {
            Write-Log "WARN" "Failed to stop process $($process.Id): $_"
        }
    }
    
    if ($count -gt 0) {
        Write-Host "  OK Stopped $count process(es)" -ForegroundColor Green
    }
} else {
    Write-Host "  [INFO] No running processes found" -ForegroundColor Gray
}

Write-Host ""

Write-Host "[4/4] Uninstallation summary..." -ForegroundColor Cyan
Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "                     Uninstallation Complete!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Completed:" -ForegroundColor Cyan
Write-Host "  - Auto-startup disabled" -ForegroundColor Gray
Write-Host "  - Desktop shortcut removed" -ForegroundColor Gray
Write-Host "  - Running processes stopped" -ForegroundColor Gray
Write-Host ""
Write-Host "Preserved:" -ForegroundColor Cyan
Write-Host "  - Log files: C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\logs\" -ForegroundColor Gray
Write-Host "  - State data: C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\data\" -ForegroundColor Gray
Write-Host ""
Write-Host "If you want to completely remove MemoryGuardian Pro:" -ForegroundColor Yellow
Write-Host "  1. Delete the project directory: $ScriptRoot" -ForegroundColor Yellow
Write-Host "  2. Delete data directory: C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\" -ForegroundColor Yellow
Write-Host ""
Write-Host "Thank you for using MemoryGuardian Pro!" -ForegroundColor Green
Write-Host ""
