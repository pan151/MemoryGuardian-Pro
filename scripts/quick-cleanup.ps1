# ============================================================
# quick-cleanup.ps1 - 快速清理脚本
# ============================================================

param(
    [switch]$WhatIf,
    [switch]$Force
)

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              Memory Guardian Pro - 快速清理工具                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "[INFO] 预演模式 - 不会实际执行任何操作" -ForegroundColor Yellow
    Write-Host ""
}

# 获取清理前内存状态
$os = Get-CimInstance Win32_OperatingSystem
$beforeTotal = [math]::Round($os.TotalVisibleMemorySize/1MB, 2)
$beforeFree = [math]::Round($os.FreePhysicalMemory/1MB, 2)
$beforeUsed = $beforeTotal - $beforeFree
$beforePct = [math]::Round($beforeUsed/$beforeTotal*100, 1)

Write-Host "清理前内存状态:" -ForegroundColor Gray
Write-Host "  总计: ${beforeTotal} GB  已用: ${beforeUsed} GB  可用: ${beforeFree} GB  使用率: ${beforePct}%" -ForegroundColor White
Write-Host ""

# ============================================================
# 1. 清理临时文件
# ============================================================
Write-Host "[1/5] 清理临时文件..." -ForegroundColor Cyan

$tempDirs = @($env:TEMP, $env:TMP, "C:\Windows\Temp", "C:\Windows\Prefetch")
$tempFreed = 0

foreach ($dir in $tempDirs) {
    if (Test-Path $dir) {
        try {
            $before = (Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            $beforeMB = [math]::Round($before/1MB, 1)

            if ($WhatIf) {
                Write-Host "  将清理: $dir (预估 ${beforeMB} MB)" -ForegroundColor Yellow
            } else {
                Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.PSIsContainer } |
                    Remove-Item -Force -ErrorAction SilentlyContinue

                $after = (Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                $freed = $before - $after
                $tempFreed += $freed

                if ($freed -gt 0) {
                    Write-Host "  ✓ $dir (释放 ${beforeMB} MB)" -ForegroundColor Green
                }
            }
        } catch {
            Write-Host "  ✗ $dir (跳过: $_)" -ForegroundColor Gray
        }
    }
}

Write-Host "  临时文件清理完成 $(if($WhatIf){' (预演)'}else{''})" -ForegroundColor Gray
Write-Host ""

# ============================================================
# 2. 清理 DNS 缓存
# ============================================================
Write-Host "[2/5] 清理 DNS 缓存..." -ForegroundColor Cyan

if (-not $WhatIf) {
    try {
        Clear-DnsClientCache
        Write-Host "  ✓ DNS 缓存已清理" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ DNS 缓存清理失败: $_" -ForegroundColor Gray
    }
} else {
    Write-Host "  将清理 DNS 缓存" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# 3. 释放进程工作集内存
# ============================================================
Write-Host "[3/5] 释放进程工作集内存..." -ForegroundColor Cyan

if (-not $WhatIf) {
    try {
        Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class MemOpt {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
}
"@

        $freed = 0
        $procs = Get-Process | Where-Object {
            $_.WorkingSet64 -gt 50MB -and
            $_.Name -notin @("System", "smss", "csrss", "wininit", "services", "lsass", "Memory Compression")
        }

        foreach ($p in $procs) {
            try {
                $before = $p.WorkingSet64
                [MemOpt]::EmptyWorkingSet($p.Handle) | Out-Null
                $p.Refresh()
                $freed += ($before - $p.WorkingSet64)
            } catch {}
        }

        $freedMB = [math]::Round($freed/1MB, 1)
        Write-Host "  ✓ 已对 $($procs.Count) 个进程执行 EmptyWorkingSet (释放 ${freedMB} MB)" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ 释放工作集失败: $_" -ForegroundColor Gray
    }
} else {
    Write-Host "  将对所有大内存进程执行 EmptyWorkingSet" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# 4. 停止可疑服务 (可选)
# ============================================================
Write-Host "[4/5] 检查可停止的服务..." -ForegroundColor Cyan

$services = @(
    @{ Name = "PBIEgwService"; Desc = "Power BI Enterprise Gateway"; Confirm = $true },
    @{ Name = "pbidatamovement"; Desc = "Power BI Personal Gateway"; Confirm = $true }
)

foreach ($svc in $services) {
    $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue

    if ($service -and $service.Status -eq "Running") {
        Write-Host "  发现: $($svc.Desc) - $($service.Name)" -ForegroundColor Yellow

        if ($WhatIf) {
            Write-Host "    将停止此服务 (释放约 500MB)" -ForegroundColor Yellow
        } elseif ($Force) {
            try {
                Stop-Service $svc.Name -Force
                Write-Host "    ✓ 已停止 $($svc.Desc)" -ForegroundColor Green
            } catch {
                Write-Host "    ✗ 停止失败: $_" -ForegroundColor Gray
            }
        } else {
            Write-Host "    使用 -Force 参数可自动停止此服务" -ForegroundColor Gray
        }
    }
}

Write-Host ""

# ============================================================
# 5. 清理浏览器缓存 (可选)
# ============================================================
Write-Host "[5/5] 浏览器缓存清理提示..." -ForegroundColor Cyan

Write-Host "  提示: 浏览器缓存需要手动清理" -ForegroundColor Gray
Write-Host "    Chrome: chrome://settings/clearBrowserData" -ForegroundColor Gray
Write-Host "    Edge: edge://settings/clearBrowserData" -ForegroundColor Gray
Write-Host ""

# ============================================================
# 结果汇总
# ============================================================
if (-not $WhatIf) {
    # 获取清理后内存状态
    $os = Get-CimInstance Win32_OperatingSystem
    $afterTotal = [math]::Round($os.TotalVisibleMemorySize/1MB, 2)
    $afterFree = [math]::Round($os.FreePhysicalMemory/1MB, 2)
    $afterUsed = $afterTotal - $afterFree
    $afterPct = [math]::Round($afterUsed/$afterTotal*100, 1)

    $freedTotal = $afterFree - $beforeFree

    Write-Host "清理后内存状态:" -ForegroundColor Gray
    Write-Host "  总计: ${afterTotal} GB  已用: ${afterUsed} GB  可用: ${afterFree} GB  使用率: ${afterPct}%" -ForegroundColor White
    Write-Host ""
    Write-Host "清理效果:" -ForegroundColor Cyan
    Write-Host "  可用内存增加: +$([math]::Round($freedTotal/1024, 2)) GB" -ForegroundColor Green
    Write-Host "  使用率降低: $([math]::Round($beforePct - $afterPct, 1))%" -ForegroundColor Green
    Write-Host "  临时文件清理: $([math]::Round($tempFreed/1MB, 1)) MB" -ForegroundColor Green
    Write-Host ""
}

Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                        清理完成                                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "如需实际执行清理，移除 -WhatIf 参数:" -ForegroundColor Yellow
    Write-Host "  .\scripts\quick-cleanup.ps1" -ForegroundColor Gray
} elseif (-not $Force) {
    Write-Host "提示: 使用 -Force 参数可自动停止高内存服务" -ForegroundColor Yellow
    Write-Host "  .\scripts\quick-cleanup.ps1 -Force" -ForegroundColor Gray
}
