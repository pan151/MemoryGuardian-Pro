# Executor Module - Command Execution Engine
# Executes memory optimization commands with safety mechanisms

<#
.SYNOPSIS
    Initialize executor with configuration
.DESCRIPTION
    Loads settings and configures command execution parameters
#>
function Initialize-Executor {
    [CmdletBinding()]
    param()
    
    # Load settings from parent scope
    if (-not $script:Settings) {
        # Settings should be loaded by MemoryMonitor module
        $script:Settings = @{}
    }
    
    # Initialize whitelist
    $script:CommandWhitelist = @(
        'EmptyWorkingSet'
        'Clear-ProcessMemory'
        'Clean-SystemMemory'
        'Optimize-WorkingSet'
        'DefragmentMemory'
    )
    
    # Initialize execution statistics
    $script:ExecutionStats = @{
        TotalCommands = 0
        SuccessfulCommands = 0
        FailedCommands = 0
        BytesFreed = 0
        LastExecution = $null
        ExecutionHistory = [System.Collections.Generic.List[PSCustomObject]]::new()
    }
    
    Write-Log "INFO" "Executor initialized"
}

<#
.SYNOPSIS
    Execute memory optimization command
.DESCRIPTION
    Safely executes predefined commands with validation and logging
#>
function Invoke-OptimizationCommand {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter(Mandatory=$false)]
        [int]$ProcessId = 0,
        
        [Parameter(Mandatory=$false)]
        [switch]$DryRun
    )
    
    # Validate command against whitelist
    if (-not (Test-WhitelistedCommand -Command $Command)) {
        $errorMsg = "Command '$Command' is not in whitelist. Execution denied for security reasons."
        Write-Log "ERROR" $errorMsg
        throw $errorMsg
    }
    
    # Update statistics
    $script:ExecutionStats.TotalCommands++
    
    # Log execution attempt
    $logEntry = [PSCustomObject]@{
        Timestamp = Get-Date
        Command = $Command
        ProcessId = $ProcessId
        DryRun = $DryRun.IsPresent
        Success = $false
        BytesFreed = 0
        Error = $null
    }
    
    try {
        if ($DryRun.IsPresent) {
            Write-Log "INFO" "DRY-RUN: Would execute command '$Command' for process $ProcessId"
            $logEntry.Success = $true
        } elseif ($PSCmdlet.ShouldProcess("Process ID $ProcessId", "Execute command '$Command'")) {
            Write-Log "INFO" "Executing command '$Command' for process $ProcessId"
            
            # Execute based on command type
            $bytesFreed = switch ($Command) {
                'EmptyWorkingSet' {
                    if ($ProcessId -gt 0) {
                        Invoke-EmptyWorkingSet -ProcessId $ProcessId
                    } else {
                        Invoke-EmptyWorkingSetAll
                    }
                }
                'Clear-ProcessMemory' {
                    if ($ProcessId -gt 0) {
                        Invoke-ClearProcessMemory -ProcessId $ProcessId
                    } else {
                        throw "Process ID required for Clear-ProcessMemory"
                    }
                }
                'Clean-SystemMemory' {
                    Invoke-CleanSystemMemory
                }
                'Optimize-WorkingSet' {
                    Invoke-OptimizeWorkingSet
                }
                'DefragmentMemory' {
                    Invoke-DefragmentMemory
                }
                default {
                    throw "Unknown command: $Command"
                }
            }
            
            $logEntry.Success = $true
            $logEntry.BytesFreed = $bytesFreed
            $script:ExecutionStats.BytesFreed += $bytesFreed
            $script:ExecutionStats.SuccessfulCommands++
            $script:ExecutionStats.LastExecution = Get-Date
            
            Write-Log "INFO" "Command '$Command' completed successfully. Freed: $($bytesFreed / 1MB) MB"
        }
    } catch {
        $errorMsg = "Failed to execute command '$Command': $_"
        Write-Log "ERROR" $errorMsg
        $logEntry.Error = $_.Exception.Message
        $script:ExecutionStats.FailedCommands++
        throw
    } finally {
        # Add to execution history
        $script:ExecutionStats.ExecutionHistory.Add($logEntry)
        
        # Trim history (keep last 100 entries)
        if ($script:ExecutionStats.ExecutionHistory.Count -gt 100) {
            $script:ExecutionStats.ExecutionHistory.RemoveAt(0)
        }
    }
}

<#
.SYNOPSIS
    Test if command is whitelisted
.DESCRIPTION
    Validates command against security whitelist
#>
function Test-WhitelistedCommand {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    return $script:CommandWhitelist -contains $Command
}

<#
.SYNOPSIS
    Empty working set for specific process
.DESCRIPTION
    Uses Windows API to trim working set of a process
#>
function Invoke-EmptyWorkingSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$ProcessId
    )
    
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        
        # Get current working set before
        $workingSetBefore = $process.WorkingSet64
        
        # Use .NET to empty working set
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class MemoryApi {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
'@
        
        $success = [MemoryApi]::EmptyWorkingSet($process.Handle)
        
        if (-not $success) {
            throw "Failed to empty working set"
        }
        
        # Refresh process to get new working set
        $process.Refresh()
        $workingSetAfter = $process.WorkingSet64
        
        $bytesFreed = $workingSetBefore - $workingSetAfter
        
        Write-Log "INFO" "Emptied working set for process $($process.ProcessName) (PID: $ProcessId). Freed: $($bytesFreed / 1MB) MB"
        
        return [Math]::Max(0, $bytesFreed)
        
    } catch {
        $ex = $_.Exception.Message
        Write-Log "ERROR" "Failed to empty working set for PID $ProcessId - ${ex}"
        throw
    }
}

<#
.SYNOPSIS
    Empty working set for all processes
.DESCRIPTION
    Trims working sets of all processes (safe operation)
#>
function Invoke-EmptyWorkingSetAll {
    [CmdletBinding()]
    param()
    
    Write-Log "INFO" "Emptying working sets for all processes..."
    
    $totalFreed = 0
    $processed = 0
    $failed = 0
    
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class MemoryApi {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
'@
        
        $processes = Get-Process
        
        foreach ($process in $processes) {
            try {
                if ($process.Id -eq $PID) {
                    continue  # Skip current process
                }
                
                $workingSetBefore = $process.WorkingSet64
                
                $success = [MemoryApi]::EmptyWorkingSet($process.Handle)
                
                if ($success) {
                    $process.Refresh()
                    $workingSetAfter = $process.WorkingSet64
                    $freed = $workingSetBefore - $workingSetAfter
                    $totalFreed += [Math]::Max(0, $freed)
                    $processed++
                } else {
                    $failed++
                }
            } catch {
                $failed++
            }
        }
        
        Write-Log "INFO" "Completed emptying working sets. Processed: $processed, Failed: $failed, Total freed: $($totalFreed / 1MB) MB"
        
        return $totalFreed
        
    } catch {
        Write-Log "ERROR" "Failed to empty working sets for all processes: $_"
        throw
    }
}

<#
.SYNOPSIS
    Clear process memory
.DESCRIPTION
    Force garbage collection and trim memory for specific process
#>
function Invoke-ClearProcessMemory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$ProcessId
    )
    
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        $workingSetBefore = $process.WorkingSet64
        
        # Empty working set
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class MemoryApi {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
'@
        
        [MemoryApi]::EmptyWorkingSet($process.Handle)
        
        # Refresh
        $process.Refresh()
        $workingSetAfter = $process.WorkingSet64
        
        $bytesFreed = $workingSetBefore - $workingSetAfter
        
        Write-Log "INFO" "Cleared memory for process $($process.ProcessName) (PID: $ProcessId). Freed: $($bytesFreed / 1MB) MB"
        
        return [Math]::Max(0, $bytesFreed)
        
    } catch {
        $ex = $_.Exception.Message
        Write-Log "ERROR" "Failed to clear memory for PID $ProcessId - ${ex}"
        throw
    }
}

<#
.SYNOPSIS
    Clean system memory
.DESCRIPTION
    Performs system-wide memory cleanup operations
#>
function Invoke-CleanSystemMemory {
    [CmdletBinding()]
    param()
    
    Write-Log "INFO" "Cleaning system memory..."
    
    $totalFreed = 0
    
    try {
        # 1. Empty working sets for all processes
        $totalFreed += Invoke-EmptyWorkingSetAll
        
        # 2. Call .NET garbage collection
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        Write-Log "INFO" "System memory cleanup completed. Total freed: $($totalFreed / 1MB) MB"
        
        return $totalFreed
        
    } catch {
        Write-Log "ERROR" "Failed to clean system memory: $_"
        throw
    }
}

<#
.SYNOPSIS
    Optimize working set
.DESCRIPTION
    Aggressively trims working sets to free memory
#>
function Invoke-OptimizeWorkingSet {
    [CmdletBinding()]
    param()
    
    Write-Log "INFO" "Optimizing working sets..."
    
    return Invoke-EmptyWorkingSetAll
}

<#
.SYNOPSIS
    Defragment memory
.DESCRIPTION
    Requests system memory defragmentation
#>
function Invoke-DefragmentMemory {
    [CmdletBinding()]
    param()
    
    Write-Log "INFO" "Defragmenting memory..."
    
    # Windows doesn't expose a public API for memory defragmentation
    # This is a placeholder that logs the intent
    Write-Log "WARN" "Memory defragmentation is not directly supported via public APIs. Working set optimization performed instead."
    
    return Invoke-EmptyWorkingSetAll
}

<#
.SYNOPSIS
    Get execution statistics
.DESCRIPTION
    Returns statistics about command executions
#>
function Get-ExecutionStats {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    $history = $script:ExecutionStats.ExecutionHistory | 
               Sort-Object -Property Timestamp -Descending | 
               Select-Object -First 10
    
    return [PSCustomObject]@{
        TotalCommands = $script:ExecutionStats.TotalCommands
        SuccessfulCommands = $script:ExecutionStats.SuccessfulCommands
        FailedCommands = $script:ExecutionStats.FailedCommands
        SuccessRate = if ($script:ExecutionStats.TotalCommands -gt 0) {
            [Math]::Round(($script:ExecutionStats.SuccessfulCommands / $script:ExecutionStats.TotalCommands) * 100, 1)
        } else {
            0
        }
        BytesFreed = $script:ExecutionStats.BytesFreed
        LastExecution = $script:ExecutionStats.LastExecution
        RecentExecutions = $history
    }
}

<#
.SYNOPSIS
    Reset execution statistics
.DESCRIPTION
    Clears all execution statistics and history
#>
function Reset-ExecutionStats {
    [CmdletBinding()]
    param()
    
    $script:ExecutionStats = @{
        TotalCommands = 0
        SuccessfulCommands = 0
        FailedCommands = 0
        BytesFreed = 0
        LastExecution = $null
        ExecutionHistory = [System.Collections.Generic.List[PSCustomObject]]::new()
    }
    
    Write-Log "INFO" "Execution statistics reset"
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-Executor',
    'Invoke-OptimizationCommand',
    'Test-WhitelistedCommand',
    'Invoke-EmptyWorkingSet',
    'Invoke-EmptyWorkingSetAll',
    'Invoke-ClearProcessMemory',
    'Invoke-CleanSystemMemory',
    'Invoke-OptimizeWorkingSet',
    'Invoke-DefragmentMemory',
    'Get-ExecutionStats',
    'Reset-ExecutionStats'
)
