function Export-SESCredential {
    <#
    .SYNOPSIS
    Exports SES credentials securely to a file.

    .DESCRIPTION
    This function securely saves SES client credentials (ClientId, ClientSecret, Region)
    to an XML file using Export-CliXml. The credentials are encrypted using DPAPI,
    making them accessible only by the user who encrypted them on that specific machine.

    .PARAMETER ClientId
    The OAuth2 client ID to save.

    .PARAMETER ClientSecret
    The OAuth2 client secret to save.

    .PARAMETER Region
    The regional endpoint associated with the credentials.

    .EXAMPLE
    Export-SESCredential -ClientId "your-client-id" -ClientSecret "your-secret" -Region "us"

    .NOTES
    This function is typically called by Connect-SESService when -SaveCredentials is specified.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "OAuth2 client ID")]
        [ValidateNotNullOrEmpty()]
        [string]$ClientId,

        [Parameter(Mandatory = $true, HelpMessage = "OAuth2 client secret")]
        [ValidateNotNullOrEmpty()]
        [string]$ClientSecret,

        [Parameter(Mandatory = $false, HelpMessage = "Regional endpoint")]
        [ValidateSet('us', 'eu', 'in')]
        [string]$Region = 'us'
    )

    begin {
        Write-Verbose "Starting Export-SESCredential"
        $credentialPath = Get-SESCredentialPath
        Write-Verbose "Attempting to export credentials to: $credentialPath"
    }

    process {
        try {
            $credentialObject = [PSCustomObject]@{
                ClientId = $ClientId
                ClientSecret = $ClientSecret
                Region = $Region
                SavedAt = Get-Date
            }

            $credentialObject | Export-Clixml -Path $credentialPath -Force
            Write-Verbose "Successfully exported credentials to $credentialPath"
        }
        catch {
            Write-Error ("Failed to export credentials to " + $credentialPath + ": " + ${_.Exception.Message})
            throw
        }
    }

    end {
        Write-Verbose "Completed Export-SESCredential"
    }
}