# Microsoft Power Automate Desktop Troubleshooter

Created by **Dewald Pretorius**.

A read-only PowerShell toolkit for diagnosing Power Automate Desktop installation, runtime services, browser automation, cloud connectivity, and recent execution failures.

## Checks

- Power Automate Desktop and RPA processes
- UIFlow service state
- Store and Win32 installation evidence
- Browser extension folders
- Connectivity to Power Automate and Microsoft identity endpoints
- Recent Application log events related to UIFlow and RPA components

## Run

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Microsoft_Power_Automate_Desktop_Troubleshooter.ps1"
```

Reports are saved to `Desktop\Power_Automate_Desktop_Reports` as TXT and CSV.

## Scenarios supported

- Desktop console does not start
- Flows fail at runtime
- Browser automation does not attach
- Selectors stop working after application changes
- UIFlow service problems
- Sign-in and cloud connectivity failures
- Unattended or user-context execution differences

## Safety

The script does not modify flows, credentials, selectors, services, gateways, or browser extensions. It gathers evidence and recommends next steps.
