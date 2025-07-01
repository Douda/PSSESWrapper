function Import-SESCredential {
    <#
    .SYNOPSIS
    Imports securely stored SES credentials.

    .DESCRIPTION
    This function retrieves previously saved SES client credentials from a secure XML file
    using Export-CliXml. It's used by Connect-SESService when -UseStoredCredentials is specified.

    .EXAMPLE
    $credentials = Import-SESCredential

    .NOTES
    Credentials are encrypted using DPAPI and are user-specific.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    begin {
        Write-Verbose "Starting Import-SESCredential"
        $credentialPath = Get-SESCredentialPath
        Write-Verbose "Attempting to import credentials from: $credentialPath"
    }

    process {
        if (-not (Test-Path $credentialPath)) {
            Write-Verbose "Credential file not found at $credentialPath"
            return $null
        }

        try {
            $credentials = Import-Clixml -Path $credentialPath
            Write-Verbose "Successfully imported credentials."
            return $credentials
        }
        catch {
            Write-Warning ("Failed to import credentials from " + $credentialPath + ": " + ${_.Exception.Message})
            return $null
        }
    }

    end {
        Write-Verbose "Completed Import-SESCredential"
    }
}