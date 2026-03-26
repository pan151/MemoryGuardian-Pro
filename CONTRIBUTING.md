# Contributing to MemoryGuardian Pro

感谢您对 MemoryGuardian Pro 项目的关注!我们欢迎任何形式的贡献。

## 🤝 如何贡献

### 报告问题

如果您发现了 Bug 或有功能建议,请在 GitHub 上创建一个 Issue。

在创建 Issue 之前,请先搜索现有的 Issues,以避免重复报告。

### 提交代码

1. **Fork 本仓库**
2. **创建您的特性分支** (`git checkout -b feature/AmazingFeature`)
3. **提交您的更改** (`git commit -m 'Add some AmazingFeature'`)
4. **推送到分支** (`git push origin feature/AmazingFeature`)
5. **创建 Pull Request**

## 📋 代码规范

### PowerShell 代码规范

1. **函数命名**: 使用 `Verb-Noun` 格式 (PowerShell 标准)
2. **参数命名**: 使用 PascalCase
3. **注释**: 每个函数都需要有摘要注释 (`.SYNOPSIS`)
4. **错误处理**: 所有可能失败的操作都应该包含 `try-catch`
5. **日志记录**: 重要操作需要记录日志

### 示例

```powershell
<#
.SYNOPSIS
获取系统内存状态

.DESCRIPTION
采集内存使用情况,包括总内存、已用内存、可用内存等
#>
function Get-MemoryState {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Logger
    )
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        # ... 逻辑代码
        return $result
    }
    catch {
        if ($Logger) {
            $Logger.Error("Failed to get memory state: $_")
        }
        throw
    }
}
```

## 🔍 开发环境设置

### 前置要求
- PowerShell 5.1 或更高版本
- Windows 10 或更高版本
- (可选) VSCode + PowerShell Extension

### 设置步骤
```powershell
# 克隆仓库
git clone https://github.com/yourusername/MemoryGuardian-Pro.git
cd MemoryGuardian-Pro

# 导入模块
Import-Module src/core/MemoryMonitor.psm1
Import-Module src/core/Executor.psm1
# ... 其他模块

# 运行测试
.\tests\test-all.ps1
```

## 📝 提交消息规范

我们遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范:

- `feat:` 新功能
- `fix:` 修复 Bug
- `docs:` 文档更新
- `style:` 代码格式调整 (不影响功能)
- `refactor:` 重构代码
- `perf:` 性能优化
- `test:` 测试相关
- `chore:` 构建/工具相关

### 示例
```
feat(dashboard): 添加实时图表功能

fix(logger): 修复日志轮换时的文件锁定问题

docs(readme): 更新安装指南

refactor(core): 重构状态管理模块,使用线程安全集合
```

## 🧪 测试

### 运行测试
```powershell
# 运行所有测试
.\tests\test-all.ps1

# 运行单个模块测试
.\tests\test-monitor.ps1
.\tests\test-executor.ps1
```

### 编写测试
- 测试文件命名: `test-{ModuleName}.ps1`
- 使用 Pester 测试框架
- 覆盖正常情况和异常情况

### 示例
```powershell
Describe "Monitor Module" {
    It "Should return memory state" {
        $state = Get-MemoryState
        $state | Should -Not -BeNullOrEmpty
        $state.TotalGB | Should -BeGreaterThan 0
    }
}
```

## 📚 文档

更新代码时,请同步更新相关文档:
- README.md
- docs/ARCHITECTURE.md
- docs/api.md (如果添加了新的 API)
- CHANGELOG.md

## 🐛 Bug 修复流程

1. 在 Issue 中详细描述 Bug
2. 复现 Bug
3. 定位问题根源
4. 编写测试用例 (测试应该失败)
5. 修复 Bug
6. 确保测试通过
7. 提交 Pull Request

## ✨ 新功能流程

1. 先创建 Issue 讨论功能设计
2. 在 Issue 中获得团队同意后开始开发
3. 编写测试用例
4. 实现功能
5. 更新文档
6. 提交 Pull Request

## 📄 许可证

通过提交代码,您同意您的代码将按照项目的 MIT 许可证进行授权。

## 💬 社区

- GitHub Issues: [问题反馈](https://github.com/yourusername/MemoryGuardian-Pro/issues)
- GitHub Discussions: [讨论区](https://github.com/yourusername/MemoryGuardian-Pro/discussions)

---

感谢您的贡献! 🎉
