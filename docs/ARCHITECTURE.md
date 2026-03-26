# MemoryGuardian Pro 架构设计文档

## 1. 系统概述

MemoryGuardian Pro 是一个模块化的 Windows 内存监控与优化系统,采用 PowerShell 模块化架构,注重线程安全、可扩展性和易用性。

### 1.1 核心设计原则

- **模块化设计**: 功能拆分为独立模块,职责单一
- **线程安全**: 使用 `ConcurrentDictionary` 等线程安全集合
- **可扩展性**: 插件化架构,易于添加新功能
- **安全性**: 命令白名单、输入验证、权限控制
- **可观测性**: 完善的日志系统和状态导出
- **用户友好**: 一键安装、可视化Dashboard、桌面弹窗

---

## 2. 架构分层

```
┌─────────────────────────────────────────────────────────────┐
│                     用户交互层 (UI Layer)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Desktop     │  │  Dashboard   │  │  Command     │       │
│  │  Popup       │  │  (Web UI)    │  │  Line        │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    集成层 (Integration Layer)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  AutoStart   │  │  Tray Icon   │  │  Notifier    │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    业务逻辑层 (Business Layer)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Monitor     │  │  Analyzer    │  │  Executor    │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    数据层 (Data Layer)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  StateManager│  │  Logger      │  │  Config      │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   系统层 (System Layer)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Windows API │  │  WMI/CIM     │  │  File System │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 核心模块详解

### 3.1 Monitor.psm1 (监控引擎)

**职责**: 内存状态采集、进程监控、基础告警检测

**主要功能**:
- 内存状态采集 (Get-ComputerInfo, Get-CimInstance)
- 进程快照 (Get-Process)
- CPU 负载监控
- 内存趋势计算 (移动平均、增长率)
- 基础告警触发

**关键数据结构**:
```powershell
MemoryState {
    TotalGB: double
    UsedGB: double
    FreeGB: double
    UsedPct: double
    AvailableGB: double
    CachedGB: double
    SwapUsedGB: double
    SwapTotalGB: double
    SwapPct: double
}
```

### 3.2 Analyzer.psm1 (分析引擎)

**职责**: AI驱动分析、规则引擎、优化建议生成

**主要功能**:
- 规则引擎 (基于config/rules.json)
- 进程异常检测 (阈值+趋势)
- 内存泄漏检测 (Z-Score统计算法)
- 风险评分 (四维度加权:内存占用、增长率、进程重要性、历史行为)
- 优化建议生成

**分析算法**:
1. **阈值检测**: 进程内存超过阈值 → 高危进程
2. **趋势检测**: 计算进程内存增长率 → 快速增长进程
3. **Z-Score检测**: 统计异常 → 泄漏进程
4. **规则匹配**: 应用自定义规则 → 自定义告警

**风险评分模型**:
```
RiskScore = W1*内存占用分 + W2*增长率分 + W3*重要性分 + W4*历史行为分
```

### 3.3 Executor.psm1 (执行器)

**职责**: 安全命令执行、操作审计

**主要功能**:
- 命令白名单验证
- 安全进程终止
- EmptyWorkingSet内存释放
- 服务控制
- DryRun模式

**安全机制**:
- 白名单验证 (只允许预定义命令)
- 参数验证 (防止注入攻击)
- 操作日志 (审计追踪)
- DryRun模式 (测试安全性)

**支持的操作**:
- `Stop-Process` / `taskkill` - 终止进程
- `Stop-Service` / `net stop` - 停止服务
- `Start-Service` / `net start` - 启动服务
- `EmptyWorkingSet` - 释放内存

### 3.4 StateManager.psm1 (状态管理)

**职责**: 线程安全的状态管理、历史数据维护

**主要功能**:
- 全局状态维护 (ConcurrentDictionary)
- 历史数据管理 (环形缓冲区)
- 告警冷却管理
- 状态持久化 (JSON导出/导入)
- 线程安全保证

**线程安全机制**:
```powershell
# 使用 ConcurrentDictionary 保证线程安全
$State = [ConcurrentDictionary[string,object]]::new()
$State['MemPct'] = 80.5  # 线程安全操作
```

**历史数据管理**:
- 最大保留: 720个数据点 (约2.5天,5分钟采样)
- 自动清理: 超过7天的数据自动删除
- 支持查询: 按时间范围、数量查询

### 3.5 Logger.psm1 (日志系统)

**职责**: 多级别日志记录、日志轮换

**日志级别**:
- Debug - 调试信息
- Info - 一般信息
- Warn - 警告信息
- Error - 错误信息
- Fatal - 致命错误

**日志轮换**:
- 单文件大小限制: 默认10MB
- 保留文件数: 默认5个
- 自动命名: `memoryguardian_yyyyMMdd.log`

### 3.6 AlertPopup.psm1 (弹窗告警)

**职责**: 桌面弹窗显示、用户交互处理

**主要功能**:
- 美观的WPF弹窗界面
- 一键清理按钮
- 详细信息展示
- 告警历史查看

**UI设计**:
- 深色主题
- 渐变色卡片
- 流畅动画
- 响应式布局

### 3.7 Dashboard.psm1 (Web Dashboard)

**职责**: HTTP服务器、数据API、可视化展示

**主要功能**:
- 内置HTTP服务器 (使用.NET HttpListener)
- RESTful API
- 实时数据推送
- 图表可视化 (Chart.js)

**API端点**:
- `GET /api/state` - 获取当前状态
- `GET /api/history` - 获取历史数据
- `GET /api/processes` - 获取进程列表
- `POST /api/optimize` - 执行优化
- `GET /api/health` - 健康检查

### 3.8 AutoStart.psm1 (开机自启动)

**职责**: 开机自启动配置、状态查询

**支持的方式**:
1. **注册表方式**: 写入 `HKCU:\Software\Microsoft\Windows\CurrentVersion\Run`
2. **任务计划程序**: 创建计划任务

**优势对比**:
| 方式 | 优点 | 缺点 |
|-----|------|------|
| 注册表 | 简单直接 | 无日志记录 |
| 任务计划 | 支持延迟启动、日志记录 | 配置较复杂 |

---

## 4. 数据流

### 4.1 监控流程

```
Monitor Loop (每30秒)
  ↓
1. 采集内存状态 (MemoryState)
  ↓
2. 采集进程快照 (Top Processes)
  ↓
3. 更新StateManager (线程安全)
  ↓
4. 触发Analyzer分析
  ↓
5. 生成告警 (超过阈值)
  ↓
6. 显示弹窗 / 发送通知
  ↓
7. 记录历史数据
  ↓
8. 循环继续...
```

### 4.2 优化流程

```
用户点击"一键清理"
  ↓
1. Executor验证命令白名单
  ↓
2. 显示确认对话框
  ↓
3. 执行优化操作:
   - 终止高危进程
   - 释放内存
   - 清理缓存
  ↓
4. 记录操作日志
  ↓
5. 更新状态
  ↓
6. 显示结果
```

### 4.3 Dashboard数据流

```
浏览器请求 /api/state
  ↓
HTTP Listener接收
  ↓
StateManager导出状态 (JSON)
  ↓
返回响应
  ↓
前端解析并渲染 (Chart.js)
  ↓
显示图表
```

---

## 5. 线程安全设计

### 5.1 线程安全问题

在 PowerShell 中,主要线程安全问题:
- 多线程并发访问共享数据
- 计时器回调与主线程冲突
- Dashboard请求与监控循环冲突

### 5.2 解决方案

1. **使用线程安全集合**
```powershell
$State = [ConcurrentDictionary[string,object]]::new()
```

2. **避免共享状态**
- 每个模块维护自己的状态
- 通过API传递数据,不直接访问

3. **使用锁机制** (如需要)
```powershell
$lock = [object]::new()
lock($lock) {
    # 临界区代码
}
```

---

## 6. 扩展性设计

### 6.1 插件系统

未来可支持的插件:
- **通知插件**: Slack、Email、Telegram
- **分析插件**: 机器学习预测、AI分析
- **存储插件**: 数据库存储、云同步

### 6.2 规则引擎

支持自定义规则:
```json
{
  "name": "CustomRule",
  "pattern": "myapp",
  "maxMB": 500,
  "action": "ALERT | KILL | OPTIMIZE",
  "reason": "自定义规则"
}
```

### 6.3 API设计

RESTful API支持第三方集成:
```powershell
# 获取状态
GET /api/state

# 执行优化
POST /api/optimize
{
  "actions": ["empty_working_set", "kill_high_memory"]
}

# 自定义规则
POST /api/rules
{
  "rules": [...]
}
```

---

## 7. 性能优化

### 7.1 内存优化

- 使用环形缓冲区限制历史数据量
- 定期清理过期数据
- 避免频繁的大对象创建

### 7.2 CPU优化

- 异步执行耗时操作
- 使用线程池处理请求
- 合理设置监控间隔

### 7.3 I/O优化

- 批量写入日志
- 异步文件操作
- 缓存频繁读取的配置

---

## 8. 安全性设计

### 8.1 命令白名单

只允许执行预定义的安全命令:
```powershell
$SafeCommands = @{
    'Stop-Process' = $true
    'Stop-Service' = $true
    'EmptyWorkingSet' = $true
}
```

### 8.2 输入验证

对所有用户输入进行严格验证:
- 进程ID验证 (必须是数字)
- 文件路径验证 (检查路径合法性)
- 命令参数验证 (防止注入)

### 8.3 权限控制

- 进程终止需要管理员权限 (可选)
- 白名单进程不可终止
- DryRun模式默认开启

### 8.4 审计日志

记录所有敏感操作:
- 进程终止
- 服务停止
- 配置修改

---

## 9. 测试策略

### 9.1 单元测试

- 测试各个模块的独立功能
- Mock外部依赖
- 边界条件测试

### 9.2 集成测试

- 测试模块间协作
- 测试完整流程
- 压力测试

### 9.3 端到端测试

- 测试用户场景
- 测试安装/卸载
- 测试Dashboard功能

---

## 10. 未来规划

### 10.1 短期目标 (v2.1)
- [ ] 完善Dashboard图表
- [ ] 添加更多通知渠道
- [ ] 优化AI分析算法

### 10.2 中期目标 (v3.0)
- [ ] 机器学习预测
- [ ] 云数据同步
- [ ] 跨平台支持 (Linux/Mac)

### 10.3 长期目标
- [ ] 插件市场
- [ ] 企业版功能
- [ ] SaaS服务

---

## 11. 技术栈

- **语言**: PowerShell 5.1+
- **UI**: WPF (弹窗), HTML/JS (Dashboard)
- **图表**: Chart.js
- **线程安全**: System.Collections.Concurrent
- **HTTP服务**: System.Net.HttpListener
- **日志**: 自定义日志系统
- **配置**: JSON

---

## 12. 参考文档

- [PowerShell 文档](https://docs.microsoft.com/en-us/powershell/)
- [Chart.js 文档](https://www.chartjs.org/docs/)
- [ConcurrentDictionary](https://docs.microsoft.com/en-us/dotnet/api/system.collections.concurrent.concurrentdictionary-2)

---

**文档版本**: v1.0.0
**最后更新**: 2025-03-26
**维护者**: MemoryGuardian Team
