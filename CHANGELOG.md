# Changelog

All notable changes to MemoryGuardian Pro will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- 核心监控引擎 (MemoryMonitor.psm1)
- 安全命令执行器 (Executor.psm1)
- 线程安全状态管理 (StateManager.psm1)
- 日志系统 (Logger.psm1)
- 桌面弹窗告警 (AlertPopup.psm1)
- Web Dashboard (Dashboard.psm1)
- 开机自启动支持 (AutoStart.psm1)
- 一键安装/卸载脚本 (install.ps1, uninstall.ps1)
- 启动脚本 (start.ps1)
- 完整的项目文档 (README.md, ARCHITECTURE.md)

### Changed
- 重构为模块化架构
- 分离配置文件到 `config/settings.json`
- 使用线程安全的 ConcurrentDictionary
- 添加 RESTful API 支持

### Security
- 命令白名单机制
- 输入参数验证
- 权限控制

## [2.0.0] - 2025-03-26

### Added
- 完整的模块化架构
- 桌面弹窗告警 (带一键清理按钮)
- Web Dashboard (实时监控面板)
- 开机自启动 (注册表 + 任务计划程序)
- 线程安全的状态管理
- 多级别日志系统
- RESTful API (5个端点)

### Changed
- 重构原 `ai_memory_guardian.ps1` 为模块化架构
- 改进 AI 分析引擎 (规则引擎 + 趋势分析)
- 优化内存泄漏检测算法 (Z-Score)

### Fixed
- 修复多线程并发访问问题
- 修复日志轮换问题
- 修复 Dashboard API 跨域问题

### Security
- 添加命令白名单验证
- 添加输入参数验证
- 添加 DryRun 模式 (测试安全性)

### Deprecated
- 旧的单文件版本 `ai_memory_guardian.ps1` (已废弃)

### Removed
- 硬编码配置参数

## [1.0.0] - 2025-03-20

### Added
- 初始版本发布
- 基础内存监控功能
- 进程快照和 Top 10 列表
- 简单的告警机制
- 一键清理功能

---

## Future Plans

### [3.0.0] - Planned
- [ ] 机器学习预测 (内存趋势预测)
- [ ] 插件系统 (通知插件、分析插件)
- [ ] 云数据同步 (跨设备同步)
- [ ] 跨平台支持 (Linux/Mac)

### [2.1.0] - Planned
- [ ] 完善 Dashboard 图表 (Chart.js 集成)
- [ ] 添加更多通知渠道 (Slack, Email, Telegram)
- [ ] 优化 AI 分析算法
- [ ] 添加单元测试

### [2.0.1] - Planned
- [ ] 快速开始指南文档
- [ ] 配置说明文档
- [ ] API 文档
- [ ] 故障排查文档
- [ ] 贡献指南
