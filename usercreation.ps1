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
    Revision Date: October 7,, 2022
.EXAMPLE
    powershell.exe -path "<full path to file>.ps1"
#>

# The file containing the CSV
$inputFile = "\\path\to\Watch\Employees.csv"

# Location for outputted log file
$Logfile = "\\path\to\logs\UserCreation.logs"

$CreateUserName = $null
$CreatePass      = $null

# Default email to be used
$DefaultEmail = "email@email.com"

# Set account limit
$SAMLengthLimit = 15
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
        [int] $amountOfNonAlphanumeric = 1
    )
    Add-Type -AssemblyName 'System.Web'
    return [System.Web.Security.Membership]::GeneratePassword($length, $amountOfNonAlphanumeric)
}

<#
function showFailure {
    cls
    Write-Host ------------------------------------------------------------
    Write-Host                   User Creation =  -NoNewline
    Write-Host " " Failure -ForegroundColor Red 
    Write-Host ------------------------------------------------------------
}

function showSuccess {
    cls
    Write-Host ------------------------------------------------------------
    Write-Host                   User Creation =  -NoNewline
    Write-Host " " Success -ForegroundColor Green 
    Write-Host ------------------------------------------------------------
}
#>

function find-supervisor {

    # Get info from the supervisor
    $GetADUserManager = Get-ADUser -Filter { SamAccountName -Like $CreateUserName } -Properties Manager
    $SetADUserManager = $GetADUserManager.Manager
    $script:supervisorEmail  = Get-ADUser -Identity $SetADUserManager -Properties Mail | Select-Object Mail
    
    # Return the specified user mailbox
    return $script:supervisorEmail
 }

# You don't have to call this function
function Send-ToEmail {

    # Application (client) ID, tenant Name and secret
    $clientID = "fakeID3482748"
    $tenantName = "tenantName.onmicrosoft.com"
    $clientSecret = "89347329gr87fsdf73"
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
function Enable-O365MailBox {

    # Get-Credentials for exchange admin
    $MailBoxAddr = "exchange.mail.onmicrosoft.com"
    Enable-RemoteMailbox $CreateUserName -RemoteRoutingAddress "$CreateUserName@$MailBoxAddr"
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

# Began the user creation, this can also create multiple users at a time
if (Test-Path -Path "$inputFile") {

    Import-Csv -Path $inputFile | ForEach-Object {
        
        # Call the function to create a password with acceptable parameters
        $CreatePass = Get-RandomPassword -length 8 -amountOfNonAlphanumeric 2
        $securedPass = ConvertTo-SecureString -String $CreatePass -AsPlainText -Force     

        # Create the username (Format First Name (First Letter) + Last Name)
        $CreateUserName = '{0}{1}' -f $_.FirstName.Substring(0,1),$_.LastName

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
        $domain = '@domain.gov'

        # All Parameters to create the SAM Account
        $NewUserParameters = @{
            GivenName          = $_.FirstName
            Surname            = $_.LastName
            Name               = $CreateUserName
            AccountPassword    = $securedPass
            DisplayName        = $displayName
            Title              = $_.Title
            Manager            = $_.Manager
            Description        = $_.Title 
            Department         = $_.Department
            UserPrincipalName  = $CreateUserName+$domain
            Enabled            = $True
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

            # Create the user's o365 mailbox / Maybe invoke-command?
            #Enable-O365MailBox
            
            # Return the value and assign to a var
            $GrabEmail = find-supervisor
            Send-ToEmail

            #Add-AdGroupMember -Identity 'Accounting' -Members $userName
            Remove-Item -Path "\\path\to\Watch\Employees.csv"

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

}
