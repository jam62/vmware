
$viserver = 'vcenter-01.domain.local'

$Scriptpath = Split-Path $MyInvocation.MyCommand.path
$user = "reporter@vsphere.local"
$pscred = $Scriptpath+"\pscred-reporter.txt"
#$pscred = "C:\Scripts\vmreportfull\pscred-reporter.txt"
[Byte[]] $key = (1..24)
$pass = get-content $pscred | convertto-securestring -Key $key 
$pass.Makereadonly()
$cred = New-Object System.Management.Automation.PsCredential $user, $pass

Connect-VIServer $viserver -Credential $cred -ErrorAction Stop

$HTMLPath = "C:\inetpub\wwwroot\vmreportfull\index.html"

# Функция записи лога
function Write-Log
{
Param ([string]$LogString )
$fLogN = 'log.txt'
$LogPath = $Scriptpath
$LogFile = $LogPath + "\" +  $fLogN
If (!(Test-Path $LogFile)) {md $LogPath; New-Item -path $LogPath -name $fLogN -itemType File}
$Stamp = (Get-Date).toString("dd.MM.yyyy  HH:mm:ss")
$LogMessage = "$Stamp   $LogString"
Add-content $LogFile -value $LogMessage -Encoding UTF8
}

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
    Write-Host "`n----------- Сервер: $VMWHost -----------"
 #   Write-Log  "----------- Сервер: $VMWHost -----------"     
    $esxi = get-vmhost $vmhost
    $model = $esxi.Manufacturer +" "+ $esxi.Model

    $CpuMhzTotal = $esxi.CpuTotalMhz
    $CpuMhzUsage = $esxi.CpuUsageMhz
    $CPUUsagePercent = [math]::Round(100 * $CpuMhzUsage / $CpuMhzTotal)
    $HostTotalMem = [math]::Round($esxi.MemoryTotalGB)
    $HostUsageMem = [math]::Round($esxi.MemoryUsageGB)
    $HostUsagePercent = [math]::Round(100 * $HostUsageMem / $HostTotalMem)
    
    $DataStores = Get-Datastore -VMHost $VMHost | where { (($Datastore.Name -notlike "*ISO*") -and ($_.State -ne "Maintenance")) }
    $Storage = $DataStores | Sort-Object FreeSpaceGB -Descending | Select Name,FreeSpaceGB,CapacityGB -First 1
    $StorageTotal = [math]::Round($Storage.CapacityGB )
    $StorageFree =  [math]::Round($Storage.FreeSpaceGB)
    $StoragUsagePercent = [math]::Round(100 * ($StorageTotal - $StorageFree) / $StorageTotal)
                                                      
    $HostReport = [PSCustomObject] @{
        "Name" = $esxi
        "Model" =  $model
        "CPU " = $esxi.ProcessorType
        "CPU Cores" = $esxi.NumCpu
        "CPU Total MHz" = $CpuMhzTotal
        "CPU Usage MHz" = $CpuMhzUsage
        "CPU Usage %" = $CPUUsagePercent
        "Memory Total Gb" = $HostTotalMem
        "Memory Usage Gb" = $HostUsageMem
        "Memory Usage %" = $HostUsagePercent
        "Storage Total Gb" = $StorageTotal
        "Storage Free Gb" = $StorageFree
        "Storage Usage %" = $StoragUsagePercent
    } 
    $VMHostTable += $HostReport
    }
    $Report += $VMHostTable |ConvertTo-HTML -Fragment -PreContent "<h3>VMHost information</h3>" | Out-String 

$folders = get-folder -Type VM | Where-Object {($_.name -ne 'vm') -and ($_.name -ne 'prod')} | sort

Foreach  ($folder in $folders) 
    {
    $FolderSummary = @()
    $VMTable = @()
    $FolderCPU = 0
    $FolderMemorySet = 0
    $FolderStorageUse = 0
    Write-Host "`n----------- Папка: $folder -----------"
    Write-Log  "----------- Папка: $folder -----------"          
    $vms = (Get-VM -Location $folder) |sort
        # Foreach VM
        Foreach ($vm in $vms)  
        {
        $vmname = $VM.name 
        $vmHostName = $vm.Guest.HostName
        $NumCPU = $vm.NumCpu
        $MemorySet = $vm.MemoryGB
        #$MemoryUse = [math]::Round(($vm | get-view).summary.QuickStats.GuestMemoryUsage/1024,2)
        $StorageUse = [math]::Round($VM.UsedSpaceGB)
                
        # CustomAttributes
        $Role = ($vm| Get-Annotation -CustomAttribute "Role").value
        $Function = ($vm| Get-Annotation -CustomAttribute "Function").value
        $Owner = ($vm| Get-Annotation -CustomAttribute "Owner").value
                
        # PowerState
        if ($VM.PowerState -eq "PoweredOn") {$power="ON"}
        elseif ($VM.PowerState -eq "PoweredOff") {$power="OFF"}
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
            #"Folder" = ''
            "VM" = $vmname 
            "HostName" = $vmHostName
            "CPU" = $NumCPU
            "Memory(Gb)" = $MemorySet
            #"MemoryUse(Gb)" = $MemoryUse
            "Storage Used(Gb)" = $StorageUse
            "IP" = $ips
            "OS" = $OS
            "Power" = $power
            "VMTools" = $VMTools
            "Owner" = $Owner
            "Function" = $Function
            "Autostart" = $autostart
            }

        Write-Host $vm.name 
        Write-Log "$vm"
        $FolderCPU += $NumCPU
        $FolderMemorySet += $MemorySet
        $FolderMemoryUse += $MemoryUse
        $FolderStorageUse += $StorageUse
    
        $VMTable += $VMReport  

        } # Foreach VM end

        $Report += $VMTable |ConvertTo-HTML -Fragment -PreContent "<h3>Folder: $folder</h3>" | Out-String 

    Write-Host "-----------" 
    Write-Log  "-----------" 
    Write-Host "Всего ВМ:" $vms.count
    Write-Log "Всего ВМ:"
    Write-Log $vms.count
    $FolderSummary = [PSCustomObject] @{
        "Folder Summary" = $folder
        "VM Count" = $vms.count
        "CPU Cores Used" = $FolderCPU
        "Memory(GB) Summary" = $FolderMemorySet
        "Storage Used(Gb) Summary" = $FolderStorageUse
        #"Power" = ''
    }

    $AllVMCount += $vms.count
    $AllCPU += $FolderCPU
    $AllMemorySet += $FolderMemorySet

    $Report += $FolderSummary | ConvertTo-HTML -Fragment | Out-String
    } # Foreach  folder end
 
Write-Host "`n---------------------------------------" 
Write-Log "---------------------------------------" 
Write-Host "Всего папок: "$folders.count""
Write-Log "Всего папок:"
Write-Log $folders.count
Write-Host "Всего ВМ во всех папках: $AllVMCount"
Write-Log "Всего ВМ во всех папках:"
Write-Log $AllVMCount

$Overall = [PSCustomObject] @{
        "Folders" =$folders.count
        "Overall VM Count" = $AllVMCount
        "CPU Cores Used" = $AllCPU
        "Memory(GB) Summary" = $AllMemorySet
        "Storage Used(Gb) Summary" = $FolderStorageUse
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

#Load report in default browser
#Invoke-Item $HTMLPath

# Отключение от vCenter / vCenter Disconnonect
Disconnect-VIServer $viserver -Confirm:$False
