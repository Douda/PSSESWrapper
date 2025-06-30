function Initialize-SESConnection {
    <#
    .SYNOPSIS
    Initializes the global SES connection object for session management.

    .DESCRIPTION
    This function creates and initializes the global SES connection object
    that stores authentication tokens, session information, and configuration
    settings for the Symantec Endpoint Security API.

    .PARAMETER Force
    Force initialization even if a connection object already exists.

    .EXAMPLE
    Initialize-SESConnection

    .EXAMPLE
    Initialize-SESConnection -Force

    .NOTES
    This function is typically called automatically by Connect-SESService
    and should not need to be called directly by users.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Force initialization even if connection exists")]
        [switch]$Force
    )

    begin {
        Write-Verbose "Starting Initialize-SESConnection"
    }

    process {
        # Check if connection already exists and force is not specified
        if ($Global:SESConnection -and -not $Force) {
            Write-Verbose "SES connection object already exists and Force not specified"
            return $Global:SESConnection
        }

        Write-Verbose "Creating new SES connection object"
        
        # Create the global connection object with default values
        $Global:SESConnection = [PSCustomObject]@{
            # Connection status
            IsConnected = $false
            ConnectedAt = $null
            LastActivity = $null
            
            # Authentication information
            AuthToken = $null
            TokenExpiry = $null
            RefreshToken = $null
            ClientId = $null
            Region = $null
            
            # API configuration
            BaseUri = $null
            ApiVersion = 'v1'
            UserAgent = "PSSESWrapper/$($MyInvocation.MyCommand.Module.Version)"
            
            # Session settings
            TimeoutSec = 30
            RetryCount = 3
            RetryDelay = 1
            
            # Regional endpoints
            RegionalEndpoints = @{
                'us' = 'https://api.sep.securitycloud.symantec.com'
                'eu' = 'https://api.sep.eu.securitycloud.symantec.com'
                'in' = 'https://api.sep.in.securitycloud.symantec.com'
            }
            
            # Connection metadata
            ConnectionId = [System.Guid]::NewGuid().ToString()
            PSVersion = $PSVersionTable.PSVersion.ToString()
            PSEdition = $PSVersionTable.PSEdition
            Platform = if ($PSVersionTable.PSVersion.Major -ge 6) { 
                if ($IsWindows) { 'Windows' } 
                elseif ($IsLinux) { 'Linux' } 
                elseif ($IsMacOS) { 'macOS' } 
                else { 'Unknown' }
            } else { 'Windows' }
            
            # Credential storage path
            CredentialPath = $null
            
            # Debug and logging
            VerbosePreference = $VerbosePreference
            DebugPreference = $DebugPreference
        }
        
        # Set the credential storage path based on platform
        $Global:SESConnection.CredentialPath = Get-SESCredentialPath
        
        Write-Verbose "SES connection object initialized with ConnectionId: $($Global:SESConnection.ConnectionId)"
        Write-Verbose "Platform: $($Global:SESConnection.Platform), PSVersion: $($Global:SESConnection.PSVersion)"
        Write-Verbose "Credential path: $($Global:SESConnection.CredentialPath)"
        
        return $Global:SESConnection
    }

    end {
        Write-Verbose "Completed Initialize-SESConnection"
    }
}

function Get-SESCredentialPath {
    <#
    .SYNOPSIS
    Gets the appropriate credential storage path for the current platform.

    .DESCRIPTION
    This function determines the correct path for storing SES credentials
    based on the current platform and PowerShell version.

    .EXAMPLE
    Get-SESCredentialPath

    .NOTES
    This function handles cross-platform differences in credential storage.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    begin {
        Write-Verbose "Determining credential storage path"
    }

    process {
        try {
            # Determine the appropriate credential directory based on platform
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                # PowerShell Core/7.x
                if ($IsWindows) {
                    $credentialDir = Join-Path $env:APPDATA 'PSSESWrapper'
                }
                elseif ($IsLinux) {
                    $credentialDir = Join-Path $env:HOME '.config/PSSESWrapper'
                }
                elseif ($IsMacOS) {
                    $credentialDir = Join-Path $env:HOME 'Library/Application Support/PSSESWrapper'
                }
                else {
                    # Fallback for unknown platforms
                    $credentialDir = Join-Path $env:HOME '.PSSESWrapper'
                }
            }
            else {
                # PowerShell 5.1 - Windows only
                $credentialDir = Join-Path $env:APPDATA 'PSSESWrapper'
            }
            
            # Ensure the directory exists
            if (-not (Test-Path $credentialDir)) {
                New-Item -Path $credentialDir -ItemType Directory -Force | Out-Null
                Write-Verbose "Created credential directory: $credentialDir"
            }
            
            $credentialPath = Join-Path $credentialDir 'ses-credentials.xml'
            Write-Verbose "Credential path determined: $credentialPath"
            
            return $credentialPath
        }
        catch {
            Write-Warning "Failed to determine credential path: $($_.Exception.Message)"
            # Fallback to temp directory
            $tempPath = Join-Path $env:TEMP 'ses-credentials.xml'
            Write-Verbose "Using fallback credential path: $tempPath"
            return $tempPath
        }
    }

    end {
        Write-Verbose "Completed Get-SESCredentialPath"
    }
}

function Reset-SESConnection {
    <#
    .SYNOPSIS
    Resets the global SES connection object to its default state.

    .DESCRIPTION
    This function resets the global SES connection object, clearing all
    authentication tokens and session information while preserving
    configuration settings.

    .PARAMETER PreserveConfig
    Preserve configuration settings when resetting the connection.

    .EXAMPLE
    Reset-SESConnection

    .EXAMPLE
    Reset-SESConnection -PreserveConfig

    .NOTES
    This function is typically called by Disconnect-SESService.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Preserve configuration settings")]
        [switch]$PreserveConfig
    )

    begin {
        Write-Verbose "Starting Reset-SESConnection"
    }

    process {
        if (-not $Global:SESConnection) {
            Write-Verbose "No SES connection object to reset"
            return
        }

        Write-Verbose "Resetting SES connection object"
        
        # Store configuration if preserving
        $configToPreserve = @{}
        if ($PreserveConfig) {
            $configToPreserve = @{
                Region = $Global:SESConnection.Region
                BaseUri = $Global:SESConnection.BaseUri
                TimeoutSec = $Global:SESConnection.TimeoutSec
                RetryCount = $Global:SESConnection.RetryCount
                RetryDelay = $Global:SESConnection.RetryDelay
                CredentialPath = $Global:SESConnection.CredentialPath
            }
        }
        
        # Reset connection status
        $Global:SESConnection.IsConnected = $false
        $Global:SESConnection.ConnectedAt = $null
        $Global:SESConnection.LastActivity = $null
        
        # Clear authentication information
        $Global:SESConnection.AuthToken = $null
        $Global:SESConnection.TokenExpiry = $null
        $Global:SESConnection.RefreshToken = $null
        $Global:SESConnection.ClientId = $null
        
        # Reset API configuration if not preserving
        if (-not $PreserveConfig) {
            $Global:SESConnection.Region = $null
            $Global:SESConnection.BaseUri = $null
            $Global:SESConnection.TimeoutSec = 30
            $Global:SESConnection.RetryCount = 3
            $Global:SESConnection.RetryDelay = 1
        }
        else {
            # Restore preserved configuration
            foreach ($key in $configToPreserve.Keys) {
                $Global:SESConnection.$key = $configToPreserve[$key]
            }
        }
        
        # Update connection metadata
        $Global:SESConnection.ConnectionId = [System.Guid]::NewGuid().ToString()
        $Global:SESConnection.LastActivity = Get-Date
        
        Write-Verbose "SES connection object reset with new ConnectionId: $($Global:SESConnection.ConnectionId)"
    }

    end {
        Write-Verbose "Completed Reset-SESConnection"
    }
}

function Update-SESConnectionActivity {
    <#
    .SYNOPSIS
    Updates the last activity timestamp for the SES connection.

    .DESCRIPTION
    This function updates the LastActivity property of the global SES
    connection object to track when the connection was last used.

    .EXAMPLE
    Update-SESConnectionActivity

    .NOTES
    This function is typically called automatically by API request functions.
    #>
    [CmdletBinding()]
    param()

    begin {
        Write-Verbose "Updating SES connection activity"
    }

    process {
        if ($Global:SESConnection) {
            $Global:SESConnection.LastActivity = Get-Date
            Write-Verbose "Updated LastActivity to: $($Global:SESConnection.LastActivity)"
        }
        else {
            Write-Verbose "No SES connection object to update"
        }
    }

    end {
        Write-Verbose "Completed Update-SESConnectionActivity"
    }
}