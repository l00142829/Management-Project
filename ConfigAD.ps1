Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

Import-Module ActiveDirectory

$Date = Get-Date -f yyyyMMddhhmm
$wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$( (Get-WmiObject Win32_ComputerSystem).Domain)'"
$DN = $wmiDomain.DomainName
$DomainDN = Get-ADDomain -Current LocalComputer | Select-Object -ExpandProperty DistinguishedName


auditpol /set /subcategory:"directory service changes" /success:enable
Enable-ADOptionalFeature 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target $env:USERDNSDOMAIN -Confirm:$false
Add-KDSRootKey -EffectiveTime ((get-date).addhours(-10))  


$DefaultSiteRename = Read-Host -Prompt "Provide a valid name for the default AD Site, Default-First-Site-Name: <NoSpaces>"
Get-ADObject -SearchBase (Get-ADRootDSE).ConfigurationNamingContext -filter "objectclass -eq 'site'" | Set-ADObject -DisplayName $DefaultSiteRename
Get-ADObject -SearchBase (Get-ADRootDSE).ConfigurationNamingContext -filter "objectclass -eq 'site'" | Rename-ADObject -NewName $DefaultSiteRename


New-ADOrganizationalUnit -Name "$DN" -Path $DomainDN
New-ADOrganizationalUnit -Name "Admin Users" -Path "OU=$DN,$DomainDN"
New-ADOrganizationalUnit -Name "Network Devices" -Path "OU=$DN,$DomainDN"
New-ADOrganizationalUnit -Name "Service Accounts" -Path "OU=$DN,$DomainDN"
New-ADOrganizationalUnit -Name "Employees" -Path "OU=$DN,$DomainDN"
New-ADOrganizationalUnit -Name "Ex Employees" -Path "OU=Employees,OU=$DN,$DomainDN"



New-ADGroup -Name "Employees_$DN" -GroupCategory Security -GroupScope Global -Description "ALL employee accounts" -path "OU=Employees,OU=$DN,$DomainDN"
New-ADGroup -Name "Service Accounts_$DN" -GroupCategory Security -GroupScope Global -Description "ALL service accounts" -path "OU=Service Accounts,OU=$DN,$DomainDN"

New-ADServiceAccount -Name "DC-SchTsk" -DNSHostName "DC-SchTsk.$env:USERDNSDOMAIN" -PrincipalsAllowedToRetrieveManagedPassword "Domain Controllers","Domain Admins"
Install-ADServiceAccount -Identity "DC-SchTsk"
Test-ADServiceAccount -Identity "DC-SchTsk"

## MS Best Practices | -MinPasswordLength 14 -MaxPasswordAge "90.00:00:00" -MinPasswordAge "1.00:00:00" -PasswordHistoryCount 24 -LockoutThreshold 5 -LockoutDuration "0.00:60:00" -ComplexityEnabled $true 
## CIS | -MinPasswordLength 14 -MaxPasswordAge "60.00:00:00" -MinPasswordAge "1.00:00:00" -PasswordHistoryCount 24 -LockoutThreshold 5 -LockoutDuration "0.00:60:00" -ComplexityEnabled $true 
## NIST | -MinPasswordLength 8 -MaxPasswordAge "00.00:00:00" -MinPasswordAge "1.00:00:00" -PasswordHistoryCount 24 -LockoutThreshold 3 -ComplexityEnabled $false 
## HITRUST | -MinPasswordLength 8 -MaxPasswordAge "90.00:00:00" -MinPasswordAge "1.00:00:00" -PasswordHistoryCount 6 -LockoutThreshold 3 -LockoutDuration "0.03:00:00" -ComplexityEnabled $true #privileged accounts reset every 60 days


New-ADFineGrainedPasswordPolicy -Precedence 1 -Name PSO_desNOTexp -DisplayName PSO_desNOTexp -Description "PSO for accounts whose password does NOT expire" -ReversibleEncryptionEnabled $false -ProtectedFromAccidentalDeletion $true
Add-ADFineGrainedPasswordPolicySubject PSO_desNOTexp -Subjects "Employees_$DN"

New-ADFineGrainedPasswordPolicy -Precedence 5 -Name PSO_IncSec -DisplayName PSO_IncSec -Description "PSO for accounts that require a more strict password" -ReversibleEncryptionEnabled $false -ProtectedFromAccidentalDeletion $true
Add-ADFineGrainedPasswordPolicySubject PSO_IncSec -Subjects "Domain Admins"

New-ADFineGrainedPasswordPolicy -Precedence 10 -Name PSO_BasicSec -DisplayName PSO_BasicSec -Description "PSO for basic user accounts" -ReversibleEncryptionEnabled $false -ProtectedFromAccidentalDeletion $true
Add-ADFineGrainedPasswordPolicySubject PSO_BasicSec -Subjects "Service Accounts_$DN"











