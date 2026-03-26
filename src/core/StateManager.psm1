# State Management Module - Thread-safe state manager
# Maintains global state, manages history data, supports concurrent access

using namespace System.Collections.Concurrent

<#
.SYNOPSIS
    Initialize state manager
.DESCRIPTION
    Creates thread-safe data structures for monitoring state and history
#>
function Initialize-StateManager {
    [CmdletBinding()]
    param(
        [int]$HistoryRetentionHours = 168  # Default: 7 days
    )
    
    # Create thread-safe storage structures
    $script:State = [System.Collections.Concurrent.ConcurrentDictionary[string,object]]::new()
    
    # Initialize monitoring state
    $script:State['Round'] = 0
    $script:State['LastCheck'] = $null
    $script:State['MemPct'] = 0
    $script:State['MemUsedGB'] = 0.0
    $script:State['MemFreeGB'] = 0.0
    $script:State['MemTotalGB'] = 0.0
    $script:State['TopProcs'] = @()
    $script:State['Findings'] = @()
    $script:State['RiskScore'] = 0
    $script:State['AlertsTriggered'] = @()
    
    # History data (circular buffer)
    $script:State['History'] = [System.Collections.Generic.List[object]]::new()
    $script:State['ProcessHistory'] = [System.Collections.Concurrent.ConcurrentDictionary[int,object]]::new()
    
    # Alert cooldown dictionary
    $script:State['AlertCooldown'] = [System.Collections.Concurrent.ConcurrentDictionary[string,DateTime]]::new()
    
    # Configuration
    $script:HistoryRetentionHours = $HistoryRetentionHours
    $script:MaxHistorySize = 720  # 5-minute intervals, 2.5 days
    
    Write-Log "INFO" "State manager initialized. Retention: $HistoryRetentionHours hours"
}

<#
.SYNOPSIS
    Update current monitoring state
.DESCRIPTION
    Updates the current round of monitoring data
#>
function Update-State {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [double]$MemPct,
        
        [Parameter(Mandatory=$true)]
        [double]$MemUsedGB,
        
        [Parameter(Mandatory=$true)]
        [double]$MemFreeGB,
        
        [Parameter(Mandatory=$true)]
        [double]$MemTotalGB,
        
        [Parameter(Mandatory=$true)]
        [array]$TopProcs,
        
        [Parameter(Mandatory=$false)]
        [array]$Findings = @(),
        
        [Parameter(Mandatory=$false)]
        [int]$RiskScore = 0
    )
    
    $round = $script:State['Round'] + 1
    $timestamp = Get-Date
    
    $script:State['Round'] = $round
    $script:State['LastCheck'] = $timestamp
    $script:State['MemPct'] = $MemPct
    $script:State['MemUsedGB'] = $MemUsedGB
    $script:State['MemFreeGB'] = $MemFreeGB
    $script:State['MemTotalGB'] = $MemTotalGB
    $script:State['TopProcs'] = $TopProcs
    $script:State['Findings'] = $Findings
    $script:State['RiskScore'] = $RiskScore
    
    # Add to history
    $historyEntry = [PSCustomObject]@{
        Round = $round
        Timestamp = $timestamp
        MemPct = $MemPct
        MemUsedGB = $MemUsedGB
        MemFreeGB = $MemFreeGB
        MemTotalGB = $MemTotalGB
        RiskScore = $RiskScore
        FindingsCount = $Findings.Count
    }
    
    $script:State['History'].Add($historyEntry)
    
    # Trim history if exceeding max size
    while ($script:State['History'].Count -gt $script:MaxHistorySize) {
        $script:State['History'].RemoveAt(0)
    }
    
    # Update process history
    foreach ($proc in $TopProcs) {
        if (-not $script:State['ProcessHistory'].ContainsKey($proc.Id)) {
            $script:State['ProcessHistory'][$proc.Id] = [System.Collections.Generic.List[PSCustomObject]]::new()
        }
        
        $procHistory = [PSCustomObject]@{
            Round = $round
            Timestamp = $timestamp
            ProcessName = $proc.ProcessName
            Id = $proc.Id
            WorkingSet64 = $proc.WorkingSet64
            PrivateMemorySize64 = $proc.PrivateMemorySize64
        }
        
        $script:State['ProcessHistory'][$proc.Id].Add($procHistory)
        
        # Trim process history (keep last 100 entries)
        if ($script:State['ProcessHistory'][$proc.Id].Count -gt 100) {
            $script:State['ProcessHistory'][$proc.Id].RemoveAt(0)
        }
    }
    
    Write-Log "DEBUG" "State updated: Round=$round, MemPct=$($MemPct.ToString('F1'))%"
}

<#
.SYNOPSIS
    Get current monitoring state
.DESCRIPTION
    Returns the current state as a hashtable
#>
function Get-State {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    $result = @{}
    
    foreach ($key in $script:State.Keys) {
        $result[$key] = $script:State[$key]
    }
    
    return $result
}

<#
.SYNOPSIS
    Get historical data
.DESCRIPTION
    Returns monitoring history within specified time range
#>
function Get-History {
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory=$false)]
        [int]$LastMinutes = 60,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxPoints = 0  # 0 = no limit
    )
    
    $cutoff = (Get-Date).AddMinutes(-$LastMinutes)
    $history = $script:State['History'] | Where-Object { $_.Timestamp -ge $cutoff }
    
    if ($MaxPoints -gt 0 -and $history.Count -gt $MaxPoints) {
        # Sample evenly
        $step = [Math]::Floor($history.Count / $MaxPoints)
        $result = @()
        for ($i = 0; $i -lt $history.Count; $i += $step) {
            $result += $history[$i]
        }
        return $result
    }
    
    return $history
}

<#
.SYNOPSIS
    Get process history
.DESCRIPTION
    Returns historical data for specific process
#>
function Get-ProcessHistory {
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory=$true)]
        [int]$ProcessId,
        
        [Parameter(Mandatory=$false)]
        [int]$LastMinutes = 60
    )
    
    if (-not $script:State['ProcessHistory'].ContainsKey($ProcessId)) {
        return @()
    }
    
    $cutoff = (Get-Date).AddMinutes(-$LastMinutes)
    return $script:State['ProcessHistory'][$ProcessId] | 
           Where-Object { $_.Timestamp -ge $cutoff }
}

<#
.SYNOPSIS
    Check if process is in alert cooldown
.DESCRIPTION
    Returns true if process is within cooldown period
#>
function Test-AlertCooldown {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProcessKey,
        
        [Parameter(Mandatory=$false)]
        [int]$CooldownMinutes = 60
    )
    
    if ($script:State['AlertCooldown'].ContainsKey($ProcessKey)) {
        $lastAlert = $script:State['AlertCooldown'][$ProcessKey]
        $timeSinceAlert = ((Get-Date) - $lastAlert).TotalMinutes
        
        if ($timeSinceAlert -lt $CooldownMinutes) {
            return $true
        } else {
            # Expired, remove from cooldown
            $null = $script:State['AlertCooldown'].Remove($ProcessKey)
        }
    }
    
    return $false
}

<#
.SYNOPSIS
    Set alert cooldown for process
.DESCRIPTION
    Records alert timestamp for cooldown tracking
#>
function Set-AlertCooldown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProcessKey
    )
    
    $script:State['AlertCooldown'][$ProcessKey] = Get-Date
}

<#
.SYNOPSIS
    Get statistics summary
.DESCRIPTION
    Returns summary statistics for monitoring period
#>
function Get-StatisticsSummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$false)]
        [int]$LastMinutes = 60
    )
    
    $history = Get-History -LastMinutes $LastMinutes
    
    if ($history.Count -eq 0) {
        return [PSCustomObject]@{
            PeriodMinutes = $LastMinutes
            Samples = 0
            AvgMemPct = 0
            MaxMemPct = 0
            MinMemPct = 0
            AvgMemUsedGB = 0
            AvgMemFreeGB = 0
            TotalAlerts = 0
            AvgRiskScore = 0
        }
    }
    
    $avgMemPct = ($history | Measure-Object -Property MemPct -Average).Average
    $maxMemPct = ($history | Measure-Object -Property MemPct -Maximum).Maximum
    $minMemPct = ($history | Measure-Object -Property MemPct -Minimum).Minimum
    $avgMemUsedGB = ($history | Measure-Object -Property MemUsedGB -Average).Average
    $avgMemFreeGB = ($history | Measure-Object -Property MemFreeGB -Average).Average
    $totalAlerts = ($history | Where-Object { $_.FindingsCount -gt 0 }).Count
    $avgRiskScore = ($history | Measure-Object -Property RiskScore -Average).Average
    
    return [PSCustomObject]@{
        PeriodMinutes = $LastMinutes
        Samples = $history.Count
        AvgMemPct = [Math]::Round($avgMemPct, 1)
        MaxMemPct = [Math]::Round($maxMemPct, 1)
        MinMemPct = [Math]::Round($minMemPct, 1)
        AvgMemUsedGB = [Math]::Round($avgMemUsedGB, 2)
        AvgMemFreeGB = [Math]::Round($avgMemFreeGB, 2)
        TotalAlerts = $totalAlerts
        AvgRiskScore = [Math]::Round($avgRiskScore, 0)
    }
}

<#
.SYNOPSIS
    Cleanup old state data
.DESCRIPTION
    Removes historical data older than retention period
#>
function Invoke-StateCleanup {
    [CmdletBinding()]
    param()
    
    $cutoff = (Get-Date).AddHours(-$script:HistoryRetentionHours)
    
    # Remove old history entries
    $oldEntries = $script:State['History'] | Where-Object { $_.Timestamp -lt $cutoff }
    
    foreach ($entry in $oldEntries) {
        $script:State['History'].Remove($entry)
    }
    
    # Clean up old process history
    foreach ($processId in $script:State['ProcessHistory'].Keys) {
        $procHistory = $script:State['ProcessHistory'][$processId]
        
        for ($i = $procHistory.Count - 1; $i -ge 0; $i--) {
            if ($procHistory[$i].Timestamp -lt $cutoff) {
                $procHistory.RemoveAt($i)
            }
        }
    }
    
    # Clean up expired cooldowns
    $expiredCooldowns = @()
    foreach ($key in $script:State['AlertCooldown'].Keys) {
        $lastAlert = $script:State['AlertCooldown'][$key]
        if (((Get-Date) - $lastAlert).TotalHours -gt 24) {
            $expiredCooldowns += $key
        }
    }
    
    foreach ($key in $expiredCooldowns) {
        $null = $script:State['AlertCooldown'].Remove($key)
    }
    
    Write-Log "INFO" "State cleanup completed. Removed $($oldEntries.Count) history entries"
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-StateManager',
    'Update-State',
    'Get-State',
    'Get-History',
    'Get-ProcessHistory',
    'Test-AlertCooldown',
    'Set-AlertCooldown',
    'Get-StatisticsSummary',
    'Invoke-StateCleanup'
)
