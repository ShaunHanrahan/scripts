<#
.SYNOPSIS
    Check if a list of users from a csv are in your AD environment
.DESCRIPTION
    Checks for a qualified .csv containing a list users then
    query your AD environment to check if the user is in AD.
.NOTES
    Version:       1.0
    Author:        Bryan Jones
    Creation Date: October 27, 2022
    Revision Date: October 27, 2022
.EXAMPLE
    powershell.exe -path "<full path to file>.ps1"
#>

# Get all users within the AD Group
$O365Members = Get-ADGroupMember -Identity O365_G3 | Select-Object Name 
function Get-CSVPath {
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )
    
    # Check the validity of the file is tested 
    If (-not(Test-Path -Path "$Path")) {

        # Prompt that the user does not exist
        Write-Host "The file [$Path] does not exist"

    } else {
        Import-Csv -Path $Path | ForEach-Object {
            $GetTheUsername = '{0}{1}' -f $_.GivenName.Substring(0,1).ToLower(),$_.Surname.ToLower()
            $script:ADUser = Get-ADUser -Filter "Name -Like '$GetTheUsername'" -Properties Name 

        }

        $objects = @{
            ReferenceObject = $ADUser.Name
            DifferenceObject = $O365Members.Name
        }
    
        Compare-Object @objects -Property Name -IncludeEqual

    }
}