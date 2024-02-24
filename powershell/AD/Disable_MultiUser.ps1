<#
.SYNOPSIS
    Fulfill the termination process for a user
.DESCRIPTION
    Run a series of commands to unassign the Users's license, disable in AD,
    remove from any groups, and finally disable the user
.NOTES
    Version:       1.0
    Author:        Bryan Jones
    Creation Date: October 28, 2022
    Revision Date: October 28,, 2022
.EXAMPLE
    powershell.exe -path "<full path to file>.ps1"
#>

# Obtain creds
$cred = Get-Credential "username"

# Connecting to the microsoft service
Connect-MsolService -Credential $cred
 
$tenantName = "domain"

# The AD Group that gets licensing 
$ADGroup = "O365_G3"

# The OU that the user(s) will be placed 
$Disabled_OU = "OU=_inactive,OU=Domain Users,DC=domain,DC=local"

# List of users; can be replaced with a .csv file
$DisableList = @('lealey')

foreach ($Users in $DisableList){
    $GetUserProp = Get-ADUser -Identity $Users -Properties Name, SAMAccountName, distinguishedName
    Set-ADUser -Identity $GetUserProp.SAMAccountName -Enabled:$false

    # Remove the license for the user
    # Depending on your environment, you can disregard this
    Set-MsolUserLicense -UserPrincipalName $Users@opalockafl.gov -RemoveLicenses "$tenantName":ENTERPRISEPACK_GOV

    # Remove the user(s) from the AD Group
    # If the user is already found in the OU, throw a custom error
    try {
        Remove-ADGroupMember -Identity $ADGroup -Members $GetUserProp.SAMAccountName -Confirm:$false 
    }
    catch {
        throw "User is not in the group!"
    }

    # Move the user to a disabled OU
    Move-ADObject -Identity $GetUserProp.distinguishedName -TargetPath $Disabled_OU
}

