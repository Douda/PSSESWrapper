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

Describe 'Invoke-SESWebRequest' -Tag 'Private' {
    BeforeAll {
        Mock -CommandName 'Invoke-RestMethod' -MockWith {
            return @{
                StatusCode = 200
                Content = @{ data = 'mock response' }
            }
        } -ModuleName $script:dscModuleName
    }

    Context 'Parameter Validation' {
        It 'Should accept valid URI parameter' {
            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri 'https://api.example.com' } | Should -Not -Throw
            }
        }

        It 'Should throw when URI is null or empty' {
            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri '' } | Should -Throw
                { Invoke-SESWebRequest -Uri $null } | Should -Throw
            }
        }

        It 'Should accept valid HTTP methods' {
            InModuleScope -ScriptBlock {
                $validMethods = @('GET', 'POST', 'PUT', 'DELETE', 'PATCH')
                foreach ($method in $validMethods) {
                    { Invoke-SESWebRequest -Uri 'https://api.test.com' -Method $method } | Should -Not -Throw
                }
            }
        }

        It 'Should reject invalid HTTP methods' {
            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri 'https://api.test.com' -Method 'INVALID' } | Should -Throw
            }
        }

        It 'Should accept valid timeout values' {
            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri 'https://api.test.com' -TimeoutSec 60 } | Should -Not -Throw
            }
        }

        It 'Should accept headers hashtable' {
            InModuleScope -ScriptBlock {
                $headers = @{ 'Authorization' = 'Bearer token123' }
                { Invoke-SESWebRequest -Uri 'https://api.test.com' -Headers $headers } | Should -Not -Throw
            }
        }
    }

    Context 'Success Scenarios' {
        It 'Should make successful GET request' {
            InModuleScope -ScriptBlock {
                $result = Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint'
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -Times 1 -Exactly
        }

        It 'Should make successful POST request with body' {
            InModuleScope -ScriptBlock {
                $body = '{"name": "test"}'
                $result = Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint' -Method 'POST' -Body $body
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $Method -eq 'POST' -and $Body -eq '{"name": "test"}'
            } -Times 1 -Exactly
        }

        It 'Should pass through custom headers' {
            InModuleScope -ScriptBlock {
                $headers = @{ 
                    'Authorization' = 'Bearer token123'
                    'X-Custom-Header' = 'CustomValue'
                }
                $result = Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint' -Headers $headers
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $Headers.ContainsKey('Authorization') -and 
                $Headers.ContainsKey('X-Custom-Header') -and
                $Headers['Authorization'] -eq 'Bearer token123'
            } -Times 1 -Exactly
        }

        It 'Should use specified content type' {
            InModuleScope -ScriptBlock {
                $result = Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint' -ContentType 'application/xml'
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $ContentType -eq 'application/xml'
            } -Times 1 -Exactly
        }

        It 'Should use specified timeout' {
            InModuleScope -ScriptBlock {
                $result = Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint' -TimeoutSec 45
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $TimeoutSec -eq 45
            } -Times 1 -Exactly
        }
    }

    Context 'PowerShell Version Compatibility' {
        BeforeAll {
            Mock -CommandName 'Write-Verbose' -MockWith { } -ModuleName $script:dscModuleName
        }

        It 'Should handle PowerShell Core SkipCertificateCheck' {
            Mock -CommandName 'Get-Variable' -ParameterFilter { $Name -eq 'PSVersionTable' } -MockWith {
                return @{ 
                    Value = @{ 
                        PSEdition = 'Core'
                        PSVersion = [Version]'7.0.0'
                    }
                }
            }

            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint' -SkipCertificateCheck } | Should -Not -Throw
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $SkipCertificateCheck -eq $true
            } -Times 1 -Exactly
        }

        It 'Should handle PowerShell 5.1 UseBasicParsing' {
            Mock -CommandName 'Get-Variable' -ParameterFilter { $Name -eq 'PSVersionTable' } -MockWith {
                return @{ 
                    Value = @{ 
                        PSEdition = 'Desktop'
                        PSVersion = [Version]'5.1.0'
                    }
                }
            }

            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint' -UseBasicParsing } | Should -Not -Throw
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $UseBasicParsing -eq $true
            } -Times 1 -Exactly
        }
    }

    Context 'Error Handling' {
        It 'Should handle WebException with detailed error information' {
            Mock -CommandName 'Invoke-RestMethod' -MockWith {
                $webException = [System.Net.WebException]::new('Request failed')
                
                # Create a mock response object
                $response = New-Object PSObject
                $response | Add-Member -MemberType NoteProperty -Name 'StatusCode' -Value 404
                $response | Add-Member -MemberType NoteProperty -Name 'StatusDescription' -Value 'Not Found'
                
                # Mock GetResponseStream method
                $response | Add-Member -MemberType ScriptMethod -Name 'GetResponseStream' -Value {
                    $stream = New-Object System.IO.MemoryStream
                    $writer = New-Object System.IO.StreamWriter($stream)
                    $writer.Write('{"error": "Resource not found"}')
                    $writer.Flush()
                    $stream.Position = 0
                    return $stream
                }
                
                $webException | Add-Member -MemberType NoteProperty -Name 'Response' -Value $response
                throw $webException
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri 'https://api.test.com/nonexistent' } | Should -Throw
            }
        }

        It 'Should handle general exceptions' {
            Mock -CommandName 'Invoke-RestMethod' -MockWith {
                throw [System.Exception]::new('General error occurred')
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint' } | Should -Throw
            }
        }

        It 'Should handle timeout exceptions' {
            Mock -CommandName 'Invoke-RestMethod' -MockWith {
                throw [System.TimeoutException]::new('Request timed out')
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri 'https://api.test.com/slow-endpoint' } | Should -Throw
            }
        }
    }

    Context 'SSL Certificate Handling' {
        BeforeAll {
            Mock -CommandName 'Add-Type' -MockWith { } -ModuleName $script:dscModuleName
            Mock -CommandName 'New-Object' -ParameterFilter { $TypeName -eq 'TrustAllCertsPolicy' } -MockWith {
                return New-Object PSObject
            } -ModuleName $script:dscModuleName
        }

        It 'Should handle SSL certificate bypass in PowerShell 5.1' {
            Mock -CommandName 'Get-Variable' -ParameterFilter { $Name -eq 'PSVersionTable' } -MockWith {
                return @{ 
                    Value = @{ 
                        PSEdition = 'Desktop'
                        PSVersion = [Version]'5.1.0'
                    }
                }
            }

            InModuleScope -ScriptBlock {
                { Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint' -SkipCertificateCheck } | Should -Not -Throw
            }

            Should -Invoke -CommandName 'Add-Type' -Times 1 -Exactly
        }
    }

    Context 'Verbose Output' {
        It 'Should write verbose messages when verbose preference is set' {
            InModuleScope -ScriptBlock {
                $VerbosePreference = 'Continue'
                $verboseOutput = Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint' -Verbose 4>&1
                $verboseOutput | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Default Parameter Values' {
        It 'Should use GET as default method' {
            InModuleScope -ScriptBlock {
                Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint'
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $Method -eq 'GET'
            } -Times 1 -Exactly
        }

        It 'Should use application/json as default content type' {
            InModuleScope -ScriptBlock {
                Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint'
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $ContentType -eq 'application/json'
            } -Times 1 -Exactly
        }

        It 'Should use 30 seconds as default timeout' {
            InModuleScope -ScriptBlock {
                Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint'
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $TimeoutSec -eq 30
            } -Times 1 -Exactly
        }

        It 'Should use empty hashtable as default headers' {
            InModuleScope -ScriptBlock {
                Invoke-SESWebRequest -Uri 'https://api.test.com/endpoint'
            }

            Should -Invoke -CommandName 'Invoke-RestMethod' -ParameterFilter {
                $Headers -is [hashtable] -and $Headers.Count -eq 0
            } -Times 1 -Exactly
        }
    }
}