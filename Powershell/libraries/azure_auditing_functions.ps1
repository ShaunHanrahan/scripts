# Call Azure Helper Function
. "$PSScriptRoot\azure_helper_functions.ps1"

function Get-AuditLogStatus {
    <#
    .SYNOPSIS 
        Get the audit log status for all customers
    .DESCRIPTION
        Retrieves the audit log status for all customers. 
        The function fetches the current status of the audit log settings 
        for each customer and indicates whether logging is enabled or not. 
        It leverages Azure Key Vault for securing and retrieving necessary 
        credentials and tokens.
    .PARAMETER None
        No parameters
    .EXAMPLE
        Get-AuditLogStatus
    .NOTES
        Ensure appropriate permissions are in place before attempting to modify audit log settings.
    #>

    # Fetch common token parameters from the helper function
    $commonTokenParams = Get-CommonToken

    # Generate CBI token
    $tokenResponse = Get-MicrosoftToken @commonTokenParams -TenantID (Get-VaultSecrets -VaultName 'key-vault-scripts' -SecretName 'ConnectionsTenantID')

    # Create the header for the request
    if ($tokenResponse.Access_Token) {
        $cbi = @{
            Authorization = 'bearer {0}' -f $tokenResponse.Access_Token
            Accept        = "application/json"
        }
    }

    # Get all the customers
    $customers = (Invoke-RestMethod -Method "GET" -Headers $cbi -uri "https://graph.microsoft.com/v1.0/contracts").value
    
    $results = New-Object 'System.Collections.ArrayList'

    foreach ($customer in $customers) {
        $customerTenantId = $customer.customerId
    
        try {
            $token = (Get-MicrosoftToken @commonTokenParams -TenantID $customerTenantId -Scope "https://outlook.office365.com/.default" -ErrorAction SilentlyContinue).Access_Token
            if ($null -eq $token) { throw "No token received" }
        } catch {
            Write-Warning "Failed to get token for customer $($customer.displayName): $_"
            continue
        }
    
        $header = @{
            Authorization = 'Bearer {0}' -f $token
            Accept        = 'application/json'
        }
    
        $BaseURL = "https://outlook.office365.com/adminapi/beta/$($customerTenantId)/InvokeCommand"
    
        $cmdletBody1 = @{
            CmdletInput = @{
                CmdletName = 'Get-AdminAuditLogConfig'
                Parameters = @{}
            }
        } | ConvertTo-Json -Depth 3
    
        try {
            $auditConfig = (Invoke-RestMethod -Method POST -Uri $BaseURL -body $cmdletBody1 -ContentType 'application/json' -Headers $header).value
        } catch {
            Write-Warning "Failed to retrieve audit log configuration for customer $($customer.displayName)"
            continue
        }
        
        $isLoggingEnabled = $auditConfig.AdminAuditLogEnabled -and $auditConfig.UnifiedAuditLogIngestionEnabled
        
        # Create PSCustomObject
        $obj = [PSCustomObject]@{
            CustomerName = $customer.displayName
            LoggingEnabled = $isLoggingEnabled
        }
        
        # Add to results array for better performance
        [void]$results.Add($obj)
    }

    return $results
}
function Set-AuditLogStatus {
    <#
    .SYNOPSIS 
        Set the audit log status for all customers.
        
    .DESCRIPTION
        Configures the audit log settings for each customer. 
        The function updates the status of the audit log settings based on the provided input, 
        enabling or disabling logging as required.
        It leverages Azure Key Vault for securing and retrieving necessary credentials and tokens.

    .PARAMETER none
        No parameters
    .EXAMPLE
        Set-AuditLogStatus

    .NOTES
        Ensure appropriate permissions are in place before attempting to modify audit log settings.
    #>

    # Fetch common token parameters from the helper function
    $commonTokenParams = Get-CommonToken

    # Generate CBI token
    $tokenResponse = Get-MicrosoftToken @commonTokenParams -TenantID (Get-VaultSecrets -VaultName 'key-vault-scripts' -SecretName 'ConnectionsTenantID')

    # Create the header for the request
    if ($tokenResponse.Access_Token) {
        $cbi = @{
            Authorization = 'bearer {0}' -f $tokenResponse.Access_Token
            Accept        = "application/json"
        }
    }

    # Get all the customers
    $customers = (Invoke-RestMethod -Method "GET" -Headers $cbi -uri "https://graph.microsoft.com/v1.0/contracts").value
    
    $results = New-Object 'System.Collections.ArrayList'

    foreach ($customer in $customers) {
        $customerTenantId = $customer.customerId
    
        try {
            $token = (Get-MicrosoftToken @commonTokenParams -TenantID $customerTenantId -Scope "https://outlook.office365.com/.default" -ErrorAction SilentlyContinue).Access_Token
            if ($null -eq $token) { throw "No token received" }
        } catch {
            Write-Warning "Failed to get token for customer $($customer.displayName): $_"
            continue
        }
    
        $header = @{
            Authorization = 'Bearer {0}' -f $token
            Accept        = 'application/json'
        }
    
        $BaseURL = "https://outlook.office365.com/adminapi/beta/$($customerTenantId)/InvokeCommand"
    
        $cmdletBody1 = @{
            CmdletInput = @{
                CmdletName = 'Set-AdminAuditLogConfig'
                Parameters = @{
                    AdminAuditLogEnabled = $true
                    UnifiedAuditLogIngestionEnabled = $true
                    AdminAuditLogCmdlets = '*'
                    AdminAuditLogParameters = '*'
                }
            }
        } | ConvertTo-Json -Depth 3

        # Enable audit logging
        try {
            $response = (Invoke-RestMethod -Method POST -Uri $BaseURL -body $cmdletBody1 -ContentType 'application/json' -Headers $header).value

            # Store the response or any relevant data in the results array
            $obj = [PSCustomObject]@{
                CustomerName = $customer.displayName
                AuditConfigChangeResponse = $response # or any other relevant field from the response
            }

            [void]$results.Add($obj)

        } catch {
            if ($_.Exception.Message -like "*User is not allowed to call Set-AdminAuditLogConfig*") {
                Write-Warning "Permission denied: Cannot set audit log configuration for customer $($customer.displayName). User does not have the necessary permissions to call Set-AdminAuditLogConfig."
            } else {
                Write-Warning "Failed to set audit log configuration for customer $($customer.displayName)"
            }
            continue
        }
    }
    return $results
}
function Get-InactiveUsers {
    <#
    .SYNOPSIS 
        Get an audit of inactive users for all customers.
    .DESCRIPTION
        Retrieves a list of inactive users for each customer based 
        on a specified time period. It leverages Azure Key Vault for
        securing and retrieving necessary credentials and tokens.
    .PARAMETER Days
        Time period in days to identify inactive users.
    .EXAMPLE
        Get-InactiveUsers -Days 30
    .NOTES
        Ensure appropriate permissions are in place before attempting to retrieve user data.
    #>

    param(
        [Parameter(Mandatory = $false)]
        [int]$Days = 90
    )

    # Fetch common token parameters from the helper function
    $commonTokenParams = Get-CommonToken

    # Generate CBI token
    $tokenResponse = Get-MicrosoftToken @commonTokenParams -TenantID (Get-VaultSecrets -VaultName 'key-vault-scripts' -SecretName 'ConnectionsTenantID')

    # Create the header for the request
    if ($tokenResponse.Access_Token) {
        $cbi = @{
            Authorization = 'bearer {0}' -f $tokenResponse.Access_Token
            Accept        = "application/json"
        }
    }

    # Get all the customers
    $customers = (Invoke-RestMethod -Method GET -Headers $cbi -uri "https://graph.microsoft.com/v1.0/contracts").value
    
    $results = New-Object 'System.Collections.ArrayList'
    $log = New-Object 'System.Collections.ArrayList'

    foreach ($customer in $customers) {
        $customerTenantId = $customer.customerId
        $skipTenant = $false  # Flag to indicate whether to skip the current tenant
    
        try {
            $token = (Get-MicrosoftToken @commonTokenParams -TenantID $customerTenantId -Scope "https://graph.microsoft.com/.default" -ErrorAction SilentlyContinue).Access_Token
            if ($null -eq $token) { throw "No token received" }
        } catch {
            Write-Warning "Failed to get token for customer $($customer.displayName): $_"
            continue
        }
    
        $header = @{
            Authorization = 'Bearer {0}' -f $token
            Accept        = 'application/json'
        }

        $BaseURL = "https://graph.microsoft.com/beta/users/?`$select=mail,accountEnabled,assignedLicenses,signInActivity"

        do {
            if ($skipTenant) { break }  # Exit the do-while loop if the tenant should be skipped
            
            try {
                $response = Invoke-RestMethod -Method GET -Uri $BaseURL -Headers $header
            } catch {
                if ($_.Exception.Response.StatusCode -eq 'Forbidden') {
                    Write-Warning "Tenant $($customer.displayName) does not have a premium license."
                    $logEntry = [PSCustomObject]@{
                        CustomerName = $customer.displayName
                        Status = "Skipped due to lack of premium license"
                    }
                    [void]$log.Add($logEntry)
                    $skipTenant = $true  # Set the flag to skip the current tenant
                    continue
                } else {
                    Write-Warning "Failed to get inactive users for customer $($customer.displayName): $_"
                    continue
                }
            }

            $response.value | ForEach-Object {
                $user = $_
                $mail = $user.mail
                $accountEnabled = $user.accountEnabled
                $userIsLicensed = ($user.assignedLicenses | Measure-Object).Count -gt 0
                $lastSignIn = $user.signInActivity.lastSignInDateTime
                $isInactive = $false
        
                # Check if user is licensed
                if ($userIsLicensed) {
                    if ($lastSignIn -and $accountEnabled -eq $true) {
                        $lastSignInDate = [DateTime]::Parse($lastSignIn)
                        $daysSinceLastSignIn = (New-TimeSpan -Start $lastSignInDate -End (Get-Date)).Days
                        if ($daysSinceLastSignIn -gt $Days) {
                            $isInactive = $true
                        }
                    }
        
                    # Create PSCustomObject
                    $obj = [PSCustomObject]@{
                        Mail = $mail
                        AccountEnabled = $accountEnabled
                        IsLicensed = $userIsLicensed
                        LastSignIn = $lastSignIn
                        IsInactive = $isInactive
                    }
        
                    # Add to results array for better performance
                    [void]$results.Add($obj)
                }
            }
            # Check for pagination
            $BaseURL = $response.'@odata.nextLink'
        } while ($BaseURL)
    }

    # Export results and log to CSV
    $results | Export-Csv -Path ".\InactiveUsers.csv" -NoTypeInformation
    $log | Export-Csv -Path ".\TenantStatusLog.csv" -NoTypeInformation
}