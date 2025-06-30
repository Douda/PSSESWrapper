BeforeAll {
    $script:dscModuleName = 'PSSymantecSES'

    Import-Module -Name $script:dscModuleName -Force -ErrorAction 'Stop'

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:dscModuleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:dscModuleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    # Unload the module being tested so that it doesn't impact any other tests.
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Submit-SESRequest' -Tag 'Private' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            # Mock the global connection object
            $Global:SESConnection = @{
                IsConnected = $true
                AuthToken = 'mock-token-12345'
                BaseUri = 'https://api.sep.securitycloud.symantec.com'
            }
        }

        Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
            return @{
                StatusCode = 200
                Content = '{"data": "mock response"}'
                Headers = @{}
            }
        } -ModuleName $script:dscModuleName
    }

    AfterAll {
        InModuleScope -ScriptBlock {
            Remove-Variable -Name 'SESConnection' -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Parameter Validation' {
        It 'Should accept valid URI parameter' {
            InModuleScope -ScriptBlock {
                { Submit-SESRequest -Uri 'https://api.sep.securitycloud.symantec.com/v1/devices' } | Should -Not -Throw
            }
        }

        It 'Should throw when URI is null or empty' {
            InModuleScope -ScriptBlock {
                { Submit-SESRequest -Uri '' } | Should -Throw
                { Submit-SESRequest -Uri $null } | Should -Throw
            }
        }

        It 'Should accept valid HTTP methods' {
            InModuleScope -ScriptBlock {
                $validMethods = @('GET', 'POST', 'PUT', 'DELETE', 'PATCH')
                foreach ($method in $validMethods) {
                    { Submit-SESRequest -Uri 'https://api.test.com' -Method $method } | Should -Not -Throw
                }
            }
        }

        It 'Should reject invalid HTTP methods' {
            InModuleScope -ScriptBlock {
                { Submit-SESRequest -Uri 'https://api.test.com' -Method 'INVALID' } | Should -Throw
            }
        }

        It 'Should accept valid timeout values' {
            InModuleScope -ScriptBlock {
                { Submit-SESRequest -Uri 'https://api.test.com' -TimeoutSec 60 } | Should -Not -Throw
            }
        }
    }

    Context 'Connection Validation' {
        It 'Should throw when no global connection exists' {
            InModuleScope -ScriptBlock {
                Remove-Variable -Name 'SESConnection' -Scope Global -Force -ErrorAction SilentlyContinue
                { Submit-SESRequest -Uri 'https://api.test.com' } | Should -Throw -ExpectedMessage '*No active SES connection found*'
            }
        }

        It 'Should throw when connection is not active' {
            InModuleScope -ScriptBlock {
                $Global:SESConnection = @{
                    IsConnected = $false
                    AuthToken = 'mock-token'
                }
                { Submit-SESRequest -Uri 'https://api.test.com' } | Should -Throw -ExpectedMessage '*No active SES connection found*'
            }
        }
    }

    Context 'Success Scenarios' {
        BeforeEach {
            InModuleScope -ScriptBlock {
                $Global:SESConnection = @{
                    IsConnected = $true
                    AuthToken = 'mock-token-12345'
                    BaseUri = 'https://api.sep.securitycloud.symantec.com'
                }
            }
        }

        It 'Should make successful GET request' {
            InModuleScope -ScriptBlock {
                $result = Submit-SESRequest -Uri 'https://api.test.com/devices'
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -Times 1 -Exactly
        }

        It 'Should make successful POST request with body' {
            InModuleScope -ScriptBlock {
                $body = '{"name": "test"}'
                $result = Submit-SESRequest -Uri 'https://api.test.com/devices' -Method 'POST' -Body $body
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -Times 1 -Exactly
        }

        It 'Should include authorization header' {
            InModuleScope -ScriptBlock {
                Submit-SESRequest -Uri 'https://api.test.com/devices'
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -ParameterFilter {
                $Headers.ContainsKey('Authorization') -and $Headers['Authorization'] -eq 'Bearer mock-token-12345'
            } -Times 1 -Exactly
        }

        It 'Should include default headers' {
            InModuleScope -ScriptBlock {
                Submit-SESRequest -Uri 'https://api.test.com/devices'
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -ParameterFilter {
                $Headers.ContainsKey('Accept') -and $Headers['Accept'] -eq 'application/json'
            } -Times 1 -Exactly
        }

        It 'Should merge custom headers with default headers' {
            InModuleScope -ScriptBlock {
                $customHeaders = @{ 'X-Custom-Header' = 'CustomValue' }
                Submit-SESRequest -Uri 'https://api.test.com/devices' -Headers $customHeaders
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -ParameterFilter {
                $Headers.ContainsKey('X-Custom-Header') -and 
                $Headers.ContainsKey('Authorization') -and 
                $Headers.ContainsKey('Accept')
            } -Times 1 -Exactly
        }
    }

    Context 'Error Handling' {
        BeforeEach {
            InModuleScope -ScriptBlock {
                $Global:SESConnection = @{
                    IsConnected = $true
                    AuthToken = 'mock-token-12345'
                    BaseUri = 'https://api.sep.securitycloud.symantec.com'
                }
            }
        }

        It 'Should handle network errors' {
            Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
                throw [System.Net.WebException]::new('Network error')
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Submit-SESRequest -Uri 'https://api.test.com/devices' } | Should -Throw
            }
        }

        It 'Should retry on retryable status codes' {
            Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
                $exception = [System.Net.WebException]::new('Server error')
                $response = [PSCustomObject]@{ StatusCode = 503 }
                $exception | Add-Member -MemberType NoteProperty -Name 'Response' -Value $response -Force
                throw $exception
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Submit-SESRequest -Uri 'https://api.test.com/devices' -RetryCount 2 } | Should -Throw
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -Times 2 -Exactly
        }

        It 'Should not retry on non-retryable status codes' {
            Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
                $exception = [System.Net.WebException]::new('Client error')
                $response = [PSCustomObject]@{ StatusCode = 400 }
                $exception | Add-Member -MemberType NoteProperty -Name 'Response' -Value $response -Force
                throw $exception
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Submit-SESRequest -Uri 'https://api.test.com/devices' -RetryCount 3 } | Should -Throw
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -Times 1 -Exactly
        }
    }

    Context 'Retry Logic' {
        BeforeEach {
            InModuleScope -ScriptBlock {
                $Global:SESConnection = @{
                    IsConnected = $true
                    AuthToken = 'mock-token-12345'
                    BaseUri = 'https://api.sep.securitycloud.symantec.com'
                }
            }
        }

        It 'Should succeed on second attempt' {
            $script:callCount = 0
            Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    $exception = [System.Net.WebException]::new('Temporary error')
                    $response = [PSCustomObject]@{ StatusCode = 503 }
                    $exception | Add-Member -MemberType NoteProperty -Name 'Response' -Value $response -Force
                    throw $exception
                }
                return @{
                    StatusCode = 200
                    Content = '{"success": true}'
                }
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                $result = Submit-SESRequest -Uri 'https://api.test.com/devices' -RetryCount 2
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -Times 2 -Exactly
        }

        It 'Should respect custom retry count' {
            Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
                $exception = [System.Net.WebException]::new('Server error')
                $response = [PSCustomObject]@{ StatusCode = 503 }
                $exception | Add-Member -MemberType NoteProperty -Name 'Response' -Value $response -Force
                throw $exception
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Submit-SESRequest -Uri 'https://api.test.com/devices' -RetryCount 5 } | Should -Throw
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -Times 5 -Exactly
        }
    }

    Context 'Verbose Output' {
        BeforeEach {
            InModuleScope -ScriptBlock {
                $Global:SESConnection = @{
                    IsConnected = $true
                    AuthToken = 'mock-token-12345'
                    BaseUri = 'https://api.sep.securitycloud.symantec.com'
                }
            }
        }

        It 'Should write verbose messages when verbose preference is set' {
            InModuleScope -ScriptBlock {
                $VerbosePreference = 'Continue'
                $verboseOutput = Submit-SESRequest -Uri 'https://api.test.com/devices' -Verbose 4>&1
                $verboseOutput | Should -Not -BeNullOrEmpty
            }
        }
    }
}