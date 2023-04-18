$viserver = 'vcenter-01.domain.local'

$Scriptpath = Split-Path $MyInvocation.MyCommand.path
$user = "robot@vsphere.local"
$pscred = $Scriptpath+"\pscred-robot.txt"
#$pscred = "C:\Scripts\CustomAttributes\pscred-robot.txt"
$pass = get-content $pscred | convertto-securestring -Key(1..24) 
$pass.Makereadonly()
$cred = New-Object System.Management.Automation.PsCredential $user, $pass


#  Write-Log Function
function Write-Log
{
Param (
[string]$LogString)
[string]$fLogN = 'log.txt'
$LogPath = $Scriptpath
$LogFile = $LogPath + "\" +  $fLogN
If (!(Test-Path $LogFile)) {md $LogPath; New-Item -path $LogPath -name $fLogN -itemType File}
$Stamp = (Get-Date).toString("dd.MM.yyyy  HH:mm:ss")
$LogMessage = "$Stamp   $LogString"
Add-content $LogFile -value $LogMessage -Encoding UTF8
}

Connect-VIServer $viserver -Credential $cred -ErrorAction Stop

    If (-NOT (Get-CustomAttribute "CreatedBy" -ea silentlycontinue)) {
        Write-Log "Creating 'CreatedBy' attribute"
        New-CustomAttribute -Name "CreatedBy" -TargetType VirtualMachine
        }

    If (-NOT (Get-CustomAttribute "Owner" -ea silentlycontinue)) {
        Write-Log "Creating 'Owner' attribute"
        New-CustomAttribute -Name "Owner" -TargetType VirtualMachine
        }

    If (-NOT (Get-CustomAttribute "Function" -ea silentlycontinue)) {
        Write-Log "Creating 'Function' attribute"
        New-CustomAttribute -Name "Function" -TargetType VirtualMachine
        }

    If (-NOT (Get-CustomAttribute "Role" -ea silentlycontinue)) {
        Write-Log "Creating 'Role' attribute"
        New-CustomAttribute -Name "Role" -TargetType VirtualMachine
        }

    If (-NOT (Get-CustomAttribute "CreatedOn" -ea silentlycontinue)) {
        Write-Log "Creating 'CreatedOn' attribute"
        New-CustomAttribute -Name "CreatedOn" -TargetType VirtualMachine
        }

    Try {        
        $vms = Get-VM
        }
    Catch {
        Write-Warning "$($Error[0])"
        Write-Log "$($Error[0])"
        Break
        }

    ForEach ($vm in $vms) {
        If (-NOT $vm.CustomFields['CreatedBy']) {
             Write-Log "Looking for creator of $($vm.name)"
            Try {
                $event = $vm | Get-VIEvent -MaxSamples 500000 -Types Info | Where {
                    $_.GetType().Name -eq "VmBeingDeployedEvent" -OR $_.Gettype().Name -eq "VmCreatedEvent" -or $_.Gettype().Name -eq "VmRegisteredEvent"`
                     -or $_.Gettype().Name -eq "VmClonedEvent"
                    } 
                If (($event | Measure-Object).Count -eq 0) {
                    $username = ""
                    $created = ""
                    } 
                Else {
                    If ([system.string]::IsNullOrEmpty($event.username)) {
                        $username = ""
                        } 
                    Else {
                        $username = $event.username
                        }
                    $created = $event.CreatedTime
                    } 
                 Write-Log "Updating $($vm.name) attributes"
                $VM | Set-Annotation -CustomAttribute "CreatedBy" -Value $username | Out-Null
                $VM | Set-Annotation -CustomAttribute "CreatedOn" -Value $created | Out-Null
                }
            Catch {
                Write-Warning "$($Error[0])"
                Write-Log "$($Error[0])"
                Return
                }
            } 
        } 
   

Disconnect-VIServer $viserver -Confirm:$False

