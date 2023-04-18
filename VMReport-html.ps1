
$viserver = 'vcenter-01.domain.local'

$Scriptpath = Split-Path $MyInvocation.MyCommand.path
$user = "reporter@vsphere.local"
$pscred = $Scriptpath+"\pscred-reporter.txt"
#$pscred = "C:\Scripts\vmreport\pscred-reporter.txt"
[Byte[]] $key = (1..24)
$pass = get-content $pscred | convertto-securestring -Key $key 
$pass.Makereadonly()
$cred = New-Object System.Management.Automation.PsCredential $user, $pass

Connect-VIServer $viserver -Credential $cred -ErrorAction Stop

$HTMLPath = "C:\inetpub\wwwroot\vmreport\index.html"

Clear-Host
$AllVMCount = 0
$AllCPU = 0
$AllMemorySet = 0
$Table = @()
$Report = @()
$date = Get-Date -Format "dd.MM.yyyy HH:mm"

# VMHostInfo

$VMHostlist = Get-VMHost -State Connected| sort-object | select name -Unique
    
    foreach($VMHost in $VMHostList.name) {
    $VMHostTable = @()
    Write-Host "`n----------- Server: $VMHost -----------"
    $esxi = get-vmhost $vmhost
    $model = $esxi.Manufacturer +" "+ $esxi.Model

    $CpuMhzTotal = $esxi.CpuTotalMhz
    $CpuMhzUsage = $esxi.CpuUsageMhz
    $CPUUsagePercent = [math]::Round(100 * $CpuMhzUsage / $CpuMhzTotal)
    $HostTotalMem = [math]::Round($esxi.MemoryTotalGB)
    $HostUsageMem = [math]::Round($esxi.MemoryUsageGB)
    $HostUsagePercent = [math]::Round(100 * $HostUsageMem / $HostTotalMem)
    
    $HostReport = [PSCustomObject] @{
        "Name" = $esxi
        "Model" =  $model
        "CPU " = $esxi.ProcessorType
        "CPU Cores" = $esxi.NumCpu
        "CPU Threads " = $esxi.NumCpu * 2
        "CPU Total MHz" = $CpuMhzTotal
        "CPU Usage MHz" = $CpuMhzUsage
        "CPU Usage %" = $CPUUsagePercent
        "Memory Total Gb" = $HostTotalMem
        "Memory Usage Gb" = $HostUsageMem
        "Memory Usage %" = $HostUsagePercent

        } 
    $VMHostTable += $HostReport
    }
    $Report += $VMHostTable |ConvertTo-HTML -Fragment -PreContent "<h3>VMHost information</h3>" | Out-String 

# Datastores Info
    
$DataStores = Get-Datastore | where { (($Datastore.Name -notlike "*ISO*") -and ($_.State -ne "Maintenance")) }
foreach ($Storage in $DataStores) 
    {
    $DSTable = @()
    $DSName = (Get-Datastore $Storage).name
    $StorageTotal = [math]::Round($Storage.CapacityGB )
    $StorageFree =  [math]::Round($Storage.FreeSpaceGB)
    $StoragUsagePercent = [math]::Round(100 * ($StorageTotal - $StorageFree) / $StorageTotal)
    $StorageUncommitted = [math]::Round(($Storage.ExtensionData.Summary.Uncommitted)/1Gb)
    $ProbablyCommitmentSize = [math]::Round($StorageUncommitted / 10)
        
    $DSReport = [PSCustomObject] @{
        "Name" = $DSName
        "Storage Total Gb" = $StorageTotal
        "Storage Free Gb" = $StorageFree
        "Storage Usage %" = $StoragUsagePercent
        "Uncommitted Gb" = $StorageUncommitted
        "Probably Uncommitted Allocation (10%) GB"= $ProbablyCommitmentSize
        }
    $DSTable += $DSReport
    }

    $Report += $DSTable | ConvertTo-HTML -Fragment -PreContent "<h3>Datastore Information</h3>" | Out-String
    
# Folders

$folders = get-folder -Type VM | Where-Object {($_.name -ne 'vm') -and ($_.name -ne 'prod')} | sort

Foreach  ($folder in $folders) 
    {
    $FolderSummary = @()
    $VMTable = @()
    $FolderCPU = 0
    $FolderMemorySet = 0
    $FolderMemoryUse = 0
    $FolderStorageUse = 0
    
    Write-Host "`n----------- Папка: $folder -----------"
    
    $vms = (Get-VM -Location $folder -NoRecursion) | sort
        # Foreach VM
        Foreach ($vm in $vms)  
        {
        $vmname = $VM.name 
        $vmHostName = $vm.Guest.HostName
        $NumCPU = $vm.NumCpu
        
        $MemorySet = $vm.MemoryGB
        $MemoryUse = ($vm | get-view).summary.QuickStats.GuestMemoryUsage
        $MemoryUseGB = [math]::Round($MemoryUse/1024,2)
        
        $StorageUse = [math]::Round($VM.UsedSpaceGB)
        $ProvisionedSpace = [math]::round($VM.ProvisionedSpaceGB)
                
        # CustomAttributes
        $Role = ($vm| Get-Annotation -CustomAttribute "Role").value
        $Function = ($vm| Get-Annotation -CustomAttribute "Function").value
        $Owner = ($vm| Get-Annotation -CustomAttribute "Owner").value
                
        # PowerState
        if ($VM.PowerState -eq "PoweredOn") {$power="ON"}
        elseif ($VM.PowerState -eq "PoweredOff") {$power=""}
        else {$power="n/a"}

        # Autostart
        if (($vm|Get-VMStartPolicy).StartAction -eq "PowerOn") {$autostart = "Yes"}
        else {$autostart = ""}

        # VMTools version
        $VMTools1 = ($VM | get-view).config.tools.ToolsVersion
        $VMTools2 = $vm.Guest.ToolsVersion
            if ($VMTools1 -eq 0) {$VMTools = "not installed"}
            else {$VMTools = "$VMTools1" + ' ('+"$VMTools2"+')'}

        #$ipaddr=$vm.guest.net.ipaddress
        $ips = $vm.Guest.IPAddress -join '; '

        # OS
        $OS = $VM.Guest.OSFullName
        if ($OS -match "Microsoft") {$OS = $OS.Replace('Microsoft ','')}
        if ($OS -match "(64-bit)") {$OS = $OS.Replace(' (64-bit)','')}
                                               
        $VMReport = [PSCustomObject] @{
            "VM" = $vmname 
            "HostName" = $vmHostName
            "CPU" = $NumCPU
            "Memory(Gb)" = $MemorySet
            "MemoryUsed(Gb)" = $MemoryUseGB
            "StorageUsed(Gb)" = $StorageUse
            "MaxVMSize(Gb)" = $ProvisionedSpace
            "IP" = $ips
            "OS" = $OS
            "Power" = $power
            "VMTools" = $VMTools
            "Owner" = $Owner
            "Functional" = $Function
            "Autostart" = $autostart
            }

        Write-Host $vm.name 
 
        $FolderCPU += $NumCPU
        $FolderMemorySet += $MemorySet
        $FolderMemoryUse += $MemoryUse
        $FolderStorageUse += $StorageUse
        
        $VMTable += $VMReport  

        } # Foreach VM end

        $FolderMemoryUseGB = [math]::Round($FolderMemoryUse/1024,2)
        $Report += $VMTable |ConvertTo-HTML -Fragment -PreContent "<h3>Folder: $folder</h3>" | Out-String 

    Write-Host "-----------" 
    Write-Host "Всего ВМ:" $vms.count

    $FolderSummary = [PSCustomObject] @{
        "Folder Summary" = $folder
        "VM Count" = $vms.count
        "CPU Cores Used" = $FolderCPU
        "Memory Set Summary (GB)" = $FolderMemorySet
        "Memory Used Summary(GB)" = $FolderMemoryUseGb
        "Storage Used Summary(Gb)" = $FolderStorageUse
        }

    $AllVMCount += $vms.count
    $AllCPU += $FolderCPU
    #$AllMemorySet += $FolderMemorySet
    
    $Report += $FolderSummary | ConvertTo-HTML -Fragment | Out-String
    } # Foreach  folder end

# PoweredOn VM Summary

$PoweredOnVM = get-vm | where PowerState -eq "PoweredOn"
$PoweredOnVMcount = $PoweredOnVM.count
$PoweredOnCPUCoresUsed = ($PoweredOnVM | measure-object -Property numcpu -sum).Sum
$PoweredOnMemorySet = ($PoweredOnVM | measure-object -Property MemoryGB -sum).Sum
$PoweredOnStorageUse = [math]::Round(($PoweredOnVM | measure-object -Property UsedSpaceGB -sum).Sum)

$PoweredOnSummary = [PSCustomObject] @{
        
        "PoweredOn VM" = $PoweredOnVMcount
        "CPU Cores Used" = $PoweredOnCPUCoresUsed
        "PoweredOn VM Memory Set(GB)" = "{0:N0}" -f $PoweredOnMemorySet
        "PoweredOn Storage Used Summary(Gb)" = $PoweredOnStorageUse
}

$Report += $PoweredOnSummary | ConvertTo-HTML -Fragment -PreContent "<h3>Powered On VM Summary</h3>" | Out-String

# Powered Off VM Summary

$PoweredOffVM = get-vm | where PowerState -eq "PoweredOff"
$PoweredOffVMcount = $PoweredOffVM.count
$PoweredOffCPUCoresUsed = ($PoweredOffVM | measure-object -Property numcpu -sum).Sum
$PoweredOffMemorySet = ($PoweredOffVM | measure-object -Property MemoryGB -sum).Sum
$PoweredOffStorageUse = [math]::Round(($PoweredOffVM | measure-object -Property UsedSpaceGB -sum).Sum)

$PoweredOffSummary = [PSCustomObject] @{
        
        "PoweredOff VM" = $PoweredOffVMcount
        "CPU Cores Assigned" = $PoweredOffCPUCoresUsed
        "PoweredOff VM Memory Set(GB)" = "{0:N0}" -f $PoweredOffMemorySet
        "PoweredOff Storage Used Summary(Gb)" = $PoweredOffStorageUse
}

$Report += $PoweredOffSummary | ConvertTo-HTML -Fragment -PreContent "<h3>Powered Off VM Summary</h3>" | Out-String


# Overall VM Summary

$CPUCoresAssigned = (get-vm | measure-object -Property numcpu -sum).Sum
$OverAllVMCount = (get-vm).count
$AllMemorySet = (get-vm | measure-object -Property MemoryGB -sum).Sum
$StorageUsedSummary = [math]::Round((get-vm | measure-object -Property UsedSpaceGB -sum).Sum)

Write-Host "`n---------------------------------------" 
Write-Host "Всего папок: "$folders.count""
Write-Host "Всего ВМ во всех папках: $OverAllVMCount"

$Overall = [PSCustomObject] @{
        "Folders" = $folders.count
        "Overall VM Count" = $OverAllVMCount
        "Powered On VM" = $PoweredOnVMcount
        "Powered Off VM" = $PoweredOffVMcount
        "CPU Cores Assigned" = $CPUCoresAssigned
        "CPU Cores Used" = $PoweredOnCPUCoresUsed
        "Memory Set(GB)" = "{0:N0}" -f $AllMemorySet
        "Storage Used Summary(Gb)" = $StorageUsedSummary
}

$Report += $Overall | ConvertTo-HTML -Fragment -PreContent "<h3>Overall Summary</h3>" | Out-String

$head = @"
<style>
body {background-color: #9AB2C7;font-family: Arial; font-size: 9pt;}
h1 {color: 	#080D07; text-align: center;font-size: 40px;display: block;font-family: "Arial Black", Times, serif;}
h2 {color: 	#080D07; font-family: "Arial Black"}
TABLE {border-style: solid;border-color: black;}
TH {border-style: solid;border-color: Black;background-color: #4682B4;}
TD {background-color:#DCDCDC}
table {border-collapse: collapse;width: 100%;}
table, th, td {border: 1px solid black;height: 25px;text-align: Center;font-weight: bold;}
</style>
"@


ConvertTo-HTML -head $head -PostContent $Report -Body "<h2>VM Inventory for $VIserver ($date)</h2>" | Set-Content -Path $HTMLPath -Encoding UTF8 -ErrorAction Stop

# Отключение от vCenter / vCenter Disconnonect
Disconnect-VIServer $viserver -Confirm:$False
