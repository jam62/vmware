# Encrypt a password to file

$user ="robot@vsphere.local"
$File = "C:\Scripts\pscred"
[Byte[]] $key = (1..24)
$Password = "Str0ngPa$$w0rd" | ConvertTo-SecureString -AsPlainText -Force
$Password | ConvertFrom-SecureString -key $key | Out-File $File


# Use a password file in scripts

$user ="robot@vsphere.local"
$File = "C:\Scripts\pscred"
[Byte[]] $key = (1..24)
$pwd = Get-Content $File | ConvertTo-SecureString -Key $key
