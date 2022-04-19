#
# Run this script as administrator
#

$LogPath = "C:\Scripts\logs\"

# Write Log Function
function Write-Log
{
Param (
[string]$LogString,
[string]$fLogN = "Template.txt")
$LogFile = $LogPath + "\" +  $fLogN
If (!(Test-Path $LogFile)) {md $LogPath; New-Item -path $LogPath -name $fLogN -itemType File}
$Stamp = (Get-Date).toString("dd.MM.yyyy  HH:mm:ss")
$LogMessage = "$Stamp   $LogString"
Add-content $LogFile -value $LogMessage -Encoding UTF8
}
Write-Log "--------------------------------------------"

### Firewall Disable
Set-NetFirewallProfile -All -Enabled False -ErrorVariable err
# Get-NetFirewallProfile |select Name,Enabled
If ($Err.Count -gt 0) {
Write-Host "ERROR. Can NOT set Windows Firewall Profiles" -ForegroundColor Red 
Write-Log "ERROR. Can NOT set Windows Firewall Profiles"
}
Else {
Write-Host "Windows Firewall DISABLED" -ForegroundColor Green
Write-Log "Windows Firewall DISABLED" }

### IPv6 Disable
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\services\TCPIP6\Parameters' -Name DisabledComponents -Value 0xffffffff -ErrorVariable err
#Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\services\TCPIP6\Parameters' -Name DisabledComponents  
If ($Err.Count -gt 0) {
Write-Host "ERROR. Can NOT Disable IPv6" -ForegroundColor Red 
Write-Log "ERROR. Can NOT Disable IPv6"
}
Else {
Write-Host "IPv6 DISABLED" -ForegroundColor Green
Write-Log "IPv6 DISABLED" }


###  RDP Enable
# Easy way:
#Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0

# Hard Way:
if ((Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server').fDenyTSConnections) {
    (Get-WmiObject Win32_TerminalServiceSetting -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1, 1) | Out-Null
    (Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null
}
else {
    (Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null
}
Write-Host "Remote Desktop Access ENABLED" -ForegroundColor Green
Write-Log "Remote Desktop Access ENABLED"

### .Net 3.5 Install
Dism /online /enable-feature /featurename:NetFx3 /All /Source:D:\sources\sxs /LimitAccess

### Keyboard Layout
Set-ItemProperty -Path 'HKCU:\Keyboard Layout\Preload' -Name 1 -Value 00000409
Set-ItemProperty -Path 'HKCU:\Keyboard Layout\Preload' -Name 2 -Value 00000419
Get-ItemProperty -Path 'HKCU:\Keyboard Layout\Preload'

New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
Set-ItemProperty -Path 'HKU:\.DEFAULT\Keyboard Layout\Preload' -Name 1 -Value 00000409
Set-ItemProperty -Path 'HKU:\.DEFAULT\Keyboard Layout\Preload' -Name 2 -Value 00000419
Get-ItemProperty -Path 'HKU:\.DEFAULT\Keyboard Layout\Preload'
Write-Host "Keyboard Layout Done" -ForegroundColor Green
Write-Log "Keyboard Layout Done"

### Telnet Client
dism /online /Enable-Feature /FeatureName:TelnetClient
# For Windows Server
# Install-WindowsFeature -name "Telnet-Client"
Write-Host "Telnet Client Installed " -ForegroundColor Green
Write-Log "Telnet Client Installed "

# Disable Hibernation 
powercfg -h off
Write-Host "Hibernation Disabled" -ForegroundColor Green
Write-Log "Hibernation Disabled"