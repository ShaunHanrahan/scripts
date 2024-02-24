Function Get-DHCPAllocatableIPAddresses {
    param (
        [Parameter(Mandatory=$true)]
        [Int32] $dhcpServerIP
    )

    # Get all scopes from the DHCP server
    $scopes = Get-DhcpServerv4Scope -ComputerName $dhcpServerIP

    # Iterate over each scope and calculate the total number of allocatable IPs
    foreach ($scope in $scopes) {
        $startIP = [System.Net.IPAddress]::Parse($scope.StartRange).GetAddressBytes()
        [Array]::Reverse($startIP)
        $startIP = [System.BitConverter]::ToUInt32($startIP, 0)
        
        $endIP = [System.Net.IPAddress]::Parse($scope.EndRange).GetAddressBytes()
        [Array]::Reverse($endIP)
        $endIP = [System.BitConverter]::ToUInt32($endIP, 0)
        
        $totalIPs = $endIP - $startIP + 1
        Write-Output "Scope $($scope.Name) has a total of $totalIPs allocatable IP addresses"
    }

}