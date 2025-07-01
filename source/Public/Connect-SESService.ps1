function Connect-SESService {
    <#
    .SYNOPSIS
    Establishes a connection to the Symantec Endpoint Security (SES) API.

    .DESCRIPTION
    This function authenticates with the SES API using client credentials (OAuth2)
    and establishes a session for subsequent API calls. It supports multiple
    regional endpoints and credential storage for convenience.

    .PARAMETER ClientId
    The OAuth2 client ID for authentication.

    .PARAMETER ClientSecret
    The OAuth2 client secret for authentication.

    .PARAMETER Region
    The regional endpoint to connect to. Valid values are 'us', 'eu', 'in'.
    Defaults to 'us'.

    .PARAMETER BaseUri
    Custom base URI for the API. If specified, overrides the regional endpoint.

    .PARAMETER SaveCredentials
    Save the credentials securely for future use.

    .PARAMETER UseStoredCredentials
    Use previously stored credentials for authentication.

    .PARAMETER Force
    Force a new connection even if one already exists.

    .PARAMETER SkipCertificateCheck
    Skip SSL certificate validation (for testing environments only).

    .EXAMPLE
    Connect-SESService -ClientId "your-client-id" -ClientSecret "your-secret" -Region "us"

    .EXAMPLE
    Connect-SESService -ClientId "your-client-id" -ClientSecret "your-secret" -SaveCredentials

    .EXAMPLE
    Connect-SESService -UseStoredCredentials

    .EXAMPLE
    Connect-SESService -BaseUri "https://custom.api.endpoint.com"

    .NOTES
    This function creates a global connection object ($Global:SESConnection) that
    stores authentication tokens and session information for use by other cmdlets.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Credentials', SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Credentials', HelpMessage = "OAuth2 client ID")]
        [ValidateNotNullOrEmpty()]
        [string]$ClientId,

        [Parameter(Mandatory = $true, ParameterSetName = 'Credentials', HelpMessage = "OAuth2 client secret")]
        [ValidateNotNullOrEmpty()]
        [string]$ClientSecret,

        [Parameter(Mandatory = $false, ParameterSetName = 'Credentials', HelpMessage = "Regional endpoint")]
        [Parameter(Mandatory = $false, ParameterSetName = 'StoredCredentials', HelpMessage = "Regional endpoint")]
        [ValidateSet('us', 'eu', 'in')]
        [string]$Region = 'us',

        [Parameter(Mandatory = $false, ParameterSetName = 'CustomUri', HelpMessage = "Custom base URI")]
        [ValidateNotNullOrEmpty()]
        [string]$BaseUri,

        [Parameter(Mandatory = $false, ParameterSetName = 'Credentials', HelpMessage = "Save credentials securely")]
        [switch]$SaveCredentials,

        [Parameter(Mandatory = $true, ParameterSetName = 'StoredCredentials', HelpMessage = "Use stored credentials")]
        [switch]$UseStoredCredentials,

        [Parameter(Mandatory = $false, HelpMessage = "Force new connection")]
        [switch]$Force,

        [Parameter(Mandatory = $false, HelpMessage = "Skip SSL certificate validation")]
        [switch]$SkipCertificateCheck
    )

    begin {
        Write-Verbose "Starting Connect-SESService"

        # Initialize connection object
        Initialize-SESConnection -Force:$Force

        # Check if already connected and not forcing
        if ($Global:SESConnection.IsConnected -and -not $Force) {
            Write-Warning "Already connected to SES API. Use -Force to establish a new connection."
            return $Global:SESConnection
        }
    }

    process {
        if ($PSCmdlet.ShouldProcess("SES API", "Establish connection")) {
            try {
                # Handle parameter sets
                switch ($PSCmdlet.ParameterSetName) {
                    'StoredCredentials' {
                        Write-Verbose "Using stored credentials"
                        $credentials = Import-SESCredential
                        if (-not $credentials) {
                            throw "No stored credentials found. Please run Connect-SESService with -ClientId and -ClientSecret first."
                        }
                        $ClientId = $credentials.ClientId
                        $ClientSecret = $credentials.ClientSecret
                        if (-not $Region -and $credentials.Region) {
                            $Region = $credentials.Region
                        }
                    }
                    'CustomUri' {
                        Write-Verbose "Using custom base URI: $BaseUri"
                        $Global:SESConnection.BaseUri = $BaseUri
                        $Global:SESConnection.Region = 'custom'
                    }
                    'Credentials' {
                        Write-Verbose "Using provided credentials for region: $Region"
                        # Set base URI from regional endpoints
                        if ($Global:SESConnection.RegionalEndpoints.ContainsKey($Region)) {
                            $Global:SESConnection.BaseUri = $Global:SESConnection.RegionalEndpoints[$Region]
                            $Global:SESConnection.Region = $Region
                        }
                        else {
                            throw "Invalid region specified: $Region. Valid regions are: $($Global:SESConnection.RegionalEndpoints.Keys -join ', ')"
                        }
                    }
                }

                Write-Verbose "Connecting to SES API at: $($Global:SESConnection.BaseUri)"

                # Prepare authentication request (SES API uses Basic Auth header method)
                $authUri = "$($Global:SESConnection.BaseUri)/v1/oauth2/tokens"
                
                # Create Basic Authentication header as per SES API documentation
                $authString = "$ClientId`:$ClientSecret"
                $encodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($authString))
                $authHeader = "Basic $encodedAuth"

                Write-Verbose "Requesting OAuth2 token from: $authUri"

                # Make authentication request using Basic Auth header (following PSSEPCloud pattern)
                $splat = @{
                    Uri = $authUri
                    Method = 'POST'
                    Headers = @{
                        'Host' = ($authUri -replace 'https://', '' -replace '/.*', '')
                        'Accept' = 'application/json'
                        'Authorization' = $authHeader
                    }
                    UseBasicParsing = $true
                    TimeoutSec = $Global:SESConnection.TimeoutSec
                }

                if ($SkipCertificateCheck) {
                    $splat['SkipCertificateCheck'] = $true
                }

                $authResponse = Invoke-SESWebRequest @splat

                if (-not $authResponse -or -not $authResponse.access_token) {
                    throw "Authentication failed: No access token received"
                }

                # Update connection object with authentication details
                $Global:SESConnection.AuthToken = $authResponse.access_token
                $Global:SESConnection.TokenExpiry = if ($authResponse.expires_in) {
                    (Get-Date).AddSeconds($authResponse.expires_in)
                } else {
                    (Get-Date).AddHours(1)
                }
                $Global:SESConnection.RefreshToken = $authResponse.refresh_token
                $Global:SESConnection.ClientId = $ClientId
                $Global:SESConnection.IsConnected = $true
                $Global:SESConnection.ConnectedAt = Get-Date

                Write-Verbose "Successfully authenticated. Token expires at: $($Global:SESConnection.TokenExpiry)"

                # Save credentials if requested
                if ($SaveCredentials) {
                    Write-Verbose "Saving credentials for future use"
                    Export-SESCredential -ClientId $ClientId -ClientSecret $ClientSecret -Region $Region
                }

                # Test the connection with a simple API call
                try {
                    Write-Verbose "Testing connection with API health check"
                    $testUri = "$($Global:SESConnection.BaseUri)/v1/health"
                    $testResponse = Submit-SESRequest -Uri $testUri -Method GET -TimeoutSec 10
                    Write-Verbose "Connection test successful: $($testResponse.status -or 'OK')"
                }
                catch {
                    Write-Warning "Connection established but health check failed: $($_.Exception.Message)"
                }

                Update-SESConnectionActivity

                Write-Information "Successfully connected to SES API" -InformationAction Continue
                Write-Information "Region: $($Global:SESConnection.Region)" -InformationAction Continue
                Write-Information "Base URI: $($Global:SESConnection.BaseUri)" -InformationAction Continue
                Write-Information "Token expires: $($Global:SESConnection.TokenExpiry)" -InformationAction Continue

                return $Global:SESConnection
            }
            catch {
                Write-Error "Failed to connect to SES API: $($_.Exception.Message)"

                # Reset connection on failure
                Reset-SESConnection
                throw
            }
        }
        else {
            Write-Verbose "Connection cancelled by user"
            return $null
        }
    }

    end {
        Write-Verbose "Completed Connect-SESService"
    }
}

function Import-SESCredential {
    <#
    .SYNOPSIS
    Imports previously saved SES credentials.

    .DESCRIPTION
    This function imports SES credentials that were previously saved using
    Export-SESCredential. The credentials are encrypted and stored securely.

    .EXAMPLE
    Import-SESCredential

    .NOTES
    This is a private helper function used by Connect-SESService.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    begin {
        Write-Verbose "Starting Import-SESCredential"
    }

    process {
        try {
            $credentialPath = Get-SESCredentialPath

            if (-not (Test-Path $credentialPath)) {
                Write-Verbose "No credential file found at: $credentialPath"
                return $null
            }

            Write-Verbose "Importing credentials from: $credentialPath"
            $credentials = Import-Clixml -Path $credentialPath

            if (-not $credentials -or -not $credentials.ClientId) {
                Write-Warning "Invalid credential file format"
                return $null
            }

            Write-Verbose "Successfully imported credentials for client: $($credentials.ClientId)"
            return $credentials
        }
        catch {
            Write-Warning "Failed to import credentials: $($_.Exception.Message)"
            return $null
        }
    }

    end {
        Write-Verbose "Completed Import-SESCredential"
    }
}

function Export-SESCredential {
    <#
    .SYNOPSIS
    Exports SES credentials securely for future use.

    .DESCRIPTION
    This function exports SES credentials using PowerShell's built-in
    encryption (Export-Clixml) for secure storage and future use.

    .PARAMETER ClientId
    The OAuth2 client ID to save.

    .PARAMETER ClientSecret
    The OAuth2 client secret to save.

    .PARAMETER Region
    The regional endpoint to save.

    .EXAMPLE
    Export-SESCredential -ClientId "client-id" -ClientSecret "secret" -Region "us"

    .NOTES
    This is a private helper function used by Connect-SESService.
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
    }

    process {
        try {
            $credentialPath = Get-SESCredentialPath
            Write-Verbose "Exporting credentials to: $credentialPath"

            $credentialObject = [PSCustomObject]@{
                ClientId = $ClientId
                ClientSecret = $ClientSecret
                Region = $Region
                SavedAt = Get-Date
                SavedBy = $env:USERNAME
                ComputerName = $env:COMPUTERNAME
            }

            $credentialObject | Export-Clixml -Path $credentialPath -Force
            Write-Verbose "Credentials saved successfully"
        }
        catch {
            Write-Warning "Failed to save credentials: $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-Verbose "Completed Export-SESCredential"
    }
}