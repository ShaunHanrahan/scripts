param (
    [parameter(Mandatory=$true)]
    [string]$username,
    [parameter(Mandatory=$false)]
    [AllowEmptyString()]
    [string]$SetDefaultPass = $( "Welcome`$Date.Month" ),
    [AllowEmptyString()]
    [parameter(Mandatory=$false)]
    [string]$GetPass = $( $GeneratePass )

)

# Get the date
$Date = Get-Date
function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length,
        [int] $amountOfNonAlphanumeric = 1
    )
    Add-Type -AssemblyName 'System.Web'
    return [System.Web.Security.Membership]::GeneratePassword($length, $amountOfNonAlphanumeric)
}

If($PSBoundParameters.ContainsKey("DefaultPass")) {
    $GeneratePass = $SetDefaultPass
}
else {
    $GeneratePass = Get-RandomPassword -length 8 -amountOfNonAlphanumeric 2
}

# Generate the password for the user
$securedPass = ConvertTo-SecureString -String $GeneratePass -AsPlainText -Force     
Write-Output $GeneratePass

Set-ADAccountPassword -Identity $username -NewPassword $securedPass -Reset                             
Set-ADUser -Identity $username -ChangePasswordAtLogon $true