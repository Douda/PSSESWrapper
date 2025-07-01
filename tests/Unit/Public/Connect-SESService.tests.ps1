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

Describe 'Connect-SESService' -Tag 'Public' {
    BeforeAll {
        # Mock the dependencies - Initialize connection with proper setup
        Mock -CommandName 'Initialize-SESConnection' -MockWith {
            if (-not $Global:SESConnection) {
                $Global:SESConnection = @{}
            }
            $Global:SESConnection.IsConnected = $false
            $Global:SESConnection.AuthToken = $null
            $Global:SESConnection.BaseUri = $null
            $Global:SESConnection.Region = $null
            $Global:SESConnection.RegionalEndpoints = @{
                'us' = 'https://api.sep.securitycloud.symantec.com'
                'eu' = 'https://api.sep.eu.securitycloud.symantec.com'
                'in' = 'https://api.sep.in.securitycloud.symantec.com'
            }
            $Global:SESConnection.TimeoutSec = 30
            $Global:SESConnection.TokenExpiry = $null
            $Global:SESConnection.RefreshToken = $null
            $Global:SESConnection.ClientId = $null
            $Global:SESConnection.ConnectedAt = $null
        } -ModuleName $script:dscModuleName

        Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
            return @{
                access_token = 'mock-access-token-12345'
                expires_in = 3600
                token_type = 'Bearer'
                refresh_token = 'mock-refresh-token'
            }
        } -ModuleName $script:dscModuleName

        Mock -CommandName 'Submit-SESRequest' -MockWith {
            return @{ status = 'healthy' }
        } -ModuleName $script:dscModuleName

        Mock -CommandName 'Update-SESConnectionActivity' -MockWith { } -ModuleName $script:dscModuleName
        Mock -CommandName 'Reset-SESConnection' -MockWith { } -ModuleName $script:dscModuleName
        Mock -CommandName 'Export-SESCredential' -MockWith { } -ModuleName $script:dscModuleName
        Mock -CommandName 'Import-SESCredential' -MockWith {
            return @{
                ClientId = 'stored-client-id'
                ClientSecret = 'stored-client-secret'
                Region = 'us'
            }
        } -ModuleName $script:dscModuleName

        Mock -CommandName 'Write-Information' -MockWith { } -ModuleName $script:dscModuleName
        Mock -CommandName 'Write-Warning' -MockWith { } -ModuleName $script:dscModuleName
    }

    BeforeEach {
        InModuleScope -ScriptBlock {
            # Reset global connection before each test
            Remove-Variable -Name 'SESConnection' -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }

    AfterEach {
        InModuleScope -ScriptBlock {
            # Clean up global connection after each test
            Remove-Variable -Name 'SESConnection' -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Parameter Validation' {
        It 'Should accept valid client credentials' {
            InModuleScope -ScriptBlock {
                { Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' } | Should -Not -Throw
            }
        }

        It 'Should throw when ClientId is null or empty' {
            InModuleScope -ScriptBlock {
                { Connect-SESService -ClientId '' -ClientSecret 'test-secret' } | Should -Throw
                { Connect-SESService -ClientId $null -ClientSecret 'test-secret' } | Should -Throw
            }
        }

        It 'Should throw when ClientSecret is null or empty' {
            InModuleScope -ScriptBlock {
                { Connect-SESService -ClientId 'test-client' -ClientSecret '' } | Should -Throw
                { Connect-SESService -ClientId 'test-client' -ClientSecret $null } | Should -Throw
            }
        }

        It 'Should accept valid regions' {
            InModuleScope -ScriptBlock {
                $validRegions = @('us', 'eu', 'in')
                foreach ($region in $validRegions) {
                    { Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region $region } | Should -Not -Throw
                }
            }
        }

        It 'Should reject invalid regions' {
            InModuleScope -ScriptBlock {
                { Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'invalid' } | Should -Throw
            }
        }

        It 'Should accept custom base URI' {
            InModuleScope -ScriptBlock {
                { Connect-SESService -BaseUri 'https://custom.api.endpoint.com' } | Should -Not -Throw
            }
        }
    }

    Context 'Credential Parameter Sets' {
        It 'Should use provided credentials when specified' {
            InModuleScope -ScriptBlock {
                $result = Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'us'
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -ParameterFilter {
                $Uri -match '/oauth2/tokens' -and 
                $Method -eq 'POST' -and
                $Body -match 'test-client'
            } -Times 1 -Exactly
        }

        It 'Should use stored credentials when UseStoredCredentials is specified' {
            InModuleScope -ScriptBlock {
                $result = Connect-SESService -UseStoredCredentials
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Import-SESCredential' -Times 1 -Exactly
            Should -Invoke -CommandName 'Invoke-SESWebRequest' -ParameterFilter {
                $Body -match 'stored-client-id'
            } -Times 1 -Exactly
        }

        It 'Should use custom base URI when specified' {
            InModuleScope -ScriptBlock {
                $customUri = 'https://custom.api.endpoint.com'
                $result = Connect-SESService -BaseUri $customUri
                $Global:SESConnection.BaseUri | Should -Be $customUri
                $Global:SESConnection.Region | Should -Be 'custom'
            }
        }
    }

    Context 'Authentication Process' {
        It 'Should make OAuth2 token request with correct parameters' {
            InModuleScope -ScriptBlock {
                Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'us'
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -ParameterFilter {
                $Uri -eq 'https://api.sep.securitycloud.symantec.com/v1/oauth2/tokens' -and
                $Method -eq 'POST' -and
                $ContentType -eq 'application/json' -and
                $Body -match '"client_id":"test-client"' -and
                $Body -match '"client_secret":"test-secret"' -and
                $Body -match '"grant_type":"client_credentials"'
            } -Times 1 -Exactly
        }

        It 'Should update connection object with authentication details' {
            InModuleScope -ScriptBlock {
                Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'us'
                
                $Global:SESConnection.AuthToken | Should -Be 'mock-access-token-12345'
                $Global:SESConnection.IsConnected | Should -Be $true
                $Global:SESConnection.ClientId | Should -Be 'test-client'
                $Global:SESConnection.Region | Should -Be 'us'
                $Global:SESConnection.BaseUri | Should -Be 'https://api.sep.securitycloud.symantec.com'
                $Global:SESConnection.ConnectedAt | Should -Not -BeNullOrEmpty
                $Global:SESConnection.TokenExpiry | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should perform health check after authentication' {
            InModuleScope -ScriptBlock {
                Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'us'
            }

            Should -Invoke -CommandName 'Submit-SESRequest' -ParameterFilter {
                $Uri -eq 'https://api.sep.securitycloud.symantec.com/v1/health' -and
                $Method -eq 'GET'
            } -Times 1 -Exactly
        }

        It 'Should save credentials when SaveCredentials is specified' {
            InModuleScope -ScriptBlock {
                Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'us' -SaveCredentials
            }

            Should -Invoke -CommandName 'Export-SESCredential' -ParameterFilter {
                $ClientId -eq 'test-client' -and
                $ClientSecret -eq 'test-secret' -and
                $Region -eq 'us'
            } -Times 1 -Exactly
        }
    }

    Context 'Connection State Management' {
        It 'Should return existing connection when already connected and Force not specified' {
            Mock -CommandName 'Initialize-SESConnection' -MockWith {
                if (-not $Global:SESConnection) {
                    $Global:SESConnection = @{}
                }
                $Global:SESConnection.IsConnected = $true
                $Global:SESConnection.AuthToken = 'existing-token'
                $Global:SESConnection.RegionalEndpoints = @{
                    'us' = 'https://api.sep.securitycloud.symantec.com'
                }
                $Global:SESConnection.TimeoutSec = 30
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                $result = Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret'
                $result.AuthToken | Should -Be 'existing-token'
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -Times 0 -Exactly
        }

        It 'Should force new connection when Force is specified' {
            Mock -CommandName 'Initialize-SESConnection' -MockWith {
                if (-not $Global:SESConnection) {
                    $Global:SESConnection = @{}
                }
                $Global:SESConnection.IsConnected = $true
                $Global:SESConnection.AuthToken = 'existing-token'
                $Global:SESConnection.RegionalEndpoints = @{
                    'us' = 'https://api.sep.securitycloud.symantec.com'
                }
                $Global:SESConnection.TimeoutSec = 30
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                $result = Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Force
                $result.AuthToken | Should -Be 'mock-access-token-12345'
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -Times 1 -Exactly
        }

        It 'Should reset connection on authentication failure' {
            Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
                throw 'Authentication failed'
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' } | Should -Throw
            }

            Should -Invoke -CommandName 'Reset-SESConnection' -Times 1 -Exactly
        }
    }

    Context 'Error Handling' {
        It 'Should throw when authentication fails' {
            Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
                return @{ error = 'invalid_client' }
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Connect-SESService -ClientId 'invalid-client' -ClientSecret 'invalid-secret' } | Should -Throw -ExpectedMessage '*No access token received*'
            }
        }

        It 'Should throw when no stored credentials are found' {
            Mock -CommandName 'Import-SESCredential' -MockWith {
                return $null
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Connect-SESService -UseStoredCredentials } | Should -Throw -ExpectedMessage '*No stored credentials found*'
            }
        }

        It 'Should handle network errors gracefully' {
            Mock -CommandName 'Invoke-SESWebRequest' -MockWith {
                throw [System.Net.WebException]::new('Network unreachable')
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' } | Should -Throw
            }

            Should -Invoke -CommandName 'Reset-SESConnection' -Times 1 -Exactly
        }
    }

    Context 'SSL Certificate Handling' {
        It 'Should pass SkipCertificateCheck to web request when specified' {
            InModuleScope -ScriptBlock {
                Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -SkipCertificateCheck
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -ParameterFilter {
                $SkipCertificateCheck -eq $true
            } -Times 1 -Exactly
        }
    }

    Context 'ShouldProcess Support' {
        It 'Should support WhatIf' {
            InModuleScope -ScriptBlock {
                $result = Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -WhatIf
                $result | Should -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'Invoke-SESWebRequest' -Times 0 -Exactly
        }
    }

    Context 'Verbose Output' {
        It 'Should write verbose messages when verbose preference is set' {
            InModuleScope -ScriptBlock {
                $VerbosePreference = 'Continue'
                $verboseOutput = Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Verbose 4>&1
                $verboseOutput | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Regional Endpoints' {
        It 'Should use correct endpoint for US region' {
            InModuleScope -ScriptBlock {
                Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'us'
                $Global:SESConnection.BaseUri | Should -Be 'https://api.sep.securitycloud.symantec.com'
            }
        }

        It 'Should use correct endpoint for EU region' {
            InModuleScope -ScriptBlock {
                Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'eu'
                $Global:SESConnection.BaseUri | Should -Be 'https://api.sep.eu.securitycloud.symantec.com'
            }
        }

        It 'Should use correct endpoint for India region' {
            InModuleScope -ScriptBlock {
                Connect-SESService -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'in'
                $Global:SESConnection.BaseUri | Should -Be 'https://api.sep.in.securitycloud.symantec.com'
            }
        }
    }
}

Describe 'Import-SESCredential' -Tag 'Private' {
    BeforeAll {
        Mock -CommandName 'Get-SESCredentialPath' -MockWith {
            return '/mock/path/ses-credentials.xml'
        } -ModuleName $script:dscModuleName

        Mock -CommandName 'Test-Path' -MockWith { $true } -ModuleName $script:dscModuleName
        Mock -CommandName 'Import-Clixml' -MockWith {
            return @{
                ClientId = 'stored-client-id'
                ClientSecret = 'stored-client-secret'
                Region = 'us'
                SavedAt = Get-Date
            }
        } -ModuleName $script:dscModuleName
    }

    Context 'Successful Import' {
        It 'Should import credentials from correct path' {
            InModuleScope -ScriptBlock {
                $result = Import-SESCredential
                $result | Should -Not -BeNullOrEmpty
                $result.ClientId | Should -Be 'stored-client-id'
            }

            Should -Invoke -CommandName 'Import-Clixml' -ParameterFilter {
                $Path -eq '/mock/path/ses-credentials.xml'
            } -Times 1 -Exactly
        }

        It 'Should return null when credential file does not exist' {
            Mock -CommandName 'Test-Path' -MockWith { $false } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                $result = Import-SESCredential
                $result | Should -BeNullOrEmpty
            }
        }

        It 'Should handle import errors gracefully' {
            Mock -CommandName 'Import-Clixml' -MockWith {
                throw 'File corrupted'
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                $result = Import-SESCredential
                $result | Should -BeNullOrEmpty
            }
        }
    }
}

Describe 'Export-SESCredential' -Tag 'Private' {
    BeforeAll {
        Mock -CommandName 'Get-SESCredentialPath' -MockWith {
            return '/mock/path/ses-credentials.xml'
        } -ModuleName $script:dscModuleName

        Mock -CommandName 'Export-Clixml' -MockWith { } -ModuleName $script:dscModuleName
    }

    Context 'Successful Export' {
        It 'Should export credentials to correct path' {
            InModuleScope -ScriptBlock {
                Export-SESCredential -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'us'
            }

            Should -Invoke -CommandName 'Export-Clixml' -ParameterFilter {
                $Path -eq '/mock/path/ses-credentials.xml' -and
                $Force -eq $true
            } -Times 1 -Exactly
        }

        It 'Should create credential object with all required properties' {
            InModuleScope -ScriptBlock {
                Export-SESCredential -ClientId 'test-client' -ClientSecret 'test-secret' -Region 'us'
            }

            Should -Invoke -CommandName 'Export-Clixml' -ParameterFilter {
                $InputObject.ClientId -eq 'test-client' -and
                $InputObject.ClientSecret -eq 'test-secret' -and
                $InputObject.Region -eq 'us' -and
                $InputObject.SavedAt -ne $null
            } -Times 1 -Exactly
        }

        It 'Should handle export errors' {
            Mock -CommandName 'Export-Clixml' -MockWith {
                throw 'Permission denied'
            } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Export-SESCredential -ClientId 'test-client' -ClientSecret 'test-secret' } | Should -Throw
            }
        }
    }
}