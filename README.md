# Memory Guardian Pro

一个专业的 Windows 内存监控与优化工具，专为 AI 开发和创意工作场景打造。

## ✨ 主要功能

### 🚀 实时监控
- 每秒级内存状态采集
- 进程级详细追踪
- 历史趋势分析(支持7天数据)
- 智能异常检测(Z-Score统计算法)

### 🤖 AI 驱动的智能分析
- 内存泄漏检测(基于进程历史趋势)
- 异常进程识别(规则引擎+阈值检测)
- 个性化优化建议(四维度风险评分)
- 场景化规则引擎(支持30+种应用规则)

### 🎯 一键优化
- 桌面弹窗告警(带一键清理按钮,无需复制命令)
- 批量进程管理(白名单保护机制)
- 智能内存释放(EmptyWorkingSet API)
- 自动化清理脚本(支持DryRun模式)

### 📊 可视化 Dashboard
- 实时内存使用率图表
- 进程排行榜(Top 10)
- 告警时间线
- 性能趋势分析
- RESTful API支持

### ⚙️ 系统集成
- 开机自启动支持(注册表+任务计划程序两种方式)
- 一键安装/卸载脚本
- 日志审计跟踪(支持日志轮换)
- 状态持久化(支持状态保存和恢复)

## 🏗️ 项目架构

```
MemoryGuardian-Pro/
├── src/
│   ├── core/                # 核心引擎
│   │   ├── MemoryMonitor.psm1    # 内存监控引擎
│   │   ├── Executor.psm1          # 安全命令执行器
│   │   └── StateManager.psm1      # 线程安全状态管理
│   ├── ui/                  # 用户界面
│   │   └── AlertPopup.psm1        # 桌面弹窗告警
│   ├── dashboard/           # Web Dashboard
│   │   └── Dashboard.psm1         # HTTP服务器
│   ├── integrations/        # 系统集成
│   │   └── AutoStart.psm1         # 开机自启动
│   └── utils/               # 工具模块
│       └── Logger.psm1             # 日志系统
├── config/              # 配置文件
│   └── settings.json           # 主配置文件
├── docs/                # 文档
├── scripts/             # 执行脚本
│   ├── start.ps1               # 启动脚本
│   ├── install.ps1             # 一键安装
│   └── uninstall.ps1           # 一键卸载
├── build/               # 构建输出
└── README.md            # 项目文档
```

## 🚀 快速开始

### 1. 安装
```powershell
# 克隆仓库
git clone https://github.com/pan151/MemoryGuardian-Pro.git
cd MemoryGuardian-Pro

# 运行安装脚本(会自动配置开机自启动和桌面快捷方式)
.\scripts\install.ps1 -EnableAutoStart
```

### 2. 配置
编辑 `config/settings.json` 自定义监控参数:
```json
{
  "version": "1.0.0",
  "monitoring": {
    "intervalSeconds": 30,
    "alertThresholdPct": 80,
    "criticalThresholdPct": 90,
    "processAlertMB": 800,
    "processKillMB": 2000,
    "historySize": 120
  },
  "dashboard": {
    "enabled": true,
    "port": 19527,
    "autoOpen": true
  },
  "notifications": {
    "enabled": true,
    "soundEnabled": false,
    "cooldownMinutes": 5
  },
  "autoOptimization": {
    "enabled": false,
    "autoKill": false,
    "autoReleaseWorkingSet": true,
    "criticalConsecutiveCount": 3
  },
  "logging": {
    "enabled": true,
    "level": "INFO",
    "maxSizeMB": 100,
    "retentionDays": 30,
    "directory": "logs"
  },
  "dataStorage": {
    "directory": "data",
    "retentionHours": 168
  }
}
```

### 3. 启动
```powershell
# 基本模式（包含Dashboard）
.\scripts\start.ps1

# 仅后台监控模式（不启动Dashboard）
.\scripts\start.ps1 -NoDashboard

# 日志输出到文件
.\scripts\start.ps1 -LogToFile

# 指定Dashboard端口
.\scripts\start.ps1 -DashboardPort 19527

# DryRun模式(不执行实际优化操作)
.\scripts\start.ps1 -DryRun

# 组合使用多个参数
.\scripts\start.ps1 -NoDashboard -LogToFile -DryRun
```

### 4. 访问Dashboard
启动后在浏览器中访问:
```
http://localhost:19527
```

## 📖 使用文档

详细文档请查看 `docs/` 目录:
- [快速开始指南](docs/getting-started.md)
- [配置说明](docs/configuration.md)
- [API 文档](docs/api.md)
- [故障排查](docs/troubleshooting.md)

## 🔧 高级功能

### 自定义监控规则
在 `config/rules.json` 中添加自定义监控规则:
```json
{
  "name": "MyApp",
  "maxMB": 500,
  "pattern": "myapp",
  "reason": "自定义应用监控",
  "action": "ALERT"
}
```

### 白名单保护
在 `config/whitelist.yaml` 中配置保护进程:
```yaml
system:
  - System
  - smss.exe
  - csrss.exe
development:
  - code.exe
  - node.exe
  - powershell.exe
```

### RESTful API
启动后可使用以下API端点:
- `GET /api/state` - 获取当前状态
- `GET /api/history` - 获取历史数据
- `POST /api/optimize` - 执行内存优化
- `GET /api/health` - 健康检查

示例:
```powershell
# 获取当前状态
Invoke-RestMethod -Uri "http://localhost:19527/api/state" | ConvertTo-Json -Depth 10

# 执行内存优化
Invoke-RestMethod -Uri "http://localhost:19527/api/optimize" -Method Post
```

### 开机自启动
```powershell
# 启用开机自启动（推荐使用注册表方式）
.\scripts\install.ps1 -EnableAutoStart -AutoStartMethod Registry

# 检查自启动状态
Import-Module src/integrations/AutoStart.psm1
Get-AutoStartStatus

# 禁用开机自启动
.\scripts\uninstall.ps1
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request!

## 📄 许可证

MIT License

## 🙏 致谢

- 原始灵感来源于 WorkBuddy AI 诊断报告
- 使用 PowerShell 模块化架构
- Dashboard 使用 Chart.js 实现可视化
- 线程安全设计使用 ConcurrentDictionary

---

**注意**: 本工具仅供学习和开发环境使用，生产环境请谨慎使用自动终止功能。