<#
.SYNOPSIS
    Grab users from Azure AD with a qualified license and add them to a local group
.DESCRIPTION
    Get a list of users from Azure AD, save to a var and 
    proceed to add each user to a group in your AD environment. 
    This is useful for Local AD group based licensing.
.NOTES
    Version:       1.0
    Author:        Bryan Jones
    Creation Date: October 30, 2022
    Revision Date: October 30, 2022
.EXAMPLE
    powershell.exe -path "<full path to file>.ps1"
#>

$tenantName = "tenantName"

$msolUsers = Get-MsolUser -EnabledFilter EnabledOnly | Where-Object {($_.licenses).AccountSkuId -eq "'$tenantName':ENTERPRISEPACK_GOV"}

ForEach ($user in $msolUsers) {
  try {
    
    $ADUser = Get-ADUser -filter {UserPrincipalName -eq $user.UserPrincipalName} -ErrorAction stop
    Add-ADGroupMember -Identity O365_G3 -Members $ADUser -ErrorAction stop

    [PSCustomObject]@{
      UserPrincipalName = $user.UserPrincipalName
      Existing          = $false
    }
  }
  catch {
      [PSCustomObject]@{
      UserPrincipalName = $user.UserPrincipalName
      Existing          = $true
    }
  }
}