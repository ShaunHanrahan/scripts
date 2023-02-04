<#
.SYNOPSIS
    Compare users in AAD within a group to users found in AD Group 
.DESCRIPTION
    Get a list of users from Azure AD, save to a var and proceed
    to query a on-prem AD group that contains familiar users.
    Good for checking if a user found in AAD is within a local
    AD group.
.NOTES
    Version:       1.0
    Author:        Bryan Jones
    Creation Date: October 30, 2022
    Revision Date: October 30, 2022
.EXAMPLE
    powershell.exe -path "<full path to file>.ps1"
#>

$cred = Get-Credential "AAD@domain.com" 

# Connecting to the microsoft service
Connect-MsolService -Credential $cred

# Group to query
$ADGroup = "O365_G3"

# Get all Licensed users in Microsoft 365
# Additionally, we need to change the Header name to 'Name'
$msolUsers = Get-MsolUser -EnabledFilter EnabledOnly | Where-Object {($_.licenses).AccountSkuId -eq 'tenantName:ENTERPRISEPACK_GOV'} | Select-Object @{N='Name';E={$_.DisplayName}} 

# Get all users within the AD Group
$O365Members = Get-ADGroupMember -Identity $ADGroup | Select-Object Name

# Compare both Msol Users and the users in the AD Group
$objects = @{
  ReferenceObject = $msolUsers
  DifferenceObject = $O365Members
}

Compare-Object @objects -Property Name -IncludeEqual

