# 快速开始指南

欢迎使用 Memory Guardian Pro！本指南将帮助您快速上手这个强大的内存监控与优化工具。

## 系统要求

- **操作系统**: Windows 10/11 (64位)
- **PowerShell**: 5.1 或更高版本
- **内存**: 建议 4GB 以上
- **权限**: 非管理员可运行，管理员模式功能更完整

## 安装步骤

### 1. 下载项目

```powershell
# 克隆仓库
git clone https://github.com/yourusername/MemoryGuardian-Pro.git
cd MemoryGuardian-Pro

# 或解压下载的压缩包
```

### 2. 运行安装向导

```powershell
# 以管理员身份运行 PowerShell
# 进入项目目录
cd E:\workbuddy\workspace\MemoryGuardian-Pro

# 运行安装脚本
.\scripts\install.ps1
```

安装向导将自动完成以下操作：
- ✅ 检查必要文件
- ✅ 创建数据目录
- ✅ 配置桌面快捷方式
- ✅ 配置开机自启动（可选）
- ✅ 测试运行

## 首次启动

### 方法1: 使用桌面快捷方式

双击桌面上的 "MemoryGuardian-Pro" 快捷方式即可启动。

### 方法2: 使用命令行

```powershell
# 基本模式（仅监控）
.\MemoryGuardian.ps1

# 完整模式（包含 Dashboard）
.\MemoryGuardian.ps1 -Dashboard

# 带自动终止功能
.\MemoryGuardian.ps1 -Dashboard -AutoKill
```

### 方法3: 开机自启动

如果安装时启用了开机自启动，程序将在系统启动后自动运行。您可以通过以下方式查看监控界面：

1. 系统托盘图标（右键选择 "打开 Dashboard"）
2. 访问 http://localhost:19527

## 使用 Dashboard

启动程序后，默认会自动打开浏览器访问 Dashboard。Dashboard 提供以下功能：

### 实时监控

- **内存使用率**: 显示当前内存使用百分比
- **告警次数**: 本会话累计的告警数量
- **已释放内存**: 本会话通过优化释放的内存总量
- **监控时长**: 程序已运行的时长

### 快速优化

1. **释放工作集内存**: 对所有进程执行 EmptyWorkingSet，温和释放内存
2. **执行完整优化**: 包括释放工作集、清理临时文件、清理 DNS 缓存

### 内存趋势图

- 显示最近 1 小时、30 分钟或 15 分钟的内存使用趋势
- 包含告警阈值线和危急阈值线
- 帮助识别内存使用模式和异常

### AI 分析结果

- 显示检测到的异常进程
- 每个问题包含详细信息（进程名、PID、内存占用、原因）
- 提供清理命令和执行按钮

### 进程列表

- 显示内存占用 TOP 20 进程
- 可直接终止异常进程
- 支持按内存、CPU 等排序

### 操作日志

- 实时显示系统操作日志
- 包含时间戳、日志级别、消息内容
- 支持滚动查看历史记录

## 配置自定义

### 修改监控参数

编辑 `config/settings.json` 文件：

```json
{
  "monitoring": {
    "intervalSeconds": 30,      // 监控间隔（秒）
    "alertThresholdPct": 80,    // 告警阈值（%）
    "criticalThresholdPct": 90, // 危急阈值（%）
    "processAlertMB": 800,      // 进程告警阈值（MB）
    "processKillMB": 2000,      // 进程自动终止阈值（MB）
    "historySize": 120          // 历史记录大小
  }
}
```

### 自定义监控规则

编辑 `config/rules.json` 文件：

```json
{
  "whitelist": [
    // 不监控的进程白名单
  ],
  "highRiskRules": [
    {
      "name": "YourProcess",
      "maxMB": 500,
      "reason": "自定义进程监控",
      "killCmd": "taskkill /F /IM YourProcess.exe",
      "action": "ALERT"
    }
  ]
}
```

## 常用操作

### 快速清理内存

```powershell
# 预演模式（不实际执行）
.\scripts\quick-cleanup.ps1 -WhatIf

# 完整清理
.\scripts\quick-cleanup.ps1

# 强制停止高内存服务
.\scripts\quick-cleanup.ps1 -Force
```

### 管理 Dashboard 端口

如果 19527 端口被占用，可以修改配置：

```json
{
  "dashboard": {
    "port": 8080
  }
}
```

### 查看日志

日志文件位于：`C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\logs\`

```powershell
# 查看今天的日志
Get-Content "C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\logs\memory_guardian_$(Get-Date -Format 'yyyyMMdd').log" -Tail 50

# 实时查看日志
Get-Content "C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\logs\memory_guardian_*.log" -Wait
```

## 故障排查

### 问题: Dashboard 无法打开

**解决方案**:
1. 检查程序是否正在运行
2. 检查端口是否被占用: `netstat -ano | findstr 19527`
3. 检查防火墙设置
4. 手动访问: http://localhost:19527

### 问题: 权限不足

**解决方案**:
以管理员身份运行 PowerShell：

```powershell
# 右键点击 PowerShell 图标
# 选择 "以管理员身份运行"
```

### 问题: 内存占用过高

**解决方案**:
1. 运行快速清理: `.\scripts\quick-cleanup.ps1`
2. 在 Dashboard 中点击 "执行完整优化"
3. 检查告警列表，终止异常进程
4. 调整监控阈值，减少告警频率

## 卸载

```powershell
# 运行卸载脚本
.\scripts\uninstall.ps1

# 或手动删除
.\scripts\enable-autostart.ps1 -Disable
# 然后删除整个项目目录
```

## 下一步

- 📖 查看 [配置说明](configuration.md) 了解更多配置选项
- 🔧 查看 [故障排查](troubleshooting.md) 解决常见问题
- 📊 查看 [API 文档](api.md) 了解编程接口

## 获取帮助

如果遇到问题或有任何建议，欢迎：

- 提交 Issue: https://github.com/yourusername/MemoryGuardian-Pro/issues
- 发送邮件: your-email@example.com
- 查看文档: https://github.com/yourusername/MemoryGuardian-Pro/wiki

---

享受流畅的内存管理体验！ 🚀
