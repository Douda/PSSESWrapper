function Submit-SESRequest {
    <#
    .SYNOPSIS
    Submits REST API requests to the Symantec Endpoint Security (SES) service.

    .DESCRIPTION
    This function handles all HTTP requests to the SES API, including authentication,
    error handling, and response processing. It supports various HTTP methods and
    handles pagination automatically.

    .PARAMETER Uri
    The complete URI for the API endpoint.

    .PARAMETER Method
    The HTTP method to use (GET, POST, PUT, DELETE, PATCH).

    .PARAMETER Body
    The request body for POST/PUT/PATCH requests.

    .PARAMETER Headers
    Additional headers to include in the request.

    .PARAMETER ContentType
    The content type for the request. Defaults to 'application/json'.

    .PARAMETER TimeoutSec
    The timeout for the request in seconds. Defaults to 30.

    .PARAMETER SkipCertificateCheck
    Skip SSL certificate validation (for testing environments).

    .PARAMETER RetryCount
    Number of retry attempts for failed requests. Defaults to 3.

    .PARAMETER RetryDelay
    Delay between retry attempts in seconds. Defaults to 1.

    .EXAMPLE
    Submit-SESRequest -Uri "https://api.sep.securitycloud.symantec.com/v1/devices" -Method GET

    .EXAMPLE
    Submit-SESRequest -Uri "https://api.sep.securitycloud.symantec.com/v1/devices" -Method POST -Body $jsonBody

    .NOTES
    This function requires an active SES session established via Connect-SESService.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The complete URI for the API endpoint")]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory = $false, HelpMessage = "The HTTP method to use")]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
        [string]$Method = 'GET',

        [Parameter(Mandatory = $false, HelpMessage = "The request body for POST/PUT/PATCH requests")]
        [string]$Body,

        [Parameter(Mandatory = $false, HelpMessage = "Additional headers to include in the request")]
        [hashtable]$Headers = @{},

        [Parameter(Mandatory = $false, HelpMessage = "The content type for the request")]
        [string]$ContentType = 'application/json',

        [Parameter(Mandatory = $false, HelpMessage = "The timeout for the request in seconds")]
        [int]$TimeoutSec = 30,

        [Parameter(Mandatory = $false, HelpMessage = "Skip SSL certificate validation")]
        [switch]$SkipCertificateCheck,

        [Parameter(Mandatory = $false, HelpMessage = "Number of retry attempts for failed requests")]
        [int]$RetryCount = 3,

        [Parameter(Mandatory = $false, HelpMessage = "Delay between retry attempts in seconds")]
        [int]$RetryDelay = 1
    )

    begin {
        Write-Verbose "Starting Submit-SESRequest with URI: $Uri"
        
        # Validate connection
        if (-not $Global:SESConnection -or -not $Global:SESConnection.IsConnected) {
            throw "No active SES connection found. Please run Connect-SESService first."
        }

        # Prepare headers with authentication
        $requestHeaders = $Headers.Clone()
        if ($Global:SESConnection.AuthToken) {
            $requestHeaders['Authorization'] = "Bearer $($Global:SESConnection.AuthToken)"
        }
        
        # Add default headers
        $requestHeaders['Accept'] = 'application/json'
        $requestHeaders['User-Agent'] = "PSSESWrapper/$($MyInvocation.MyCommand.Module.Version)"
    }

    process {
        $attempt = 0
        $success = $false
        $lastError = $null

        while (-not $success -and $attempt -lt $RetryCount) {
            $attempt++
            Write-Verbose "Attempt $attempt of $RetryCount for $Method $Uri"

            try {
                $splat = @{
                    Uri         = $Uri
                    Method      = $Method
                    Headers     = $requestHeaders
                    ContentType = $ContentType
                    TimeoutSec  = $TimeoutSec
                }

                if ($Body) {
                    $splat['Body'] = $Body
                    Write-Verbose "Request body: $Body"
                }

                if ($SkipCertificateCheck) {
                    $splat['SkipCertificateCheck'] = $true
                }

                # Use Invoke-SESWebRequest for cross-platform compatibility
                $response = Invoke-SESWebRequest @splat
                $success = $true

                Write-Verbose "Request successful on attempt $attempt"
                return $response
            }
            catch {
                $lastError = $_
                Write-Warning "Request failed on attempt $attempt`: $($_.Exception.Message)"

                # Check if we should retry
                if ($attempt -lt $RetryCount) {
                    $statusCode = $null
                    if ($_.Exception.Response) {
                        $statusCode = $_.Exception.Response.StatusCode
                    }

                    # Only retry on specific status codes
                    $retryableStatusCodes = @(429, 500, 502, 503, 504)
                    if ($statusCode -in $retryableStatusCodes) {
                        Write-Verbose "Retryable status code $statusCode detected. Waiting $RetryDelay seconds before retry."
                        Start-Sleep -Seconds $RetryDelay
                    }
                    else {
                        Write-Verbose "Non-retryable error detected. Failing immediately."
                        break
                    }
                }
            }
        }

        # If we reach here, all attempts failed
        Write-Error "Request failed after $attempt attempts. Last error: $($lastError.Exception.Message)"
        throw $lastError
    }

    end {
        Write-Verbose "Completed Submit-SESRequest"
    }
}