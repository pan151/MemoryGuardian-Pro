# ============================================================
# enable-autostart.ps1 - 开机自启动配置
# ============================================================

param(
    [switch]$Disable
)

$ErrorActionPreference = "Stop"

# 获取脚本路径
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$ScriptPath = Join-Path $ScriptRoot "MemoryGuardian.ps1"
$ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\MemoryGuardian-Pro.lnk"

if ($Disable) {
    # 禁用开机自启
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
        Write-Host "[OK] 已禁用开机自启动" -ForegroundColor Green
        Write-Host "  快捷方式已删除: $ShortcutPath" -ForegroundColor Gray
    } else {
        Write-Host "[INFO] 未发现开机自启动配置" -ForegroundColor Yellow
    }

    # 移除计划任务
    $taskExists = Get-ScheduledTask -TaskName "MemoryGuardian-Pro" -ErrorAction SilentlyContinue
    if ($taskExists) {
        Unregister-ScheduledTask -TaskName "MemoryGuardian-Pro" -Confirm:$false
        Write-Host "[OK] 已删除计划任务" -ForegroundColor Green
    }

    exit 0
}

# 启用开机自启
Write-Host "正在配置开机自启动..." -ForegroundColor Cyan
Write-Host ""

# 方法1: 创建启动文件夹快捷方式
Write-Host "[1/2] 创建启动文件夹快捷方式..." -ForegroundColor Gray

if (Test-Path $ShortcutPath) {
    Write-Host "[WARN] 快捷方式已存在，将重新创建" -ForegroundColor Yellow
    Remove-Item $ShortcutPath -Force
}

try {
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -Dashboard"
    $Shortcut.WorkingDirectory = $ScriptRoot
    $Shortcut.Description = "Memory Guardian Pro - 内存监控与优化"
    $Shortcut.Save()

    Write-Host "[OK] 快捷方式已创建: $ShortcutPath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] 创建快捷方式失败: $_" -ForegroundColor Red
    exit 1
}

# 方法2: 创建计划任务(更可靠)
Write-Host "[2/2] 创建计划任务..." -ForegroundColor Gray

$taskExists = Get-ScheduledTask -TaskName "MemoryGuardian-Pro" -ErrorAction SilentlyContinue
if ($taskExists) {
    Write-Host "[WARN] 计划任务已存在，将更新" -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName "MemoryGuardian-Pro" -Confirm:$false
}

try {
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -Dashboard" `
        -WorkingDirectory $ScriptRoot

    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = "PT30S"  # 延迟30秒启动

    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask `
        -TaskName "MemoryGuardian-Pro" `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Memory Guardian Pro - 实时内存监控与优化工具" `
        -Force | Out-Null

    Write-Host "[OK] 计划任务已创建: MemoryGuardian-Pro" -ForegroundColor Green
} catch {
    Write-Host "[WARN] 创建计划任务失败: $_" -ForegroundColor Yellow
    Write-Host "[INFO] 启动文件夹快捷方式仍可使用" -ForegroundColor Gray
}

Write-Host ""
Write-Host "✅ 开机自启动已配置成功！" -ForegroundColor Green
Write-Host ""
Write-Host "下次开机时，Memory Guardian Pro 将自动启动" -ForegroundColor Cyan
Write-Host "如需查看监控界面，访问: http://localhost:19527" -ForegroundColor Cyan
Write-Host ""
Write-Host "如需禁用开机自启动，运行:" -ForegroundColor Yellow
Write-Host "  .\scripts\enable-autostart.ps1 -Disable" -ForegroundColor Gray
