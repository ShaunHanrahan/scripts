<#
.SYNOPSIS
    Create a user then send an email using REST API
.DESCRIPTION
    Checks for a qualified .csv containing certain parameters that are needed 
    for the user creation to happen. Once the user is created, a log file is then
    created and an email is sent using REST API.
.NOTES
    Version:       1.0
    Author:        Bryan Jones
    Creation Date: October 1, 2022
    Revision Date: October 24, 2022
.EXAMPLE
    powershell.exe -path "<full path to file>.ps1"
#>

# The file containing the CSV
$inputFile = "\\path\to\csvfolder\*.csv"

# Location for outputted log file
$Logfile = "\\path\to\logfolder\UserCreationLogs.txt"

$CreateUserName = $null
$CreatePass      = $null

# Exchange Server to use
$exchangeServer = "exchangeServerName"

# Default email to be used
$DefaultEmail = "Default@email.com"

# Set the site location for the user provided from the .CSV
$SiteLocation = $null

# Set timer to give Exchange Server time to find the AD Object
$sleepTimer = 3

# Set account limit
$SAMLengthLimit = 15

# Localize our variables
$EmailToUse = $null
$script:supervisorEmail = $null
$script:TokenResponse =$null

# Optionally load the AD Module
function Load-Modules {
    # load AD module
    Try {
        Import-Module ActiveDirectory | Out-Null

    # Catch the error
    } Catch {
            Write-Warning "Encountered a problem importing AD module."
            Write-Host
            Read-Host "Press Enter to exit..."
        Exit
    }
}

# Generate a secured password
function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length,
        [int] $amountOfNonAlphanumeric
    )
    Add-Type -AssemblyName 'System.Web'
    return [System.Web.Security.Membership]::GeneratePassword($length, $amountOfNonAlphanumeric) 
}
function find-supervisor {

    # Get info from the supervisor
    $GetADUserManager = Get-ADUser -Filter { SamAccountName -Like $CreateUserName } -Properties Manager
    $SetADUserManager = $GetADUserManager.Manager
    $script:supervisorEmail  = Get-ADUser -Identity $SetADUserManager -Properties Mail | Select-Object Mail
    
    # Return the specified user mailbox
    return $script:supervisorEmail
 }


function Send-ToEmail {

    # Application (client) ID, tenant Name and secret
    $clientID = "clientID-string-here"
    $tenantName = "tenantName.onmicrosoft.com"
    $clientSecret = "client-secret-here"
    $resource = "https://graph.microsoft.com/"
    $apiUrl = "https://graph.microsoft.com/v1.0/users/user@domain.gov/sendMail"
    
    $ReqTokenBody = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        client_Id     = $clientID
        Client_Secret = $clientSecret
    } 

    $TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token" -Method POST -Body $ReqTokenBody

    $authHeaders = @{
    "Authorization" = "Bearer $($Tokenresponse.access_token)" 
    "Content-Type" = 'application/json'
    }
    
    # Greetings array
    $greetingsArray = @('Good morning','Good Afternoon','Good Evening')
    $time = Get-Date

    # Logic for which greeting to use from array
    If ( $time.Hour -gt 6 -and $time.Hour -le 12 ) {
        $greetings = $greetingsArray[0]
    }elseif ( $time.Hour -gt 12 -and $time.Hour -le 16 ) {
        $greetings = $greetingsArray[1]
    }elseif ( $time.Hour -gt 17 -and $time.Hour -le 24 ) {
        $greetings = $greetingsArray[2]
    }
    
    # If the supervisor variable is empty, use the default addr
    If ($null -eq $script:supervisorEmail.Mail) {

        Write-Warning "Either a manager was not provided or the specified manager does not have an email!"
        $EmailToUse = $DefaultEmail
    
    }else {
        $EmailToUse = $script:supervisorEmail.Mail
    }
    
    # The message content
    $body = @"
    {
    "Message": {
        "Subject": "NEW USER CREATED!",
        "importance":"High",
        "Body": {
        "ContentType": "HTML",
        "Content": "$greetings, the following user was created for: $displayName<br/>\n<br/>\nUsername: $CreateUserName<br/>\nPassword: $CreatePass"
        },
        "ToRecipients": [
        {
            "EmailAddress": {
            "Address": "$EmailToUse"
            }
        }
        ],
        "ccRecipients": [
        {
            "EmailAddress": {
            "Address": "$DefaultEmail"
            }
        }
        ]
    },
    "SaveToSentItems": "false",
    "isDraft": "false"
    }
"@

    # Change the email depending if the supervisor is empty
    If ( $null -eq $script:supervisorEmail.Mail ) {
        WriteLog "Credentials sent to: $DefaultEmail"
    }else {
        WriteLog "Credentials sent to: $DefaultEmail and $script:supervisorEmail"
    }

    # Invoke the request to send the email
    Invoke-RestMethod -Headers $authHeaders -Uri $apiUrl -Method Post -Body $Body 

}

# Optionally create a mailbox for the user
function Connect-ToExchange {

    # Connect to Exchange Management Shell
    $UserCredential = Get-Credential
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$exchangeServer/PowerShell/" -Authentication Kerberos -Credential $UserCredential
    Import-PSSession -Session $Session -CommandName Enable-RemoteMailbox -AllowClobber

}

function Enable-UsersMailbox {

    # Get-Credentials for exVchange admin
    $MailBoxAddr = "tenantName.mail.onmicrosoft.com"
    try {
        Enable-RemoteMailbox $CreateUserName -RemoteRoutingAddress "$CreateUserName@$MailBoxAddr" | Out-Null
    }
    catch {
        {1: WriteLog "Enable RemoteMailbox error." }
    }
}

# Set logging parameteres
function WriteLog {
    Param ([string]$LogString)
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage
}

# Load the AD modules 
#Load-Modules

# Connect to Exchange Management Shell
Connect-ToExchange

# Began the user creation, this can also create multiple users at a time
if (Test-Path -Path "$inputFile") {

    Import-Csv -Path $inputFile | ForEach-Object {
        
        # Call the function to create a password with acceptable parameters
        $CreatePass = Get-RandomPassword -length 10 -amountOfNonAlphanumeric 2 
        $securedPass = ConvertTo-SecureString -String $CreatePass -AsPlainText -Force     

        # Create the username (Format First Name (First Letter) + Last Name)
        # Also set everything to lowercase
        $CreateUserName = '{0}{1}' -f $_.FirstName.Substring(0,1).ToLower(),$_.LastName.ToLower()

        # Ensure the SamAccountName isn't to long
        If ( $CreateUserName.Length -gt $SAMLengthLimit ) {
            ForEach ( $str in $CreateUserName ) {
                $CreateUserName = $str.subString(0, [System.Math]::Min(10, $str.Length) )
                $CreateUserName = $CreateUserName.ToLower() 
            }
        }

        # Use the First Name and Last Name to create the Display Name
        $displayName = $_.FirstName + " " + $_.LastName

        # Correct the UPN 
        $domain = '@Domain.gov'

        # All Parameters to create the SAM Account
        $NewUserParameters = @{
            GivenName             = $_.FirstName
            Surname               = $_.LastName
            Name                  = $displayName
            SamAccountName        = $CreateUserName
            UserPrincipalName     = $CreateUserName+$domain
            DisplayName           = $displayName
            #Path                  = $SiteLocation
            AccountPassword       = $securedPass
            Title                 = $_.Title
            Manager               = $_.Manager
            Description           = $_.Title 
            Department            = $_.Department
            Enabled               = $True
            ChangePasswordAtLogon = $True
        }
        

        $CheckUser = Get-ADUser -Filter { SamAccountName -eq $CreateUserName }


        If ($null -eq $CheckUser) {
            
            # Use the params to create the users
            New-AdUser @NewUserParameters

            # New user OU
            $UserDistinguishedName = Get-ADUser -Identity $CreateUserName -Properties DistinguishedName

            #showSuccess
            WriteLog "Success"
            WriteLog "User created: $UserDistinguishedName.Name" 
            WriteLog "Organizational Unit: $UserDistinguishedName.DistinguishedName" 

            # Create the user's o365 mailbox
            do
                {
                    $errCountBefore = $Error.Count
                    try { Enable-UsersMailbox }
                    catch
                    {
                        #Write-Output "Cant connect the group to the main group, looping in $sleepTimer.."
                        Write-Error -ErrorAction SilentlyContinue "An error occurred in the try loop: $_"
                        Start-Sleep -Seconds $sleepTimer
                    }
                    if ($errCountBefore -eq $Error.Count) { $stopLoop = $true }
                }
                While ($stopLoop -eq $false)
            
            # Return the value and assign to a var
            $GrabEmail = find-supervisor
            Send-ToEmail

            # Add user to corresponding group depending 
            #Add-AdGroupMember -Identity 'Accounting' -Members $userName

        }else {

            # New user OU
            $UserDistinguishedName = Get-ADUser -Identity $CreateUserName -Properties DistinguishedName

            # Inform that there's a duplicate user

            #showFailure
            WriteLog "Failure"
            WriteLog "A duplicate was found. No email will be sent." 
            WriteLog "Duplicate user: $CreateUserName" 
            WriteLog "Organizational Unit: $UserDistinguishedName.DistinguishedName"
            #WriteLog "Organizational Unit: " -ForegroundColor DarkCyan -NoNewline

        } 
    }

}else{
    WriteLog "No file was found!"
}

# Remove the PSSession
try {
    Remove-PSSession $Session
}
catch {
    {1: Write-Host "PSSession removed."}
}

# Remove .csv file
Remove-Item -Path "\\path\to\csvfolder\Employees.csv"