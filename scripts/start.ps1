<#
.SYNOPSIS
    MemoryGuardian Pro Startup Script

.DESCRIPTION
    Starts the memory monitoring and optimization daemon

.PARAMETER ConfigFile
    Path to configuration file (default: config/settings.json)

.PARAMETER DashboardPort
    Dashboard service port (default: 8888)

.PARAMETER NoDashboard
    Do not start Dashboard service

.PARAMETER LogToFile
    Output logs to file

.PARAMETER LogDirectory
    Log directory (default: logs)

.PARAMETER DryRun
    Dry run mode (do not execute actual optimization operations)

.EXAMPLE
    .\start.ps1
    Start MemoryGuardian with default configuration

.EXAMPLE
    .\start.ps1 -DashboardPort 9999 -LogToFile
    Start MemoryGuardian with port 9999 and log to file

.EXAMPLE
    .\start.ps1 -DryRun
    Start MemoryGuardian in dry run mode

.NOTES
    Version: 2.0.0
    Author: MemoryGuardian Team
#>

[CmdletBinding()]
param(
    [string]$ConfigFile = "config\settings.json",
    
    [int]$DashboardPort = 8888,
    
    [switch]$NoDashboard,
    
    [switch]$LogToFile,
    
    [string]$LogDirectory,
    
    [switch]$DryRun
)

# Get script root
$ScriptRoot = Split-Path -Parent $PSScriptRoot

# Import required modules
Import-Module "$ScriptRoot\src\core\MemoryMonitor.psm1" -Force
Import-Module "$ScriptRoot\src\core\StateManager.psm1" -Force
Import-Module "$ScriptRoot\src\core\Executor.psm1" -Force
Import-Module "$ScriptRoot\src\utils\Logger.psm1" -Force
Import-Module "$ScriptRoot\src\ui\AlertPopup.psm1" -Force
Import-Module "$ScriptRoot\src\dashboard\Dashboard.psm1" -Force

# Load configuration
$configPath = Join-Path $ScriptRoot $ConfigFile
$rulesPath = Join-Path $ScriptRoot "config\rules.json"

if (-not (Test-Path $configPath)) {
    Write-Log "ERROR" "Configuration file not found: $configPath"
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Initialize logger
if ($LogToFile) {
    # Use config directory if not specified
    if (-not $LogDirectory) {
        $LogDirectory = if ($config.logging -and $config.logging.directory) {
            $config.logging.directory
        } else {
            "logs"
        }
    }
    
    $logPath = Join-Path $ScriptRoot $LogDirectory
    if (-not (Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    
    $logFile = Join-Path $logPath "MemoryGuardian_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    Initialize-Logger -LogFile $logFile -LogToConsole $true -LogToFile $true -LogLevel INFO
} else {
    Initialize-Logger -LogToConsole $true -LogLevel INFO
}

# Initialize components
Write-Log "INFO" "Initializing MemoryGuardian Pro..."
Initialize-MemoryMonitor -ConfigPath $configPath -RulesPath $rulesPath

# Use data directory from config if available
$historyRetentionHours = if ($config.dataStorage -and $config.dataStorage.retentionHours) {
    $config.dataStorage.retentionHours
} else {
    168
}
Initialize-StateManager -HistoryRetentionHours $historyRetentionHours
Initialize-Executor

# Start Dashboard if requested
if (-not $NoDashboard) {
    try {
        Write-Log "INFO" "Starting Dashboard on port $DashboardPort..."
        $dashboardHtml = Join-Path $ScriptRoot "src\dashboard\index.html"
        $dashboardData = Join-Path $ScriptRoot "src\dashboard\data.json"

        if (Test-Path $dashboardHtml) {
            Start-DashboardServer -HtmlPath $dashboardHtml -DataPath $dashboardData -Port $DashboardPort -AutoOpen
            Write-Log "INFO" "Dashboard started successfully"
        } else {
            Write-Log "WARN" "Dashboard HTML not found: $dashboardHtml"
        }
    } catch {
        Write-Log "ERROR" "Failed to start Dashboard: $_"
        Write-Log "WARN" "Continuing without Dashboard..."
    }
}

# Start monitoring loop
Write-Log "INFO" "Starting memory monitoring loop..."
Write-Log "INFO" "Press Ctrl+C to stop monitoring"

$running = $true

# Handle Ctrl+C gracefully
[Console]::TreatControlCAsInput = $false
$consoleCancelEvent = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    $script:running = $false
    Write-Log "INFO" "Shutting down MemoryGuardian Pro..."
}

try {
    while ($running) {
        try {
            # Check memory
            $memoryInfo = Get-MemoryInfo
            
            # Get top processes
            $topProcs = Get-TopMemoryProcesses -Count 10
            
            # Analyze
            $analysis = Invoke-MemoryAnalysis
            
            # Update state
            Update-State `
                -MemPct $memoryInfo.UsagePercent `
                -MemUsedGB $memoryInfo.UsedGB `
                -MemFreeGB $memoryInfo.FreeGB `
                -MemTotalGB $memoryInfo.TotalGB `
                -TopProcs $topProcs `
                -Findings $analysis.Findings `
                -RiskScore $analysis.RiskScore
            
            # Check for alerts
            if ($memoryInfo.UsagePercent -ge $config.monitoring.alertThresholdPct) {
                Write-Log "WARN" "Memory usage exceeded threshold: $($memoryInfo.UsagePercent.ToString('F1'))%"
                
                # Show popup if needed
                $cooldownKey = "alert_$(Get-Date -Format 'yyyyMMdd')"
                if (-not (Test-AlertCooldown -ProcessKey $cooldownKey -CooldownMinutes $config.monitoring.alertCooldownMinutes)) {
                    $topProcNames = $topProcs | Select-Object -First 5 | ForEach-Object { "$($_.ProcessName) ($([Math]::Round($_.WorkingSet64 / 1MB, 0)) MB)" }
                    
                    Show-AlertPopup `
                        -MemoryUsagePct $memoryInfo.UsagePercent `
                        -TopProcesses $topProcNames `
                        -CleanupAction {
                            if (-not $DryRun) {
                                Invoke-OptimizationCommand -Command 'Clean-SystemMemory'
                            }
                        }
                    
                    Set-AlertCooldown -ProcessKey $cooldownKey
                }
                
                # Execute auto-optimization if enabled
                if ($config.optimization.autoOptimizeEnabled -and -not $DryRun) {
                    Write-Log "INFO" "Executing auto-optimization..."
                    Invoke-OptimizationCommand -Command 'Clean-SystemMemory'
                }
            }
            
            # Log current status
            Write-Log "DEBUG" "Memory: $($memoryInfo.UsagePercent.ToString('F1'))% | Risk: $($analysis.RiskScore) | Procs: $($topProcs.Count)"
            
        } catch {
            Write-Log "ERROR" "Error in monitoring loop: $_"
        }
        
        # Wait for next iteration
        $checkInterval = if ($config -and $config.monitoring -and $config.monitoring.checkIntervalSeconds) {
            $config.monitoring.checkIntervalSeconds
        } else {
            5  # Default interval
        }
        Start-Sleep -Seconds $checkInterval
    }
    
} finally {
    # Cleanup
    Write-Log "INFO" "Stopping monitoring..."
    
    if (-not $NoDashboard) {
        Stop-Dashboard
    }
    
    Unregister-Event -SourceIdentifier PowerShell.Exiting -ErrorAction SilentlyContinue
    Write-Log "INFO" "MemoryGuardian Pro stopped"
}
