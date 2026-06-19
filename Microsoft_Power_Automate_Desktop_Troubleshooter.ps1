#requires -Version 5.1
<# Created by Dewald Pretorius #>
[CmdletBinding()]
param([string]$OutputPath)
$ErrorActionPreference='SilentlyContinue'
if(-not $OutputPath){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Power_Automate_Desktop_Reports'}
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$report=Join-Path $OutputPath "PAD_Diagnostics_$stamp.txt"
$csv=Join-Path $OutputPath "PAD_Findings_$stamp.csv"
function Finding{param($Area,$Status,$Detail,$Recommendation);[pscustomobject]@{Area=$Area;Status=$Status;Detail=$Detail;Recommendation=$Recommendation}}
$findings=@()
$processes=Get-Process PAD.Console,Microsoft.Flow.RPA.Agent,Microsoft.Flow.RPA.Desktop -ErrorAction SilentlyContinue
$findings+=Finding 'Processes' ($(if($processes){'Detected'}else{'Not running'})) "Count=$($processes.Count)" 'Confirm the console and runtime processes start under the intended user account.'
$services=Get-Service UIFlowService -ErrorAction SilentlyContinue
$findings+=Finding 'Service' ($(if($services.Status -eq 'Running'){'Pass'}elseif($services){'Review'}else{'Not installed'})) ($(if($services){"UIFlowService=$($services.Status)"}else{'UIFlowService not found'})) 'Repair Power Automate Desktop if the required service is missing or cannot start.'
$appx=Get-AppxPackage '*PowerAutomateDesktop*' -ErrorAction SilentlyContinue
$uninstall=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'|Where-Object DisplayName -match 'Power Automate'
$findings+=Finding 'Installation' ($(if($appx -or $uninstall){'Pass'}else{'Review'})) "StorePackage=$([bool]$appx); Win32Install=$([bool]$uninstall)" 'Confirm only the intended supported installation is present.'
$extensions=@(
 "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions",
 "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions"
)
$extCount=0;foreach($path in $extensions){if(Test-Path $path){$extCount+=(Get-ChildItem $path -Directory).Count}}
$findings+=Finding 'Browser extensions' ($(if($extCount -gt 0){'Detected'}else{'Review'})) "ExtensionFolders=$extCount" 'Verify the Power Automate browser extension is installed and enabled in the active browser profile.'
$targets='make.powerautomate.com','login.microsoftonline.com','api.powerplatform.com'
foreach($target in $targets){$dns=$false;$https=$false;try{$dns=[bool](Resolve-DnsName $target -ErrorAction Stop|Select-Object -First 1)}catch{};try{$https=Test-NetConnection $target -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue}catch{};$findings+=Finding 'Connectivity' ($(if($dns -and $https){'Pass'}else{'Fail'})) "$target DNS=$dns HTTPS443=$https" 'Review proxy, TLS inspection, firewall, sign-in policy, and service availability.'}
$events=Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=(Get-Date).AddDays(-7)}|Where-Object{$_.Message -match 'Power Automate|UIFlow|Microsoft.Flow.RPA'}|Select-Object -First 40 TimeCreated,Id,ProviderName,LevelDisplayName,Message
$findings+=Finding 'Recent events' ($(if($events){'Review'}else{'Pass'})) "Count=$($events.Count)" 'Correlate failures with selectors, browser updates, credential prompts, permissions, and unattended-run context.'
$findings|Export-Csv $csv -NoTypeInformation -Encoding UTF8
@('MICROSOFT POWER AUTOMATE DESKTOP TROUBLESHOOTER','Created by Dewald Pretorius',"Generated: $(Get-Date)",'',($findings|Format-Table -AutoSize|Out-String -Width 240),'RECENT EVENTS',($events|Format-List|Out-String -Width 240),'INSTALLED PRODUCTS',($uninstall|Select-Object DisplayName,DisplayVersion,Publisher,InstallLocation|Format-Table -AutoSize|Out-String -Width 240))|Set-Content $report -Encoding UTF8
Write-Host "Reports created in: $OutputPath" -ForegroundColor Green
