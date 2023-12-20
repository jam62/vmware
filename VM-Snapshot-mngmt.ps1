#
# Скрипт для создания/отката на нужный снапшот с предаврительным выключением ВМ и запуском после.
#

# Параметры запуска скрипта

param (
[string]$vmname,                                        # Имя ВМ
[string]$act,                                           # Действие со снапшотом
[string]$sname                                          # Имя снапшота
)

$Usage = 'VM-Snapshot-mngmt.ps1 -vmname "<Имя ВМ>" -act [new|revert] -sname "<Имя снапшота>"'
$example = 'VM-Snapshot-mngmt.ps1 -vm "VM-01" -act new -sname "Installed Software X"'


if (!$vmname) {
  write-host `n"Parameter vmname is required." -ForeGroundColor Red
  write-host `n"Необходимо указать обязательный параметр: -vmname." -ForeGroundColor Red
  write-host `n"Описание: $Usage" `n
  write-host "Пример: $example" `n
  exit
}

if (($act -ne "new") -and ($act -ne "revert")) {
  write-host `n"Parameter act is required." -ForeGroundColor Red
  write-host `n"Необходимо указать обязательный параметр: -act." -ForeGroundColor Red
  write-host `n"Описание: $Usage" `n
  write-host "Пример: $example" `n
  exit
}

if (!$sname) {
  write-host `n"Parameter sname is required." -ForeGroundColor Red
  write-host `n"Необходимо указать обязательный параметр: -snap." -ForeGroundColor Red
  write-host `n"Описание: $Usage" `n
  write-host "Пример: $example" `n
  exit
}

# Получаем системные переменные, чтобы очистить переменные скрипта в конце

$sysvars = get-variable | select -ExpandProperty name 
$sysvars += 'sysvar'

$vcName = "10.3.0.212"                                         # Адрес vCenter
$timeout = 180                                                 # Таймаут ожидания выключения ВМ в секундах
$stimeout = 90                                                 # Время ожидания готовности ВМ после включения

$Scriptpath = Split-Path $MyInvocation.MyCommand.path
$user = "robot@vsphere.local"
$pscred = $Scriptpath+"\pscred_robot.txt"
$pwd = get-content $pscred | convertto-securestring -Key(1..24) 
$pwd.Makereadonly()
$cred = New-Object System.Management.Automation.PsCredential $user, $pwd

# Подключение к vCenter / Connect to vCenter

$ErrorActionPreference = 'Stop'
try {
    Connect-VIServer $vcName -Credential $cred | Out-Null
    }
catch 
    {
    Write-host "Ошибка подключения" -ForegroundColor Red
    Break
    }
Write-Host "Сеанс подключения к $vcName"

# Проверка переменных / Check Variables

$vm = Get-VM $vmname -ErrorAction SilentlyContinue
If (!$vm) 
    {
    Write-Host "Виртуальная машина $vm не найдена" -ForegroundColor Red
    }

if (($act -eq "revert") -and (!(Get-Snapshot -VM $vmname -Name $sname -ErrorAction SilentlyContinue))) 
    {
    Write-Host `n"Снапшот не найдет." -ForeGroundColor Red
    Exit
    }


# Выключение ВМ. Сначала штатно гасим из ОС. Если за время $timeout ВМ не выключается, принудительно останавливаем ВМ.
$vm = Get-VM -Name $vmName
Try {
    if ($vm.PowerState -ne "PoweredOff")
        {
        Shutdown-VMGuest -VM $vmName -Confirm:$false
        Write-Host "Виртуальная машина $vmName выключается"
        $t = 0
        do {
            sleep 10
            $t+=10
            Write-Host -NoNewline "`r $t секунд"
            $vm = Get-VM -Name $vmName
#            $vm.PowerState
            }
        until(($vm.PowerState -eq 'PoweredOff') -or ($t -gt $timeout))
#        Write-Host "$t/$timeout сек." $vmName $vm.PowerState
        }
    $vm = Get-VM -Name $vmName
    if ($vm.PowerState -ne "PoweredOff")
        {
        Stop-VM $vmname -Confirm:$False -ErrorAction SilentlyContinue
        Write-Host "`nВиртуальная машина $vmName выключена принудительно" -ForegroundColor DarkYellow
        }
    else {Write-Host "`nВиртуальная машина $vmName выключена" -ForegroundColor Green}
    }
Catch
    {
    Disconnect-VIServer $vcName -Confirm:$False
    Get-Variable * | Where { $_.name  -notin $sysvars } | Remove-Variable -Force -ErrorAction SilentlyContinue
    throw $_
    }

# Создание снапшота
$vm = Get-VM -Name $vmName
if ($vm.PowerState -eq "PoweredOff") 
    { 
    If ($act -eq "new") 
        {
        If (Get-Snapshot -VM $vmname -Name $sname -ErrorAction SilentlyContinue) 
            {
            Write-Host "`nУдаляю старый снапшот $sname"
            Get-Snapshot -VM $vmname -Name $sname | Remove-Snapshot -Confirm:$False
            }
        Write-Host "`nСоздаю снапшот $sname"
        New-Snapshot -VM $vmname -Name $sname | Out-Null
        Write-Host "Снапшот $sname сохранен" -ForegroundColor Green
        }
    }

# Восстановление снапшота

If ($act -eq "revert") 
    {
    Write-Host "`nВосстанавливаю снапшот $sname"
    Set-VM -VM $vmname -SnapShot $sname -Confirm:$false | Out-Null
    Write-Host "`nСнапшот $sname развернут" -ForegroundColor Green 
    }

#Запуск ВМ.

Write-Host "Запускаю ВМ $vmname"
Start-VM $vmname | Out-Null

# Ожидаем загрузки ВМ
For ($s=$stimeout; $s -ge 0; $s--)
    {
    Write-Host -NoNewline "`r Готовность ВМ $vmname через: $s сек."
    Sleep 1
    }
Write-Host "`rВМ $vmname готова" -ForegroundColor Green

# Отключение от vCenter / vCenter Disconnonect
Write-Host "`r`n Отключаюсь от $vcName"
Disconnect-VIServer $vcName -Confirm:$False

# Прибиремся за собой / Clear variables
# Очистка переменных исключая системные
Write-Host "Очистка переменных"
Get-Variable * | Where { $_.name  -notin $sysvars } | Remove-Variable -Force -ErrorAction SilentlyContinue

