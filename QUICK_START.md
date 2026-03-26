# MemoryGuardian Pro - Quick Start Guide

## Installation

```powershell
cd E:\workbuddy\workspace\MemoryGuardian-Pro
.\scripts\install.ps1 -EnableAutoStart -AutoStartMethod TaskScheduler
```

## Start Monitoring

### With Dashboard (Recommended):
```powershell
.\MemoryGuardian.ps1 -Dashboard -DashboardPort 19527 -LogToFile
```

### Without Dashboard:
```powershell
.\MemoryGuardian.ps1 -LogToFile
```

## Access Dashboard

Open browser: **http://localhost:19527**

## Common Commands

### Quick Cleanup:
```powershell
.\scripts\quick-cleanup.ps1
```

### Test Modules:
```powershell
.\scripts\test-modules.ps1
```

### Configure Auto-Start:
```powershell
Import-Module .\src\integrations\AutoStart.psm1
Enable-AutoStartTaskScheduler
```

### Uninstall:
```powershell
.\scripts\uninstall.ps1
```

## Configuration Files

| File | Description |
|------|-------------|
| `config/settings.json` | Main configuration |
| `config/rules.yaml` | Process monitoring rules |
| `config/whitelist.yaml` | Process whitelist |

## Key Settings

### Alert Threshold (Default: 85%)
Edit `config/settings.json`:
```json
{
  "monitoring": {
    "alertThresholdPct": 85,
    "criticalThresholdPct": 95
  }
}
```

### Monitor Interval (Default: 5 seconds)
```json
{
  "monitoring": {
    "intervalSeconds": 5
  }
}
```

### Enable Auto-Kill
```json
{
  "autoOptimization": {
    "autoKill": false,
    "onlyKillHighRisk": true
  }
}
```

## Adding Custom Rules

Edit `config/rules.yaml`:
```yaml
rules:
  - name: YourProcess
    max_mb: 1000
    reason: "Your custom reason"
    kill_cmd: "taskkill /F /PID {pid}"
    auto_kill: false
    category: "app"
    priority: 3
```

## Adding to Whitelist

Edit `config/whitelist.yaml`:
```yaml
custom:
  - YourProcess1
  - YourProcess2.exe
  - YourPattern*
```

## Troubleshooting

### Modules Not Loading:
```powershell
.\scripts\test-modules.ps1
```

### Port Already in Use:
Change port in command:
```powershell
.\MemoryGuardian.ps1 -Dashboard -DashboardPort 19528
```

### Logs Location:
```
C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\logs\
```

### State Data Location:
```
C:\Users\Pan\WorkBuddy\MemoryGuardian-Pro\data\
```

## Dashboard Features

- **Memory Usage**: Real-time system memory monitoring
- **Process List**: Top memory-consuming processes
- **Alerts View**: Recent memory alerts
- **Quick Actions**: Clean memory, stop monitoring

## System Tray

Currently disabled. Use Dashboard instead.

## Need Help?

1. Read `README.md` - Full documentation
2. Check `ENCODING_FIX_REPORT.md` - Fix history
3. Review logs in `logs/` directory

---

**Version**: 1.0.0
**Last Updated**: 2026-03-26
