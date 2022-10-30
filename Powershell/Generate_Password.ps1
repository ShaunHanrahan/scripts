<#
.SYNOPSIS
    Password Generator for local use, not finished!
.DESCRIPTION
.NOTES
    Version:       1.0
    Author:        Bryan Jones
    Creation Date: October 28, 2022
    Revision Date: October 28,, 2022
.EXAMPLE
    powershell.exe -path "<full path to file>.ps1"
#>

function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length,
        [int] $amountOfNonAlphanumeric
    )

    Add-Type -AssemblyName 'System.Web'
    return [System.Web.Security.Membership]::GeneratePassword($length, $amountOfNonAlphanumeric)
}
$CreatePass = Get-RandomPassword -length 10 -amountOfNonAlphanumeric 2
Write-Host $CreatePass