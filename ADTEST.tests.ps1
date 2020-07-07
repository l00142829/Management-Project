
 
$myDomain = Get-ADDomain
$DomainControllers = $myDomain.ReplicaDirectoryServers
$GlobalCatalogServers = (Get-ADForest).GlobalCatalogs
 
Write-Host "Testing AD Domain $($myDomain.Name)" -ForegroundColor Cyan
Foreach ($DC in $DomainControllers) {
 
    Describe $DC {
 
        Context Network {
            It "Should respond to a ping" {
                Test-Connection -ComputerName $DC -Count 2 -Quiet | Should Be $True
            }
 
          
            $ports = 53,389,445,5985,9389
            foreach ($port in $ports) {
                It "Port $port should be open" {
                #timeout is 2 seconds
                [system.net.sockets.tcpclient]::new().ConnectAsync($DC,$port).Wait(2000) | Should Be $True
                }
            }
 
           
            if ($GlobalCatalogServers -contains $DC) {
                It "Should be a global catalog server" {
                    [system.net.sockets.tcpclient]::new().ConnectAsync($DC,3268).Wait(2000) | Should Be $True
                }
            }
            
            
            It "should resolve the domain name" {
             (Resolve-DnsName -Name FRANKIE.local -DnsOnly -NoHostsFile | Measure-Object).Count | Should Be $DomainControllers.count
            }
        } 
    
        Context Services {
            $services = "ADWS","DNS","Netlogon","KDC"
            foreach ($service in $services) {
                It "$Service service should be running" {
                    (Get-Service -Name $Service -ComputerName $DC).Status | Should Be 'Running'
                }
            }
 
        } 
 
        Context Disk {
            $disk = Get-WmiObject -Class Win32_logicaldisk -filter "DeviceID='c:'" -ComputerName $DC
            It "Should have at least 20% free space on C:" {
                ($disk.freespace/$disk.size)*100 | Should BeGreaterThan 20
            }
            $log = Get-WmiObject -Class win32_nteventlogfile -filter "logfilename = 'security'" -ComputerName $DC
            It "Should have at least 10% free space in Security log" {
                ($log.filesize/$log.maxfilesize)*100 | Should BeLessThan 90
            }
        }
    } 
 
} 
 
Describe "Active Directory" {
 
    It "Domain Admins should have 1 member" {
        (Get-ADGroupMember -Identity "Domain Admins" | Measure-Object).Count | Should Be 5
    }
    
    It "Enterprise Admins should have 1 member" {
        (Get-ADGroupMember -Identity "Enterprise Admins" | Measure-Object).Count | Should Be 1
    }
 
    It "The Administrator account should be enabled" {
        (Get-ADUser -Identity Administrator).Enabled | Should Be $False
    }
 
    It "The PDC emulator should be $($myDomain.PDCEmulator)" {
      (Get-WMIObject -Class Win32_ComputerSystem -ComputerName $myDomain.PDCEmulator).Roles -contains "Primary_Domain_Controller" | Should Be $True
    }
}