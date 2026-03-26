# Logger Module - Logging System
# Provides structured logging with multiple output destinations

# Configuration
$script:LogFile = $null
$script:LogLevel = "INFO"  # DEBUG, INFO, WARN, ERROR
$script:LogToConsole = $true
$script:LogToFile = $false
$script:MaxLogFileSizeMB = 10
$script:MaxLogFiles = 5

# Log level priorities
$script:LogLevelPriority = @{
    'DEBUG' = 0
    'INFO' = 1
    'WARN' = 2
    'ERROR' = 3
}

<#
.SYNOPSIS
    Initialize logger with configuration
.DESCRIPTION
    Configure logging destinations, log level, and file settings
#>
function Initialize-Logger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$LogFile,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$LogLevel = 'INFO',
        
        [Parameter(Mandatory=$false)]
        [bool]$LogToConsole = $true,
        
        [Parameter(Mandatory=$false)]
        [bool]$LogToFile = $false,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxLogFileSizeMB = 10,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxLogFiles = 5
    )
    
    $script:LogLevel = $LogLevel
    $script:LogToConsole = $LogToConsole
    $script:LogToFile = $LogToFile
    $script:MaxLogFileSizeMB = $MaxLogFileSizeMB
    $script:MaxLogFiles = $MaxLogFiles
    
    if ($LogFile) {
        $script:LogFile = $LogFile
        $script:LogToFile = $true
    }
    
    Write-Log "INFO" "Logger initialized. Level: $LogLevel, Console: $LogToConsole, File: $LogToFile"
}

<#
.SYNOPSIS
    Write log message
.DESCRIPTION
    Logs a message with specified level to configured destinations
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [object]$Data
    )
    
    # Check log level
    $messagePriority = $script:LogLevelPriority[$Level]
    $configuredPriority = $script:LogLevelPriority[$script:LogLevel]
    
    if ($messagePriority -lt $configuredPriority) {
        return  # Skip if level is too low
    }
    
    # Format message
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $formattedMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    if ($script:LogToConsole) {
        $color = switch ($Level) {
            'DEBUG' { 'Gray' }
            'INFO' { 'Green' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            default { 'White' }
        }
        
        Write-Host $formattedMessage -ForegroundColor $color
        
        if ($Data) {
            Write-Host $Data -ForegroundColor $color
        }
    }
    
    # File output
    if ($script:LogToFile -and $script:LogFile) {
        try {
            # Check log file size and rotate if needed
            Test-LogRotation
            
            # Write to file
            Add-Content -Path $script:LogFile -Value $formattedMessage -Encoding UTF8
            
            if ($Data) {
                Add-Content -Path $script:LogFile -Value $Data -Encoding UTF8
            }
        } catch {
            Write-Host "Failed to write to log file: $_" -ForegroundColor Red
        }
    }
}

<#
.SYNOPSIS
    Write debug log
.DESCRIPTION
    Convenience function for DEBUG level messages
#>
function Write-LogDebug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [object]$Data
    )
    
    Write-Log -Level 'DEBUG' -Message $Message -Data $Data
}

<#
.SYNOPSIS
    Write info log
.DESCRIPTION
    Convenience function for INFO level messages
#>
function Write-LogInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [object]$Data
    )
    
    Write-Log -Level 'INFO' -Message $Message -Data $Data
}

<#
.SYNOPSIS
    Write warning log
.DESCRIPTION
    Convenience function for WARN level messages
#>
function Write-LogWarn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [object]$Data
    )
    
    Write-Log -Level 'WARN' -Message $Message -Data $Data
}

<#
.SYNOPSIS
    Write error log
.DESCRIPTION
    Convenience function for ERROR level messages
#>
function Write-LogError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [object]$Data
    )
    
    Write-Log -Level 'ERROR' -Message $Message -Data $Data
}

<#
.SYNOPSIS
    Test and perform log rotation if needed
.DESCRIPTION
    Checks log file size and rotates if exceeding maximum
#>
function Test-LogRotation {
    [CmdletBinding()]
    param()
    
    if (-not (Test-Path $script:LogFile)) {
        return
    }
    
    try {
        $file = Get-Item $script:LogFile
        $sizeMB = $file.Length / 1MB
        
        if ($sizeMB -ge $script:MaxLogFileSizeMB) {
            Write-Log "INFO" "Log file size ($($sizeMB.ToString('F2')) MB) exceeds maximum ($($script:MaxLogFileSizeMB) MB). Rotating..."
            
            # Rotate existing logs
            for ($i = $script:MaxLogFiles - 1; $i -ge 1; $i--) {
                $oldFile = "$($script:LogFile).$i"
                $newFile = "$($script:LogFile).$($i + 1)"
                
                if (Test-Path $oldFile) {
                    if ($i -eq ($script:MaxLogFiles - 1)) {
                        # Remove oldest
                        Remove-Item $oldFile -Force
                    } else {
                        # Rename to next number
                        Move-Item $oldFile $newFile -Force
                    }
                }
            }
            
            # Rename current log to .1
            Move-Item $script:LogFile "$($script:LogFile).1" -Force
            
            Write-Log "INFO" "Log rotation completed"
        }
    } catch {
        Write-Host "Failed to rotate log file: $_" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Get log entries
.DESCRIPTION
    Reads and returns log entries matching specified criteria
#>
function Get-LogEntries {
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level,
        
        [Parameter(Mandatory=$false)]
        [DateTime]$StartTime,
        
        [Parameter(Mandatory=$false)]
        [DateTime]$EndTime,
        
        [Parameter(Mandatory=$false)]
        [int]$LastN = 0  # 0 = all
    )
    
    if (-not (Test-Path $script:LogFile)) {
        return @()
    }
    
    try {
        $entries = Get-Content $script:LogFile -Encoding UTF8
        
        # Parse log entries
        $parsedEntries = @()
        foreach ($entry in $entries) {
            if ($entry -match '\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] \[(DEBUG|INFO|WARN|ERROR)\] (.+)') {
                $timestamp = [DateTime]::ParseExact($matches[1], 'yyyy-MM-dd HH:mm:ss', $null)
                $entryLevel = $matches[2]
                $message = $matches[3]
                
                $parsedEntries += [PSCustomObject]@{
                    Timestamp = $timestamp
                    Level = $entryLevel
                    Message = $message
                }
            }
        }
        
        # Filter by level
        if ($Level) {
            $parsedEntries = $parsedEntries | Where-Object { $_.Level -eq $Level }
        }
        
        # Filter by time range
        if ($StartTime) {
            $parsedEntries = $parsedEntries | Where-Object { $_.Timestamp -ge $StartTime }
        }
        
        if ($EndTime) {
            $parsedEntries = $parsedEntries | Where-Object { $_.Timestamp -le $EndTime }
        }
        
        # Limit results
        if ($LastN -gt 0) {
            $parsedEntries = $parsedEntries | Select-Object -Last $LastN
        }
        
        return $parsedEntries
        
    } catch {
        Write-Log "ERROR" "Failed to read log entries: $_"
        return @()
    }
}

<#
.SYNOPSIS
    Clear log file
.DESCRIPTION
    Clears all content from the log file
#>
function Clear-LogFile {
    [CmdletBinding()]
    param()
    
    if (Test-Path $script:LogFile) {
        Clear-Content $script:LogFile -Force
        Write-Log "INFO" "Log file cleared"
    }
}

<#
.SYNOPSIS
    Set log file path
.DESCRIPTION
    Updates the log file path and enables file logging
#>
function Set-LogFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $script:LogFile = $Path
    $script:LogToFile = $true
    
    # Ensure directory exists
    $directory = Split-Path $Path -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    
    Write-Log "INFO" "Log file path set to: $Path"
}

<#
.SYNOPSIS
    Set log level
.DESCRIPTION
    Updates the minimum log level
#>
function Set-LogLevel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level
    )
    
    $script:LogLevel = $Level
    Write-Log "INFO" "Log level set to: $Level"
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-Logger',
    'Write-Log',
    'Write-LogDebug',
    'Write-LogInfo',
    'Write-LogWarn',
    'Write-LogError',
    'Get-LogEntries',
    'Clear-LogFile',
    'Set-LogFilePath',
    'Set-LogLevel'
)
