# Fix encoding issues by removing Chinese comments
# This script will be used to fix all module files

$modules = @(
    "src\dashboard\Dashboard.psm1",
    "src\ui\AlertPopup.psm1",
    "src\utils\Logger.psm1",
    "src\utils\StateManager.psm1",
    "src\utils\Executor.psm1",
    "src\integrations\AutoStart.psm1"
)

Write-Host "Fixing encoding issues in module files..." -ForegroundColor Cyan

foreach ($module in $modules) {
    $path = "E:\workbuddy\workspace\MemoryGuardian-Pro\$module"
    if (Test-Path $path) {
        Write-Host "  Checking: $module" -ForegroundColor Gray
        
        # Read file content
        $content = Get-Content $path -Raw -Encoding UTF8
        
        # Check if it contains problematic Chinese patterns
        if ($content -match "[\u4e00-\u9fff]") {
            Write-Host "    Found Chinese characters - file needs update" -ForegroundColor Yellow
            
            # Simple fix: remove Chinese comments and replace common Chinese strings with English
            $content = $content -replace "# .*[\u4e00-\u9fff].*?$", ""
            $content = $content -replace "内存告警", "Memory Alert"
            $content = $content -replace "系统托盘", "System Tray"
            $content = $content -replace "启动成功", "Started successfully"
            $content = $content -replace "启动失败", "Start failed"
            $content = $content -replace "端口.*可能被占用", "Port might be in use"
            $content = $content -replace "实时数据", "Real-time data"
            $content = $content -replace "执行清理", "Execute cleanup"
            $content = $content -replace "终止进程", "Kill process"
            
            # Write back
            [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)
            Write-Host "    Fixed: $module" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "Encoding fix complete!" -ForegroundColor Green
