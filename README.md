# Microsoft Power Automate Desktop Troubleshooter

Created by **Dewald Pretorius**.

A PowerShell 5.1 toolkit for diagnosing Power Automate Desktop installation, runtime services, browser automation, cloud connectivity, and recent execution failures.

## Files

- `Microsoft_Power_Automate_Desktop_Troubleshooter.ps1` — read-only diagnostics and reports.
- `Repair.ps1` — guarded local repair actions with pre-change evidence, confirmation, logging, backup, and verification.

## Repair actions

- `Diagnose` — collects process, cache, service, and endpoint state.
- `ResetCache` — requires Power Automate Desktop to be closed, then moves its local data folder to a timestamped backup and creates a clean folder.
- `RestartService` — restarts `UIFlowService` and verifies that it returns to `Running`.
- `FlushDns` — clears the Windows DNS client cache.

```powershell
.\Repair.ps1 -Action Diagnose
.\Repair.ps1 -Action ResetCache -WhatIf
.\Repair.ps1 -Action RestartService -Confirm
```

Service repair normally requires an elevated PowerShell session. The workflow is source-reviewed but has not been runtime-tested on every Power Automate Desktop version or unattended-runtime configuration.
