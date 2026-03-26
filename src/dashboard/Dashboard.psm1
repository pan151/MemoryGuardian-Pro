# ============================================================
# Dashboard.psm1 - Web Dashboard Server
# ============================================================

$script:DashboardServer = $null
$script:DashboardRunspace = $null

# ============================================================
# Start HTTP Dashboard Server
# ============================================================
function Start-DashboardServer {
    param(
        [string]$HtmlPath,
        [string]$DataPath,
        [int]$Port = 19527,
        [switch]$AutoOpen
    )

    # Read Dashboard HTML
    if (-not (Test-Path $HtmlPath)) {
        Write-Host "[WARN] Dashboard HTML file not found: $HtmlPath" -ForegroundColor Yellow
        return
    }

    $dashboardHtml = [System.IO.File]::ReadAllText($HtmlPath, [System.Text.Encoding]::UTF8)

    # Run in separate Runspace
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "MTA"
    $runspace.Open()

    $psCmd = [powershell]::Create()
    $psCmd.Runspace = $runspace

    $null = $psCmd.AddScript({
        param($html, $dataFile, $port)

        $ErrorActionPreference = "SilentlyContinue"
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:${port}/")

        try {
            $listener.Start()
            Write-Host "[OK] Dashboard started successfully: http://localhost:${port}" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Dashboard failed to start: Port $port might be in use" -ForegroundColor Red
            return
        }

        while ($listener.IsListening) {
            try {
                $ctx = $listener.GetContext()
                $req = $ctx.Request
                $resp = $ctx.Response
                $urlPath = $req.Url.AbsolutePath

                # Handle CORS
                $resp.AddHeader("Access-Control-Allow-Origin", "*")
                $resp.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
                $resp.AddHeader("Access-Control-Allow-Headers", "Content-Type")

                # OPTIONS preflight request
                if ($req.HttpMethod -eq "OPTIONS") {
                    $resp.StatusCode = 200
                    $resp.OutputStream.Close()
                    continue
                }

                if ($urlPath -eq "/data") {
                    # Return real-time JSON data
                    if (Test-Path $dataFile) {
                        $body = [System.IO.File]::ReadAllBytes($dataFile)
                        $resp.ContentType = "application/json; charset=utf-8"
                        $resp.ContentLength64 = $body.Length
                        $resp.OutputStream.Write($body, 0, $body.Length)
                    } else {
                        $respBody = [System.Text.Encoding]::UTF8.GetBytes('{"error":"no data"}')
                        $resp.ContentType = "application/json"
                        $resp.ContentLength64 = $respBody.Length
                        $resp.OutputStream.Write($respBody, 0, $respBody.Length)
                    }
                }
                elseif ($urlPath -eq "/action" -and $req.HttpMethod -eq "POST") {
                    # Execute cleanup command
                    $reader = New-Object System.IO.StreamReader($req.InputStream)
                    $body = $reader.ReadToEnd()
                    $reader.Close()
                    $parsed = $body | ConvertFrom-Json
                    $cmdStr = $parsed.cmd

                    # Security filter
                    $allowed = $cmdStr -match '^(taskkill|net stop|Stop-Process)'
                    if ($allowed) {
                        $result = cmd /c $cmdStr 2>&1
                        $ts = [datetime]::Now.ToString("yyyy-MM-dd HH:mm:ss")

                        # Log to file
                        $logFile = "C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\logs\memory_guardian_{0:yyyyMMdd}.log" -f [datetime]::Now
                        Add-Content $logFile "[$ts][DASHBOARD_ACTION] $cmdStr" -Encoding UTF8 -ErrorAction SilentlyContinue

                        $respBody = [System.Text.Encoding]::UTF8.GetBytes((@{ok=$true; output="$result"} | ConvertTo-Json))
                    } else {
                        $respBody = [System.Text.Encoding]::UTF8.GetBytes((@{ok=$false; output="Command blocked by security filter"} | ConvertTo-Json))
                    }

                    $resp.ContentType = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $respBody.Length
                    $resp.OutputStream.Write($respBody, 0, $respBody.Length)
                }
                elseif ($urlPath -eq "/release") {
                    # Execute EmptyWorkingSet
                    Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class MemOptHttp { [DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr h); }
"@ -ErrorAction SilentlyContinue

                    $freed = 0
                    Get-Process | Where-Object {$_.WorkingSet64 -gt 100MB} | ForEach-Object {
                        try {
                            $b=$_.WorkingSet64
                            [MemOptHttp]::EmptyWorkingSet($_.Handle) | Out-Null
                            $_.Refresh()
                            $freed+=($b-$_.WorkingSet64)
                        } catch {}
                    }

                    $freedMB = [math]::Round($freed/1MB, 1)
                    $respBody = [System.Text.Encoding]::UTF8.GetBytes((@{ok=$true; freed=$freedMB} | ConvertTo-Json))

                    $resp.ContentType = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $respBody.Length
                    $resp.OutputStream.Write($respBody, 0, $respBody.Length)
                }
                elseif ($urlPath -eq "/optimize") {
                    # Execute full optimization process
                    Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class MemOptFull {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr h);
}
"@ -ErrorAction SilentlyContinue

                    # Clean temp files
                    $tempSizeBefore = 0
                    $tempDirs = @($env:TEMP, $env:TMP, "C:\Windows\Temp")
                    foreach ($dir in $tempDirs) {
                        if (Test-Path $dir) {
                            $tempSizeBefore += (Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                        }
                    }

                    # Release working set
                    $freedMem = 0
                    Get-Process | Where-Object {$_.WorkingSet64 -gt 50MB} | ForEach-Object {
                        try {
                            $b = $_.WorkingSet64
                            [MemOptFull]::EmptyWorkingSet($_.Handle) | Out-Null
                            $_.Refresh()
                            $freedMem += ($b - $_.WorkingSet64)
                        } catch {}
                    }

                    # Clean temp files
                    foreach ($dir in $tempDirs) {
                        if (Test-Path $dir) {
                            Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue |
                                Where-Object { -not $_.PSIsContainer } |
                                Remove-Item -Force -ErrorAction SilentlyContinue
                        }
                    }

                    # Clear DNS cache
                    Clear-DnsClientCache -ErrorAction SilentlyContinue

                    $freedMB = [math]::Round($freedMem/1MB, 1)
                    $respBody = [System.Text.Encoding]::UTF8.GetBytes((@{
                        ok = $true
                        freedMB = $freedMB
                        tempFreed = [math]::Round($tempSizeBefore/1MB, 1)
                        actions = @("Release working set", "Clean temp files", "Clear DNS cache")
                    } | ConvertTo-Json))

                    $resp.ContentType = "application/json; charset=utf-8"
                    $resp.ContentLength64 = $respBody.Length
                    $resp.OutputStream.Write($respBody, 0, $respBody.Length)
                }
                else {
                    # Return Dashboard HTML
                    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($html)
                    $resp.ContentType = "text/html; charset=utf-8"
                    $resp.ContentLength64 = $bodyBytes.Length
                    $resp.OutputStream.Write($bodyBytes, 0, $bodyBytes.Length)
                }

                $resp.OutputStream.Close()
            } catch {
                Write-Host "[ERROR] Dashboard request handling failed: $_" -ForegroundColor Red
            }
        }
    }).AddParameters(@{
        html = $dashboardHtml
        dataFile = $dataPath
        port = $port
    }) | Out-Null

    # Save references
    $script:DashboardServer = $psCmd
    $script:DashboardRunspace = $runspace

    # Start
    $script:DashboardServer.BeginInvoke() | Out-Null

    # Auto open browser
    if ($AutoOpen) {
        Start-Sleep -Milliseconds 800
        try {
            Start-Process "http://localhost:${port}"
        } catch {
            Write-Host "[WARN] Cannot auto open browser, please visit manually: http://localhost:${port}" -ForegroundColor Yellow
        }
    }
}

# ============================================================
# Stop Dashboard Server
# ============================================================
function Stop-DashboardServer {
    if ($script:DashboardServer) {
        try {
            $script:DashboardServer.Stop()
            $script:DashboardServer.Dispose()
            $script:DashboardRunspace.Close()
            $script:DashboardRunspace.Dispose()
        } catch {
            Write-Host "[WARN] Error stopping Dashboard: $_" -ForegroundColor Yellow
        }
        $script:DashboardServer = $null
        $script:DashboardRunspace = $null
        Write-Host "[OK] Dashboard stopped" -ForegroundColor Green
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Start-DashboardServer',
    'Stop-DashboardServer'
)

# Create aliases for backward compatibility
New-Alias -Name Start-Dashboard -Value Start-DashboardServer -Scope Script
New-Alias -Name Stop-Dashboard -Value Stop-DashboardServer -Scope Script

# Export aliases
Export-ModuleMember -Alias @(
    'Start-Dashboard',
    'Stop-Dashboard'
)
