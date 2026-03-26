# AutoStart Module - Auto-Startup Configuration
# Manages Windows auto-startup via registry and task scheduler

<#
.SYNOPSIS
    Enable auto-startup via registry
.DESCRIPTION
    Adds MemoryGuardian to Windows registry for auto-startup
#>
function Enable-AutoStartRegistry {
    [CmdletBinding()]
    param()
    
    try {
        $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $regName = 'MemoryGuardian-Pro'
        
        # Get script path - 修复路径问题
        $scriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $scriptPath = Join-Path $scriptRoot "scripts\start.ps1"
        
        # Create command - 移除 DashboardPort 参数，添加 NoDashboard 和 LogToFile 参数
        $command = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -NoDashboard -LogToFile"
        
        # Set registry value
        Set-ItemProperty -Path $regPath -Name $regName -Value $command -Force
        
        Write-Host "INFO: Auto-startup enabled via registry" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "ERROR: Failed to enable auto-startup via registry: $_" -ForegroundColor Red
        return $false
    }
}

<#
.SYNOPSIS
    Disable auto-startup via registry
.DESCRIPTION
    Removes MemoryGuardian from Windows registry
#>
function Disable-AutoStartRegistry {
    [CmdletBinding()]
    param()
    
    try {
        $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $regName = 'MemoryGuardian-Pro'
        
        if (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $regPath -Name $regName -Force
            Write-Log "INFO" "Auto-startup disabled via registry"
            return $true
        } else {
            Write-Log "INFO" "Auto-startup not enabled via registry"
            return $false
        }
        
    } catch {
        Write-Log "ERROR" "Failed to disable auto-startup via registry: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Enable auto-startup via Task Scheduler
.DESCRIPTION
    Creates scheduled task for MemoryGuardian auto-startup
#>
function Enable-AutoStartTaskScheduler {
    [CmdletBinding()]
    param()
    
    try {
        $taskName = 'MemoryGuardian-Pro'
        
        # Get script path - 修复路径问题
        $scriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $scriptPath = Join-Path $scriptRoot "scripts\start.ps1"
        $logDir = Join-Path $scriptRoot "logs"
        
        # Create action - 移除 DashboardPort 参数，添加 NoDashboard 和 LogToFile 参数
        $action = New-ScheduledTaskAction `
            -Execute "powershell.exe" `
            -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -NoDashboard -LogToFile" `
            -WorkingDirectory $scriptRoot
        
        # Create trigger (at logon)
        $trigger = New-ScheduledTaskTrigger -AtLogon -User $env:USERNAME
        
        # Create settings
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -DontStopOnIdleEnd `
            -MultipleInstances IgnoreNew
        
        # Register task
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -RunLevel Highest `
            -Force | Out-Null
        
        Write-Host "INFO: Auto-startup enabled via Task Scheduler" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "ERROR: Failed to enable auto-startup via Task Scheduler: $_" -ForegroundColor Red
        return $false
    }
}

<#
.SYNOPSIS
    Disable auto-startup via Task Scheduler
.DESCRIPTION
    Removes MemoryGuardian scheduled task
#>
function Disable-AutoStartTaskScheduler {
    [CmdletBinding()]
    param()
    
    try {
        $taskName = 'MemoryGuardian-Pro'
        
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        
        if ($task) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Log "INFO" "Auto-startup disabled via Task Scheduler"
            return $true
        } else {
            Write-Log "INFO" "Auto-startup not enabled via Task Scheduler"
            return $false
        }
        
    } catch {
        Write-Log "ERROR" "Failed to disable auto-startup via Task Scheduler: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Check auto-startup status
.DESCRIPTION
    Returns current auto-startup status
#>
function Get-AutoStartStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    # Check registry
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $regEnabled = $false
    if (Get-ItemProperty -Path $regPath -Name 'MemoryGuardian-Pro' -ErrorAction SilentlyContinue) {
        $regEnabled = $true
    }
    
    # Check Task Scheduler
    $taskName = 'MemoryGuardian-Pro'
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    $taskEnabled = $false
    if ($task) {
        $taskEnabled = $true
    }
    
    return [PSCustomObject]@{
        RegistryEnabled = $regEnabled
        TaskSchedulerEnabled = $taskEnabled
        AnyEnabled = $regEnabled -or $taskEnabled
    }
}

<#
.SYNOPSIS
    Create desktop shortcut
.DESCRIPTION
    Creates desktop shortcut for easy access
#>
function New-DesktopShortcut {
    [CmdletBinding()]
    param()
    
    try {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $shortcutPath = Join-Path $desktopPath "MemoryGuardian-Pro.lnk"
        
        # Get script path
        $scriptPath = Join-Path $PSScriptRoot "..\scripts\start.ps1"
        $scriptPath = Resolve-Path $scriptPath
        
        # Create WScript Shell object
        $wsh = New-Object -ComObject WScript.Shell
        
        # Create shortcut
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -DashboardPort 19527"
        $shortcut.WorkingDirectory = Split-Path $scriptPath
        $shortcut.Description = "MemoryGuardian Pro - Memory Optimization and Monitoring"
        $shortcut.IconLocation = "C:\Windows\System32\shell32.dll,21"
        $shortcut.Save()
        
        Write-Log "INFO" "Desktop shortcut created at: $shortcutPath"
        return $true
        
    } catch {
        Write-Log "ERROR" "Failed to create desktop shortcut: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Remove desktop shortcut
.DESCRIPTION
    Removes desktop shortcut
#>
function Remove-DesktopShortcut {
    [CmdletBinding()]
    param()
    
    try {
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $shortcutPath = Join-Path $desktopPath "MemoryGuardian-Pro.lnk"
        
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
            Write-Log "INFO" "Desktop shortcut removed"
            return $true
        } else {
            Write-Log "INFO" "Desktop shortcut not found"
            return $false
        }
        
    } catch {
        Write-Log "ERROR" "Failed to remove desktop shortcut: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Configure auto-startup
.DESCRIPTION
    Main function to configure auto-startup with specified method
#>
function Set-AutoStart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Enable', 'Disable')]
        [string]$Action,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Registry', 'TaskScheduler', 'Both')]
        [string]$Method = 'TaskScheduler',
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateShortcut
    )
    
    if ($Action -eq 'Enable') {
        $result = @()
        
        if ($Method -eq 'Registry' -or $Method -eq 'Both') {
            $result += Enable-AutoStartRegistry
        }
        
        if ($Method -eq 'TaskScheduler' -or $Method -eq 'Both') {
            $result += Enable-AutoStartTaskScheduler
        }
        
        if ($CreateShortcut) {
            New-DesktopShortcut | Out-Null
        }
        
        return $result -contains $true
        
    } else {
        # Disable
        $result = @()
        
        if ($Method -eq 'Registry' -or $Method -eq 'Both') {
            $result += Disable-AutoStartRegistry
        }
        
        if ($Method -eq 'TaskScheduler' -or $Method -eq 'Both') {
            $result += Disable-AutoStartTaskScheduler
        }
        
        if ($CreateShortcut) {
            Remove-DesktopShortcut | Out-Null
        }
        
        return $result -contains $true
    }
}