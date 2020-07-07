Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

Import-Module "Servermanager" 

$Param_Details = @{
    CreateDnsDelegation = $false
    DatabasePath = 'C:\Windows\NTDS'
    DomainMode = 'WinThreshold'
    DomainName = 'FRANKIE.local'
    DomainNetbiosName = 'FRANKIE'
    ForestMode = 'WinThreshold'
    InstallDns = $true
    LogPath = 'C:\Windows\NTDS'
    NoRebootOnCompletion = $false
    SafeModeAdministratorPassword = (ConvertTo-SecureString -String "Pa55w0rd" -AsPlainText -Force)
    SysvolPath = 'C:\Windows\SYSVOL'
    Force = $true
    
}


Get-NetAdapter
New-NetIPAddress -InterfaceIndex 10 -IPAddress 192.168.243.10 -DefaultGateway 192.168.243.2 -PrefixLength 24

Set-DNSClientServerAddress -InterfaceIndex 10 -ServerAddresses ('192.168.243.10','127.0.0.1')

Disable-NetAdapterBinding -Name 'Ethernet0' -ComponentID 'ms_tcpip6'

Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools
Install-WindowsFeature DNS -IncludeAllSubFeature -IncludeManagementTools


Import-Module ADDSDeployment
Import-Module DnsServer


Install-ADDSForest @Param_Details        

Rename-Computer -NewName "DC01" -force



 
