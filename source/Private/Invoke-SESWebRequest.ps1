function Invoke-SESWebRequest {
    <#
    .SYNOPSIS
    Cross-platform wrapper for Invoke-RestMethod with enhanced error handling.

    .DESCRIPTION
    This function provides a cross-platform compatible wrapper around Invoke-RestMethod
    with enhanced error handling, response processing, and support for different
    PowerShell versions (5.1, 6, 7.x) on Windows and Linux.

    .PARAMETER Uri
    The URI for the web request.

    .PARAMETER Method
    The HTTP method to use.

    .PARAMETER Headers
    Headers to include in the request.

    .PARAMETER Body
    The request body.

    .PARAMETER ContentType
    The content type for the request.

    .PARAMETER TimeoutSec
    Request timeout in seconds.

    .PARAMETER SkipCertificateCheck
    Skip SSL certificate validation.

    .PARAMETER UseBasicParsing
    Use basic parsing for compatibility.

    .EXAMPLE
    Invoke-SESWebRequest -Uri "https://api.example.com" -Method GET

    .EXAMPLE
    Invoke-SESWebRequest -Uri "https://api.example.com" -Method POST -Body $jsonData

    .NOTES
    This function handles differences between PowerShell versions and platforms
    to ensure consistent behavior across environments.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The URI for the web request")]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory = $false, HelpMessage = "The HTTP method to use")]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
        [string]$Method = 'GET',

        [Parameter(Mandatory = $false, HelpMessage = "Headers to include in the request")]
        [hashtable]$Headers = @{},

        [Parameter(Mandatory = $false, HelpMessage = "The request body")]
        [string]$Body,

        [Parameter(Mandatory = $false, HelpMessage = "The content type for the request")]
        [string]$ContentType = 'application/json',

        [Parameter(Mandatory = $false, HelpMessage = "Request timeout in seconds")]
        [int]$TimeoutSec = 30,

        [Parameter(Mandatory = $false, HelpMessage = "Skip SSL certificate validation")]
        [switch]$SkipCertificateCheck,

        [Parameter(Mandatory = $false, HelpMessage = "Use basic parsing for compatibility")]
        [switch]$UseBasicParsing
    )

    begin {
        Write-Verbose "Starting Invoke-SESWebRequest for $Method $Uri"

        # Determine PowerShell version and platform capabilities
        $psVersion = $PSVersionTable.PSVersion
        $isCorePowerShell = $PSVersionTable.PSEdition -eq 'Core'
        $isWindowsPlatform = if ($PSVersionTable.PSVersion.Major -ge 6) { $IsWindows } else { $true }

        Write-Verbose "PowerShell Version: $($psVersion), Edition: $($PSVersionTable.PSEdition), Windows: $isWindowsPlatform"
    }

    process {
        try {
            # Build the parameter hashtable for Invoke-RestMethod
            $splat = @{
                Uri         = $Uri
                Method      = $Method
                Headers     = $Headers
                ContentType = $ContentType
                TimeoutSec  = $TimeoutSec
            }

            # Add body if provided
            if ($Body) {
                $splat['Body'] = $Body
            }

            # Handle SSL certificate checking based on PowerShell version
            if ($SkipCertificateCheck) {
                if ($isCorePowerShell) {
                    # PowerShell Core/7.x supports -SkipCertificateCheck
                    $splat['SkipCertificateCheck'] = $true
                    Write-Verbose "Using native SkipCertificateCheck parameter"
                }
                else {
                    # PowerShell 5.1 - need to handle SSL differently
                    Write-Verbose "PowerShell 5.1 detected - handling SSL certificate validation"

                    # Store original certificate policy
                    $originalCertificatePolicy = [System.Net.ServicePointManager]::CertificatePolicy

                    # Create a custom certificate policy that accepts all certificates
                    if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
                        Add-Type -TypeDefinition @"
                            using System.Net;
                            using System.Security.Cryptography.X509Certificates;
                            public class TrustAllCertsPolicy : ICertificatePolicy {
                                public bool CheckValidationResult(
                                    ServicePoint srvPoint, X509Certificate certificate,
                                    WebRequest request, int certificateProblem) {
                                    return true;
                                }
                            }
"@
                    }

                    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
                }
            }

            # Handle UseBasicParsing for different PowerShell versions
            if ($UseBasicParsing -and -not $isCorePowerShell) {
                $splat['UseBasicParsing'] = $true
            }

            # Set TLS version for better compatibility
            if (-not $isCorePowerShell) {
                # Ensure TLS 1.2 is available for PowerShell 5.1
                [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls
            }

            Write-Verbose "Invoking REST method with parameters: $($splat | ConvertTo-Json -Compress)"

            # Make the actual web request
            $response = Invoke-RestMethod @splat

            Write-Verbose "Request completed successfully"
            return $response
        }
        catch [System.Net.WebException] {
            # Handle web exceptions with detailed error information
            $webException = $_.Exception
            $response = $webException.Response

            $errorDetails = @{
                StatusCode = $null
                StatusDescription = $null
                ResponseBody = $null
                Exception = $webException
            }

            if ($response) {
                $errorDetails.StatusCode = $response.StatusCode
                $errorDetails.StatusDescription = $response.StatusDescription

                # Try to read the response stream for error details
                try {
                    $stream = $response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $errorDetails.ResponseBody = $reader.ReadToEnd()
                    $reader.Close()
                    $stream.Close()
                }
                catch {
                    Write-Verbose "Could not read error response body: $($_.Exception.Message)"
                }
            }

            Write-Verbose "WebException caught: StatusCode=$($errorDetails.StatusCode), Description=$($errorDetails.StatusDescription)"

            # Create a custom error with detailed information
            $errorMessage = "Web request failed"
            if ($errorDetails.StatusCode) {
                $errorMessage += " with status $($errorDetails.StatusCode)"
            }
            if ($errorDetails.StatusDescription) {
                $errorMessage += ": $($errorDetails.StatusDescription)"
            }
            if ($errorDetails.ResponseBody) {
                $errorMessage += ". Response: $($errorDetails.ResponseBody)"
            }

            $customError = [System.Exception]::new($errorMessage, $webException)
            $customError | Add-Member -MemberType NoteProperty -Name 'Response' -Value $response
            $customError | Add-Member -MemberType NoteProperty -Name 'StatusCode' -Value $errorDetails.StatusCode
            $customError | Add-Member -MemberType NoteProperty -Name 'ResponseBody' -Value $errorDetails.ResponseBody

            throw $customError
        }
        catch {
            # Handle other exceptions
            Write-Verbose "General exception caught: $($_.Exception.Message)"
            throw
        }
        finally {
            # Restore original certificate policy if it was changed
            if ($SkipCertificateCheck -and -not $isCorePowerShell -and $originalCertificatePolicy) {
                [System.Net.ServicePointManager]::CertificatePolicy = $originalCertificatePolicy
                Write-Verbose "Restored original certificate policy"
            }
        }
    }

    end {
        Write-Verbose "Completed Invoke-SESWebRequest"
    }
}