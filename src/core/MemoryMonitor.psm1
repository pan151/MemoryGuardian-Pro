# ============================================================
# MemoryMonitor.psm1 - Core Monitoring Engine
# ============================================================

$script:Settings = $null
$script:Rules = $null
$script:GuardianState = $null

# ============================================================
# Initialization
# ============================================================
function Initialize-MemoryMonitor {
    param(
        [string]$ConfigPath,
        [string]$RulesPath
    )

    # Determine base directory
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $PSScriptRoot "..\..\config\settings.json" | Resolve-Path
    }
    if (-not $RulesPath) {
        $RulesPath = Join-Path $PSScriptRoot "..\..\config\rules.json" | Resolve-Path
    }

    # Load configuration
    if (Test-Path $ConfigPath) {
        $script:Settings = Get-Content $ConfigPath | ConvertFrom-Json
    } else {
        Write-Log "WARN" "Config file not found: $ConfigPath"
        $script:Settings = @{}
    }

    # Load rules
    if (Test-Path $RulesPath) {
        $script:Rules = Get-Content $RulesPath | ConvertFrom-Json
    } else {
        Write-Log "WARN" "Rules file not found: $RulesPath"
        $script:Rules = @{}
    }

    # Initialize state
    $script:GuardianState = [hashtable]::Synchronized(@{
        Round = 0
        LastCheck = [datetime]::Now
        MemPct = 0.0
        MemUsedGB = 0.0
        MemTotalGB = 0.0
        MemFreeGB = 0.0
        TopProcs = @()
        Findings = @()
        History = [System.Collections.ArrayList]::new()
        ActionLog = [System.Collections.ArrayList]::new()
        AlertShown = @{}
        PrevSnapshot = @()
        Stats = @{
            Alerts = 0
            LeaksDetected = 0
            MaxMem = 0.0
            TotalFreedMB = 0.0
        }
    })

    Write-Log "INFO" "MemoryMonitor initialized"
    return $script:GuardianState
}

# ============================================================
# Logging
# ============================================================
function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )

    if (-not $script:Settings) {
        Write-Host "[$Level] $Message"
        return
    }

    if (-not $script:Settings.logging.enabled) { return }

    $ts = [datetime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$ts][$Level] $Message"

    # Console output
    $color = switch($Level) {
        "ALERT" { "Red" }
        "WARN" { "Yellow" }
        "OK" { "Green" }
        "AI" { "Cyan" }
        default { "Gray" }
    }
    Write-Host $line -ForegroundColor $color

    # Add to log record
    $entry = @{
        time = $ts
        level = $Level
        msg = $Message
    }
    $null = $script:GuardianState.ActionLog.Add($entry)

    # Maintain log size
    if ($script:GuardianState.ActionLog.Count -gt 200) {
        $script:GuardianState.ActionLog.RemoveAt(0)
    }

    # Write to file
    $logDir = "C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = Join-Path $logDir ("memory_guardian_{0:yyyyMMdd}.log" -f [datetime]::Now)
    Add-Content $logFile $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

# ============================================================
# Memory Status Collection
# ============================================================
function Get-MemoryStatus {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $totalMB = [math]::Round($os.TotalVisibleMemorySize/1KB, 0)
    $freeMB = [math]::Round($os.FreePhysicalMemory/1KB, 0)
    $usedMB = $totalMB - $freeMB
    $usedPct = [math]::Round($usedMB/$totalMB*100, 1)

    return @{
        TotalMB = $totalMB
        FreeMB = $freeMB
        UsedMB = $usedMB
        UsedPct = $usedPct
        TotalGB = [math]::Round($totalMB/1024, 1)
        FreeGB = [math]::Round($freeMB/1024, 1)
        UsedGB = [math]::Round($usedMB/1024, 1)
    }
}

# ============================================================
# Process Snapshot
# ============================================================
function Get-ProcessSnapshot {
    $processes = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 30 |
        ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                PID = $_.Id
                MemMB = [math]::Round($_.WorkingSet64/1MB, 1)
                CPU = [math]::Round($_.CPU, 1)
                StartTime = $_.StartTime
            }
        }

    return $processes
}

# ============================================================
# AI Analysis Engine
# ============================================================
function Invoke-AIAnalysis {
    param(
        [hashtable]$MemStatus,
        [array]$Processes
    )

    $analysis = [System.Collections.ArrayList]::new()

    # Apply high risk rules
    foreach ($rule in $script:Rules.highRiskRules) {
        $matched = $Processes | Where-Object { $_.Name -eq $rule.name -and $_.MemMB -gt $rule.maxMB }
        foreach ($p in $matched) {
            $null = $analysis.Add([PSCustomObject]@{
                Severity = if ($p.MemMB -gt $rule.maxMB * 2) { "CRITICAL" } else { "WARNING" }
                PID = $p.PID
                Name = $p.Name
                MemMB = $p.MemMB
                Reason = $rule.reason
                KillCmd = if ($rule.killCmd) { $rule.killCmd } else { "taskkill /F /PID $($p.PID)" }
                Action = if ($p.MemMB -gt $script:Settings.monitoring.processKillMB -and $p.Name -notin $script:Rules.whitelist) { "KILL" } else { "ALERT" }
            })
        }
    }

    # High memory threshold detection
    $bigProcs = $Processes | Where-Object { $_.MemMB -gt $script:Settings.monitoring.processAlertMB -and $_.Name -notin $script:Rules.whitelist }
    foreach ($p in $bigProcs) {
        if (-not ($analysis | Where-Object { $_.PID -eq $p.PID })) {
            $null = $analysis.Add([PSCustomObject]@{
                Severity = if ($p.MemMB -gt $script:Settings.monitoring.processKillMB) { "CRITICAL" } else { "WARNING" }
                PID = $p.PID
                Name = $p.Name
                MemMB = $p.MemMB
                Reason = "Single process memory exceeds $($script:Settings.monitoring.processAlertMB)MB threshold"
                KillCmd = "taskkill /F /PID $($p.PID)"
                Action = if ($p.MemMB -gt $script:Settings.monitoring.processKillMB) { "KILL" } else { "ALERT" }
            })
        }
    }

    # Trend detection
    if ($script:GuardianState.PrevSnapshot.Count -gt 0) {
        foreach ($curr in $Processes) {
            $prev = $script:GuardianState.PrevSnapshot | Where-Object { $_.PID -eq $curr.PID }
            if ($prev) {
                $growthMB = $curr.MemMB - $prev.MemMB
                $growthPct = if ($prev.MemMB -gt 0) { [math]::Round($growthMB/$prev.MemMB*100, 1) } else { 0 }

                if ($growthMB -gt 200 -and $growthPct -gt 30 -and -not ($analysis | Where-Object { $_.PID -eq $curr.PID })) {
                    $null = $analysis.Add([PSCustomObject]@{
                        Severity = "WARNING"
                        PID = $curr.PID
                        Name = $curr.Name
                        MemMB = $curr.MemMB
                        Reason = "Rapid memory growth: +${growthMB}MB (+${growthPct}%) / $($script:Settings.monitoring.intervalSeconds)s"
                        KillCmd = "taskkill /F /PID $($curr.PID)"
                        Action = "ALERT"
                    })
                }
            }
        }
    }

    return $analysis
}

# ============================================================
# Memory Optimization
# ============================================================
function Invoke-MemoryOptimization {
    param(
        [switch]$Force,
        [switch]$WorkingSetOnly
    )

    $freed = 0

    # Release working set
    if (-not $WorkingSetOnly -or $script:Settings.autoOptimization.autoReleaseWorkingSet) {
        try {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class MemOpt {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
"@ -ErrorAction SilentlyContinue

            $procs = Get-Process | Where-Object { $_.WorkingSet64 -gt 100MB -and $_.Name -notin @("System", "smss", "csrss", "wininit", "services", "lsass") }

            foreach ($p in $procs) {
                try {
                    $before = $p.WorkingSet64
                    [MemOpt]::EmptyWorkingSet($p.Handle) | Out-Null
                    $p.Refresh()
                    $freed += ($before - $p.WorkingSet64)
                } catch {}
            }
        } catch {
            Write-Log "WARN" "Failed to release working set: $_"
        }
    }

    $freedMB = [math]::Round($freed/1MB, 1)
    $script:GuardianState.Stats.TotalFreedMB += $freedMB

    Write-Log "OK" "Released ${freedMB} MB memory"
    return $freedMB
}

# ============================================================
# Execute Cleanup Command
# ============================================================
function Invoke-CleanupAction {
    param(
        [string]$Command
    )

    try {
        # Security filter
        if ($Command -match '^(taskkill|net stop|Stop-Process)') {
            $result = cmd /c $Command 2>&1
            Write-Log "ACTION" "Execute cleanup: $Command"
            return @{ Success = $true; Output = $result }
        } else {
            Write-Log "WARN" "Command blocked by security filter: $Command"
            return @{ Success = $false; Output = "Command blocked by security filter" }
        }
    } catch {
        Write-Log "ERROR" "Cleanup execution failed: $_"
        return @{ Success = $false; Output = $_.Exception.Message }
    }
}

# ============================================================
# Export State as JSON
# ============================================================
function Export-GuardianState {
    $outputPath = "C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\data\guardian_state.json"
    $outputDir = Split-Path $outputPath -Parent

    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $state = $script:GuardianState

    # Build serializable data
    $findingsArr = @($state.Findings | ForEach-Object {
        @{ severity=$_.Severity; pid=$_.PID; name=$_.Name; memMB=$_.MemMB; reason=$_.Reason; killCmd=$_.KillCmd; action=$_.Action }
    })

    $topProcsArr = @($state.TopProcs | Select-Object -First 20 | ForEach-Object {
        @{ name=$_.Name; pid=$_.PID; memMB=$_.MemMB; cpu=$_.CPU }
    })

    $historyArr = @($state.History | Select-Object -Last 60)
    $logsArr = @($state.ActionLog | Select-Object -Last 50)

    $obj = @{
        ts = [datetime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        round = $state.Round
        memPct = $state.MemPct
        memUsedGB = $state.MemUsedGB
        memFreeGB = $state.MemFreeGB
        memTotalGB = $state.MemTotalGB
        alertPct = $script:Settings.monitoring.alertThresholdPct
        criticalPct = $script:Settings.monitoring.criticalThresholdPct
        autoKill = $script:Settings.autoOptimization.autoKill
        findings = $findingsArr
        topProcs = $topProcsArr
        history = $historyArr
        logs = $logsArr
        stats = $state.Stats
    }

    $json = $obj | ConvertTo-Json -Depth 5 -Compress
    [System.IO.File]::WriteAllText($outputPath, $json, [System.Text.Encoding]::UTF8)
}

# ============================================================
# Main Monitoring Loop
# ============================================================
function Start-MonitoringLoop {
    param(
        [scriptblock]$OnAlert,
        [scriptblock]$OnCritical
    )

    Write-Log "INFO" "Starting monitoring loop - Interval: $($script:Settings.monitoring.intervalSeconds)s"

    $consecutiveCritical = 0

    while ($true) {
        $script:GuardianState.Round++
        $round = $script:GuardianState.Round

        # Collect data
        $mem = Get-MemoryStatus
        $script:GuardianState.MemPct = $mem.UsedPct
        $script:GuardianState.MemUsedGB = $mem.UsedGB
        $script:GuardianState.MemFreeGB = $mem.FreeGB
        $script:GuardianState.MemTotalGB = $mem.TotalGB
        $script:GuardianState.LastCheck = [datetime]::Now

        # Update peak
        if ($mem.UsedPct -gt $script:GuardianState.Stats.MaxMem) {
            $script:GuardianState.Stats.MaxMem = $mem.UsedPct
        }

        # History record
        $null = $script:GuardianState.History.Add(@{
            t = [datetime]::Now.ToString("HH:mm:ss")
            pct = $mem.UsedPct
            usedGB = $mem.UsedGB
        })
        if ($script:GuardianState.History.Count -gt $script:Settings.monitoring.historySize) {
            $script:GuardianState.History.RemoveAt(0)
        }

        # Process snapshot
        $topProcs = Get-ProcessSnapshot
        $script:GuardianState.TopProcs = $topProcs

        # AI Analysis
        $findings = Invoke-AIAnalysis -MemStatus $mem -Processes $topProcs
        $script:GuardianState.Findings = $findings

        # Export state
        Export-GuardianState

        # System-level alert
        if ($mem.UsedPct -ge $script:Settings.monitoring.criticalThresholdPct) {
            $consecutiveCritical++
            Write-Log "ALERT" "System memory critical: $($mem.UsedPct)%  consecutive ${consecutiveCritical} rounds"

            if ($consecutiveCritical -ge $script:Settings.autoOptimization.criticalConsecutiveCount) {
                if ($script:Settings.autoOptimization.autoReleaseWorkingSet) {
                    Write-Log "AI" "Consecutive critical, auto release working set..."
                    $freed = Invoke-MemoryOptimization -WorkingSetOnly
                    Write-Log "OK" "Released ${freed} MB"
                }
                $consecutiveCritical = 0

                if ($OnCritical) {
                    & $OnCritical $mem
                }
            }
        } elseif ($mem.UsedPct -ge $script:Settings.monitoring.alertThresholdPct) {
            $consecutiveCritical = 0
            Write-Log "WARN" "Memory alert: $($mem.UsedPct)%  ($($mem.UsedGB)/$($mem.TotalGB) GB)"
        } else {
            $consecutiveCritical = 0
        }

        # Popup alert & logging
        foreach ($f in $findings) {
            Write-Log "AI" "[$($f.Severity)] $($f.Name) PID=$($f.PID) $($f.MemMB)MB - $($f.Reason)"

            if ($OnAlert) {
                & $OnAlert $f
            }

            # Auto kill
            if ($script:Settings.autoOptimization.autoKill -and $f.Action -eq "KILL") {
                $result = Invoke-CleanupAction -Command $f.KillCmd
                if ($result.Success) {
                    Write-Log "ALERT" "Auto kill: $($f.Name) PID=$($f.PID)"
                } else {
                    Write-Log "WARN" "Failed to kill $($f.Name): $($result.Output)"
                }
            }
        }

        # Save previous snapshot
        $script:GuardianState.PrevSnapshot = $topProcs

        # Console status display
        $bar_f = [math]::Floor($mem.UsedPct/5)
        $bar = "[" + ("=" * $bar_f) + ("-" * (20-$bar_f)) + "]"
        $col = if($mem.UsedPct -gt 90){"Red"} elseif($mem.UsedPct -gt 80){"Yellow"} else {"Green"}

        Write-Host ""
        Write-Host "[$([datetime]::Now.ToString('HH:mm:ss'))] #${round}  Memory: " -NoNewline
        Write-Host "$bar $($mem.UsedPct)%  ($($mem.UsedGB)/$($mem.TotalGB)GB)" -ForegroundColor $col

        if ($findings.Count -gt 0) {
            Write-Host "  Found $($findings.Count) abnormal processes" -ForegroundColor Red
        }

        Start-Sleep -Seconds $script:Settings.monitoring.intervalSeconds
    }
}

# ============================================================
# Additional Helper Functions for Dashboard
# ============================================================

function Get-MemoryInfo {
    <#
    .SYNOPSIS
        Get current memory information for dashboard
    .DESCRIPTION
        Returns memory statistics in a format suitable for the dashboard API
    #>
    $memStatus = Get-MemoryStatus
    return [PSCustomObject]@{
        UsagePercent = $memStatus.UsedPct
        UsedGB = $memStatus.UsedGB
        FreeGB = $memStatus.FreeGB
        TotalGB = $memStatus.TotalGB
        AvailableGB = $memStatus.AvailableGB
        CachedGB = $memStatus.CachedGB
        Timestamp = [datetime]::Now
    }
}

function Get-TopMemoryProcesses {
    <#
    .SYNOPSIS
        Get top memory-consuming processes
    .DESCRIPTION
        Returns top N processes by memory usage for dashboard display
    #>
    param([int]$Count = 20)

    $procs = Get-Process | Where-Object { $_.WorkingSet64 -gt 0 } |
        Sort-Object -Property WorkingSet64 -Descending |
        Select-Object -First $Count |
        ForEach-Object {
            [PSCustomObject]@{
                Name = $_.ProcessName
                Id = $_.Id
                WorkingSet64 = $_.WorkingSet64
                WorkingSetMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
                CPU = [math]::Round($_.CPU, 2)
                StartTime = $_.StartTime
            }
        }

    return $procs
}

function Invoke-MemoryAnalysis {
    <#
    .SYNOPSIS
        Analyze memory usage and detect issues
    .DESCRIPTION
        Returns risk assessment and findings
    #>
    param(
        $MemoryInfo,
        $TopProcs
    )

    # Default values
    $findings = @()
    $riskScore = 0

    # Calculate risk based on memory usage
    if ($MemoryInfo.UsagePercent -gt 90) {
        $riskScore = 90 + [math]::Min(10, ($MemoryInfo.UsagePercent - 90))
        $findings += [PSCustomObject]@{
            Severity = "CRITICAL"
            Name = "High Memory Usage"
            PID = 0
            MemMB = [math]::Round($MemoryInfo.UsedGB * 1024, 2)
            Reason = "System memory usage is critically high"
        }
    } elseif ($MemoryInfo.UsagePercent -gt 80) {
        $riskScore = 70 + [math]::Min(20, ($MemoryInfo.UsagePercent - 80))
        $findings += [PSCustomObject]@{
            Severity = "HIGH"
            Name = "Elevated Memory Usage"
            PID = 0
            MemMB = [math]::Round($MemoryInfo.UsedGB * 1024, 2)
            Reason = "System memory usage is above threshold"
        }
    } elseif ($MemoryInfo.UsagePercent -gt 70) {
        $riskScore = 50 + [math]::Min(20, ($MemoryInfo.UsagePercent - 70))
    }

    # Check for high-memory processes
    $highMemProcs = $TopProcs | Where-Object { $_.WorkingSetMB -gt 500 }
    foreach ($proc in $highMemProcs) {
        if ($proc.WorkingSetMB -gt 1000) {
            $findings += [PSCustomObject]@{
                Severity = "HIGH"
                Name = $proc.Name
                PID = $proc.Id
                MemMB = $proc.WorkingSetMB
                Reason = "Process using excessive memory (>1GB)"
            }
            $riskScore = [math]::Min(100, $riskScore + 10)
        } elseif ($proc.WorkingSetMB -gt 500) {
            $findings += [PSCustomObject]@{
                Severity = "MEDIUM"
                Name = $proc.Name
                PID = $proc.Id
                MemMB = $proc.WorkingSetMB
                Reason = "Process using elevated memory (>500MB)"
            }
            $riskScore = [math]::Min(100, $riskScore + 5)
        }
    }

    return [PSCustomObject]@{
        RiskScore = $riskScore
        Findings = $findings
        Timestamp = [datetime]::Now
    }
}

function Update-State {
    <#
    .SYNOPSIS
        Update monitoring state
    #>
    param(
        [double]$MemPct,
        [double]$MemUsedGB,
        [double]$MemFreeGB,
        [double]$MemTotalGB,
        $TopProcs,
        $Findings,
        [int]$RiskScore
    )

    if ($script:GuardianState) {
        $script:GuardianState.MemPct = $MemPct
        $script:GuardianState.MemUsedGB = $MemUsedGB
        $script:GuardianState.MemFreeGB = $MemFreeGB
        $script:GuardianState.MemTotalGB = $MemTotalGB
        $script:GuardianState.TopProcs = $TopProcs
        $script:GuardianState.Findings = $Findings
        $script:GuardianState.RiskScore = $RiskScore
        $script:GuardianState.LastCheck = [datetime]::Now
        $script:GuardianState.Round++

        # Add to history
        $historyEntry = [PSCustomObject]@{
            Timestamp = [datetime]::Now
            MemPct = $MemPct
            MemUsedGB = $MemUsedGB
            MemFreeGB = $MemFreeGB
            MemTotalGB = $MemTotalGB
            RiskScore = $RiskScore
        }
        $script:GuardianState.History.Add($historyEntry) | Out-Null
    }
}

function Test-AlertCooldown {
    <#
    .SYNOPSIS
        Check if alert is in cooldown period
    #>
    param(
        [string]$ProcessKey,
        [int]$CooldownMinutes
    )

    if (-not $script:GuardianState) { return $false }
    if (-not $script:GuardianState.AlertShown.ContainsKey($ProcessKey)) { return $false }

    $lastShown = $script:GuardianState.AlertShown[$ProcessKey]
    $elapsed = ([datetime]::Now - $lastShown).TotalMinutes

    return $elapsed -lt $CooldownMinutes
}

function Set-AlertCooldown {
    <#
    .SYNOPSIS
        Set alert cooldown timestamp
    #>
    param([string]$ProcessKey)

    if ($script:GuardianState) {
        $script:GuardianState.AlertShown[$ProcessKey] = [datetime]::Now
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-MemoryMonitor',
    'Write-Log',
    'Get-MemoryStatus',
    'Get-ProcessSnapshot',
    'Invoke-AIAnalysis',
    'Invoke-MemoryOptimization',
    'Invoke-CleanupAction',
    'Export-GuardianState',
    'Start-MonitoringLoop',
    'Get-MemoryInfo',
    'Get-TopMemoryProcesses',
    'Invoke-MemoryAnalysis',
    'Update-State',
    'Test-AlertCooldown',
    'Set-AlertCooldown'
)
