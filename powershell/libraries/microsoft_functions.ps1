function Create-TeamsFirewallRules {
    <#
    .SYNOPSIS
    Creates firewall rules for Teams.
    .DESCRIPTION
    The script will create a new inbound firewall rule for each user folder found in c:\users.
    Requires PowerShell 3.0.
    #>

    #Requires -Version 3

    $users = Get-ChildItem (Join-Path -Path $env:SystemDrive -ChildPath 'Users') -Exclude 'Public', 'ADMINI~*'
    if ($null -ne $users) {
        foreach ($user in $users) {
            $progPath = Join-Path -Path $user.FullName -ChildPath "AppData\Local\Microsoft\Teams\Current\Teams.exe"
            if (Test-Path $progPath) {
                if (-not (Get-NetFirewallApplicationFilter -Program $progPath -ErrorAction SilentlyContinue)) {
                    $ruleName = "Teams.exe for user $($user.Name)"
                    "UDP", "TCP" | ForEach-Object { New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Profile Domain -Program $progPath -Action Allow -Protocol $_ }
                    Clear-Variable ruleName
                }
            }
            Clear-Variable progPath
        }
    }
}