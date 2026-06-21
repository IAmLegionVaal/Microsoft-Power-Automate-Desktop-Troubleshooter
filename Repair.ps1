#requires -Version 5.1
<# Created by Dewald Pretorius. #>
[CmdletBinding(SupportsShouldProcess=$true)]
param([ValidateSet('Diagnose','ResetCache','RestartService','FlushDns')][string]$Action='Diagnose',[string]$OutputPath=(Join-Path ([Environment]::GetFolderPath('Desktop')) 'Power_Automate_Desktop_Repair'))
$ErrorActionPreference='Stop'
$cachePath="$env:LOCALAPPDATA\Microsoft\Power Automate Desktop"
$serviceName='UIFlowService'
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$stamp=Get-Date -Format yyyyMMdd_HHmmss
$logPath=Join-Path $OutputPath "Repair_$stamp.log"
function Log([string]$Message){$line='{0:u} {1}'-f(Get-Date),$Message;Write-Host $line;Add-Content -LiteralPath $logPath -Value $line}
[ordered]@{Action=$Action;CacheExists=(Test-Path $cachePath);Service=(Get-Service $serviceName -ErrorAction SilentlyContinue|Select-Object Name,Status,StartType);Processes=@(Get-Process 'PAD.Console.Host','PAD.Robot','Microsoft.Flow.RPA.Agent' -ErrorAction SilentlyContinue|Select-Object Name,Id);Cloud443=(Test-NetConnection 'make.powerautomate.com' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue)}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutputPath "PreRepair_$stamp.json")
if($Action -eq 'Diagnose'){Log '[COMPLETE] Snapshot saved.';exit 0}
try{
 if($Action -eq 'ResetCache' -and $PSCmdlet.ShouldProcess($cachePath,'Back up and reset cache')){if(Get-Process 'PAD.Console.Host','PAD.Robot' -ErrorAction SilentlyContinue){throw 'Close Power Automate Desktop before resetting its cache.'};if(Test-Path $cachePath){$backup="$cachePath.backup-$stamp";Move-Item $cachePath $backup -Force;New-Item -ItemType Directory $cachePath -Force|Out-Null;Log "[BACKUP] $backup"}}
 elseif($Action -eq 'RestartService' -and $PSCmdlet.ShouldProcess($serviceName,'Restart service')){Restart-Service $serviceName -Force;Start-Sleep 2;if((Get-Service $serviceName).Status -ne 'Running'){throw 'UIFlowService did not return to Running.'}}
 elseif($Action -eq 'FlushDns' -and $PSCmdlet.ShouldProcess('Windows DNS client cache','Clear')){Clear-DnsClientCache}
}catch{Log "[FAILED] $($_.Exception.Message)";exit 5}
Log '[COMPLETE] Repair and verification completed.';exit 0
