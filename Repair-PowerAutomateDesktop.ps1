#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$RestartServices,
    [switch]$ClearCache,
    [switch]$RepairWebView2,
    [switch]$ResetPackage,
    [switch]$Force,

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = "$env:USERPROFILE\Desktop\PowerAutomateRepair"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$warnings = [System.Collections.Generic.List[string]]::new()
$logPath = $null

function Write-RepairLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN')][string]$Level = 'INFO'
    )

    $entry = '[{0}] [{1}] {2}' -f (Get-Date -Format 's'), $Level, $Message
    Write-Host $entry
    if ($logPath) {
        Add-Content -LiteralPath $logPath -Value $entry -Encoding UTF8
    }
}

function Add-RepairWarning {
    param([Parameter(Mandatory)][string]$Message)

    $warnings.Add($Message)
    Write-RepairLog -Level WARN -Message $Message
}

function Find-WebView2Setup {
    foreach ($root in @(${env:ProgramFiles(x86)}, $env:ProgramFiles) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique) {
        $applicationPath = Join-Path $root 'Microsoft\EdgeWebView\Application'
        if (-not (Test-Path -LiteralPath $applicationPath)) {
            continue
        }

        $setup = Get-ChildItem -LiteralPath $applicationPath -Filter 'setup.exe' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -match '[\\/]Installer$' } |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($setup) {
            return $setup.FullName
        }
    }

    return $null
}

try {
    if ($env:OS -ne 'Windows_NT') {
        throw 'This repair requires Windows.'
    }

    if (-not ($RestartServices -or $ClearCache -or $RepairWebView2 -or $ResetPackage)) {
        throw 'Choose at least one repair action.'
    }

    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    $logPath = Join-Path $OutputPath ('repair-{0:yyyyMMdd-HHmmss}.log' -f (Get-Date))

    $processes = @(Get-Process -Name 'PAD.Console', 'Microsoft.Flow.RPA.Desktop' -ErrorAction SilentlyContinue)
    $processes |
        Select-Object ProcessName, Id, Path |
        Export-Csv (Join-Path $OutputPath 'processes-before.csv') -NoTypeInformation -Encoding UTF8

    if ($ClearCache -and $processes.Count -gt 0 -and -not $Force) {
        throw 'Close Power Automate Desktop or use -Force before clearing application cache.'
    }

    if ($ClearCache -and $processes.Count -gt 0 -and $Force) {
        if ($PSCmdlet.ShouldProcess('Power Automate Desktop processes', 'Stop before clearing cache')) {
            $processes | Stop-Process -Force -ErrorAction Stop
            Write-RepairLog 'Stopped Power Automate Desktop processes.'
        }
    }

    if ($RestartServices) {
        foreach ($serviceName in 'UIFlowService', 'PowerAutomateService') {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $service) {
                Add-RepairWarning "Service '$serviceName' is not installed."
                continue
            }

            if ($PSCmdlet.ShouldProcess($serviceName, 'Restart Power Automate service')) {
                try {
                    if ($service.Status -eq 'Running') {
                        Restart-Service -Name $serviceName -Force -ErrorAction Stop
                    }
                    else {
                        Start-Service -Name $serviceName -ErrorAction Stop
                    }
                    Write-RepairLog "Started or restarted '$serviceName'."
                }
                catch {
                    Add-RepairWarning "Could not restart '$serviceName': $($_.Exception.Message)"
                }
            }
        }
    }

    if ($ClearCache) {
        foreach ($cachePath in @(
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Power Automate Desktop\Cache'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Power Automate Desktop\WebView2')
        )) {
            if (-not (Test-Path -LiteralPath $cachePath)) {
                continue
            }

            if ($PSCmdlet.ShouldProcess($cachePath, 'Clear Power Automate Desktop cache contents')) {
                Get-ChildItem -LiteralPath $cachePath -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction Stop
                Write-RepairLog "Cleared '$cachePath'."
            }
        }
    }

    if ($RepairWebView2) {
        $setupPath = Find-WebView2Setup
        if (-not $setupPath) {
            throw 'Microsoft Edge WebView2 setup.exe was not found in standard installation paths.'
        }

        if ($PSCmdlet.ShouldProcess('Microsoft Edge WebView2 Runtime', 'Run system-level repair')) {
            $process = Start-Process -FilePath $setupPath `
                -ArgumentList @('--repair', '--msedgewebview', '--system-level', '--verbose-logging') `
                -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) {
                throw "WebView2 repair exited with code $($process.ExitCode)."
            }
            Write-RepairLog 'WebView2 repair completed successfully.'
        }
    }

    if ($ResetPackage) {
        if (-not (Get-Command -Name 'Reset-AppxPackage' -ErrorAction SilentlyContinue)) {
            throw 'Reset-AppxPackage is unavailable on this Windows build.'
        }

        $package = Get-AppxPackage -Name '*PowerAutomateDesktop*' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $package) {
            throw 'The Power Automate Desktop AppX package was not found for the current user.'
        }

        if ($PSCmdlet.ShouldProcess($package.PackageFullName, 'Reset Power Automate Desktop package data')) {
            Reset-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
            Write-RepairLog 'Power Automate Desktop package reset completed.'
        }
    }

    $warnings | Set-Content -LiteralPath (Join-Path $OutputPath 'warnings.txt') -Encoding UTF8
    if ($warnings.Count -gt 0) {
        Write-RepairLog -Level WARN -Message "Completed with $($warnings.Count) warning(s)."
        exit 2
    }

    Write-RepairLog 'Power Automate Desktop repair workflow completed.'
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
