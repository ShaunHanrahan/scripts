<#
.SYNOPSIS
    Fulfill the termination process for a user
.DESCRIPTION
    Run a series of commands to unassign the user's license, disable in AD,
    remove from any groups, and finally disable the user
.NOTES
    Version:       1.0
    Author:        Bryan Jones
    Creation Date: October 28, 2022
    Revision Date: October 28,, 2022
.EXAMPLE
    powershell.exe -path "<full path to file>.ps1"
#>

function Obtain-Details {
    param (
        [Parameter(Mandatory)]
        [string] $RemoveUserLicense,
        [string] $DisableUser,
        [string] $,
    )
    