function Get-MicrosoftToken {
    Param(
        # Tenant Id
        [Parameter(Mandatory=$false)]
        [guid]$TenantId,

        # Scope
        [Parameter(Mandatory=$false)]
        [string]$Scope = 'https://graph.microsoft.com/.default',

        # ApplicationID
        [Parameter(Mandatory=$true)]
        [guid]$ApplicationID,

        # ApplicationSecret
        [Parameter(Mandatory=$true)]
        [string]$ApplicationSecret,

        # RefreshToken
        [Parameter(Mandatory=$true)]
        [string]$RefreshToken
    )

    if ($TenantId) {
        $Uri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    }
    else {
        $Uri = "https://login.microsoftonline.com/common/oauth2/v2.0/token"
    }

    # Define the parameters for the token request
    $Body = @{
        client_id       = $ApplicationID
        client_secret   = $ApplicationSecret
        scope           = $Scope
        refresh_token   = $RefreshToken
        grant_type      = 'refresh_token'
    }

    $Params = @{
        Uri = $Uri
        Method = 'POST'
        Body = $Body
        ContentType = 'application/x-www-form-urlencoded'
        UseBasicParsing = $true
    }

    try {
        $AuthResponse = (Invoke-WebRequest @Params).Content | ConvertFrom-Json
    } catch {
        Write-Error "Authentication Error Occured $_"
        return
    }

    return $AuthResponse
}
function Get-VaultSecrets {
    param (
        [Parameter(Mandatory=$true)]
        [string]$VaultName,
        [Parameter(Mandatory=$true)]
        [string]$SecretName
    )

    return (Get-AzKeyVaultSecret -VaultName $VaultName -Name $SecretName -AsPlainText -ErrorAction Stop)
}

function Get-CommonToken {
    $vaultName = 'key-vault-scripts'
    return @{
        ApplicationID = Get-VaultSecrets -VaultName $vaultName -SecretName 'SAMAppId'
        ApplicationSecret = Get-VaultSecrets -VaultName $vaultName -SecretName 'SAMAppSecret'
        RefreshToken = Get-VaultSecrets -VaultName $vaultName -SecretName 'RefreshToken'
    }
}