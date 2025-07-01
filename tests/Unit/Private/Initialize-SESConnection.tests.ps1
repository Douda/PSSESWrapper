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

Describe 'Initialize-SESConnection' -Tag 'Private' {
    BeforeEach {
        InModuleScope -ScriptBlock {
            # Clear any existing global connection
            Reset-SESConnection
        }
    }

    AfterEach {
        InModuleScope -ScriptBlock {
            # Clean up global connection after each test
            Remove-Variable -Name 'SESConnection' -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Basic Functionality' {
        It 'Should create global SES connection object' {
            InModuleScope -ScriptBlock {
                $result = Initialize-SESConnection
                $Global:SESConnection | Should -Not -BeNullOrEmpty
                $result | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should return existing connection when already initialized' {
            InModuleScope -ScriptBlock {
                # Initialize first connection
                $first = Initialize-SESConnection
                $firstId = $Global:SESConnection.ConnectionId

                # Initialize second connection without Force
                $second = Initialize-SESConnection
                $secondId = $Global:SESConnection.ConnectionId

                $firstId | Should -Be $secondId
                $first.ConnectionId | Should -Be $second.ConnectionId
            }
        }

        It 'Should create new connection when Force is specified' {
            InModuleScope -ScriptBlock {
                # Initialize first connection
                $first = Initialize-SESConnection
                $firstId = $Global:SESConnection.ConnectionId

                # Initialize second connection with Force
                $second = Initialize-SESConnection -Force
                $secondId = $Global:SESConnection.ConnectionId

                $firstId | Should -Not -Be $secondId
                $first.ConnectionId | Should -Not -Be $second.ConnectionId
            }
        }
    }

    Context 'Connection Object Properties' {
        BeforeEach {
            InModuleScope -ScriptBlock {
                Initialize-SESConnection
            }
        }

        It 'Should initialize with correct default values' {
            InModuleScope -ScriptBlock {
                $Global:SESConnection.IsConnected | Should -Be $false
                $Global:SESConnection.ConnectedAt | Should -BeNullOrEmpty
                $Global:SESConnection.AuthToken | Should -BeNullOrEmpty
                $Global:SESConnection.ApiVersion | Should -Be 'v1'
                $Global:SESConnection.TimeoutSec | Should -Be 30
                $Global:SESConnection.RetryCount | Should -Be 3
                $Global:SESConnection.RetryDelay | Should -Be 1
            }
        }

        It 'Should have regional endpoints configured' {
            InModuleScope -ScriptBlock {
                $Global:SESConnection.RegionalEndpoints | Should -Not -BeNullOrEmpty
                $Global:SESConnection.RegionalEndpoints['us'] | Should -Be 'https://api.sep.securitycloud.symantec.com'
                $Global:SESConnection.RegionalEndpoints['eu'] | Should -Be 'https://api.sep.eu.securitycloud.symantec.com'
                $Global:SESConnection.RegionalEndpoints['in'] | Should -Be 'https://api.sep.in.securitycloud.symantec.com'
            }
        }

        It 'Should have unique ConnectionId' {
            InModuleScope -ScriptBlock {
                $Global:SESConnection.ConnectionId | Should -Not -BeNullOrEmpty
                $Global:SESConnection.ConnectionId | Should -Match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            }
        }

        It 'Should have platform information' {
            InModuleScope -ScriptBlock {
                $Global:SESConnection.PSVersion | Should -Not -BeNullOrEmpty
                $Global:SESConnection.PSEdition | Should -Not -BeNullOrEmpty
                $Global:SESConnection.Platform | Should -Not -BeNullOrEmpty
            }
        }

        It 'Should have credential path set' {
            InModuleScope -ScriptBlock {
                $Global:SESConnection.CredentialPath | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Verbose Output' {
        It 'Should write verbose messages when verbose preference is set' {
            InModuleScope -ScriptBlock {
                $VerbosePreference = 'Continue'
                $verboseOutput = Initialize-SESConnection -Verbose 4>&1
                $verboseOutput | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'Get-SESCredentialPath' -Tag 'Private' {
    BeforeAll {
        Mock -CommandName 'Test-Path' -MockWith { return $false }
        Mock -CommandName 'New-Item' -MockWith { return @{ FullName = $Path } }
    }

    Context 'Cross-Platform Path Generation' {
        It 'Should return valid path for Windows PowerShell 5.1' {
            Mock -CommandName 'Get-Variable' -ParameterFilter { $Name -eq 'PSVersionTable' } -MockWith {
                return @{ 
                    Value = @{ 
                        PSVersion = [Version]'5.1.0'
                        PSEdition = 'Desktop'
                    }
                }
            }

            InModuleScope -ScriptBlock {
                $result = Get-SESCredentialPath
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Match 'PSSESWrapper'
                $result | Should -Match 'ses-credentials\.xml$'
            }
        }

        It 'Should return valid path for PowerShell Core on Linux' {
            Mock -CommandName 'Get-Variable' -ParameterFilter { $Name -eq 'PSVersionTable' } -MockWith {
                return @{ 
                    Value = @{ 
                        PSVersion = [Version]'7.0.0'
                        PSEdition = 'Core'
                    }
                }
            }
            Mock -CommandName 'Get-Variable' -ParameterFilter { $Name -eq 'IsLinux' } -MockWith {
                return @{ Value = $true }
            }
            Mock -CommandName 'Get-Variable' -ParameterFilter { $Name -eq 'IsWindows' } -MockWith {
                return @{ Value = $false }
            }

            InModuleScope -ScriptBlock {
                $result = Get-SESCredentialPath
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Match 'PSSESWrapper'
                $result | Should -Match 'ses-credentials\.xml$'
            }
        }

        It 'Should create directory if it does not exist' {
            InModuleScope -ScriptBlock {
                $result = Get-SESCredentialPath
                $result | Should -Not -BeNullOrEmpty
            }

            Should -Invoke -CommandName 'New-Item' -Times 1 -Exactly
        }

        It 'Should handle errors gracefully and return fallback path' {
            Mock -CommandName 'New-Item' -MockWith {
                throw 'Directory creation failed'
            }

            InModuleScope -ScriptBlock {
                $result = Get-SESCredentialPath
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Match 'ses-credentials\.xml$'
            }
        }
    }

    Context 'Path Validation' {
        It 'Should return path ending with ses-credentials.xml' {
            InModuleScope -ScriptBlock {
                $result = Get-SESCredentialPath
                $result | Should -Match 'ses-credentials\.xml$'
            }
        }

        It 'Should return absolute path' {
            InModuleScope -ScriptBlock {
                $result = Get-SESCredentialPath
                [System.IO.Path]::IsPathFullyQualified($result) | Should -Be $true
            }
        }
    }
}

Describe 'Reset-SESConnection' -Tag 'Private' {
    BeforeEach {
        InModuleScope -ScriptBlock {
            # Initialize connection for testing
            Initialize-SESConnection
            $Global:SESConnection.IsConnected = $true
            $Global:SESConnection.AuthToken = 'test-token'
            $Global:SESConnection.ClientId = 'test-client'
            $Global:SESConnection.Region = 'us'
            $Global:SESConnection.BaseUri = 'https://api.test.com'
        }
    }

    AfterEach {
        InModuleScope -ScriptBlock {
            Remove-Variable -Name 'SESConnection' -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Basic Reset Functionality' {
        It 'Should reset connection status' {
            InModuleScope -ScriptBlock {
                Reset-SESConnection
                $Global:SESConnection.IsConnected | Should -Be $false
                $Global:SESConnection.ConnectedAt | Should -BeNullOrEmpty
                $Global:SESConnection.AuthToken | Should -BeNullOrEmpty
                $Global:SESConnection.ClientId | Should -BeNullOrEmpty
            }
        }

        It 'Should clear authentication tokens' {
            InModuleScope -ScriptBlock {
                Reset-SESConnection
                $Global:SESConnection.AuthToken | Should -BeNullOrEmpty
                $Global:SESConnection.RefreshToken | Should -BeNullOrEmpty
                $Global:SESConnection.TokenExpiry | Should -BeNullOrEmpty
            }
        }

        It 'Should generate new ConnectionId' {
            InModuleScope -ScriptBlock {
                $originalId = $Global:SESConnection.ConnectionId
                Reset-SESConnection
                $Global:SESConnection.ConnectionId | Should -Not -Be $originalId
            }
        }

        It 'Should update LastActivity' {
            InModuleScope -ScriptBlock {
                $originalActivity = $Global:SESConnection.LastActivity
                Start-Sleep -Milliseconds 100
                Reset-SESConnection
                $Global:SESConnection.LastActivity | Should -BeGreaterThan $originalActivity
            }
        }
    }

    Context 'Preserve Configuration' {
        It 'Should preserve configuration when PreserveConfig is specified' {
            InModuleScope -ScriptBlock {
                $originalRegion = $Global:SESConnection.Region
                $originalBaseUri = $Global:SESConnection.BaseUri
                $originalTimeout = $Global:SESConnection.TimeoutSec

                Reset-SESConnection -PreserveConfig

                $Global:SESConnection.Region | Should -Be $originalRegion
                $Global:SESConnection.BaseUri | Should -Be $originalBaseUri
                $Global:SESConnection.TimeoutSec | Should -Be $originalTimeout
            }
        }

        It 'Should reset configuration when PreserveConfig is not specified' {
            InModuleScope -ScriptBlock {
                Reset-SESConnection

                $Global:SESConnection.Region | Should -BeNullOrEmpty
                $Global:SESConnection.BaseUri | Should -BeNullOrEmpty
                $Global:SESConnection.TimeoutSec | Should -Be 30
            }
        }
    }

    Context 'Error Handling' {
        It 'Should handle missing connection object gracefully' {
            InModuleScope -ScriptBlock {
                Remove-Variable -Name 'SESConnection' -Scope Global -Force -ErrorAction SilentlyContinue
                { Reset-SESConnection } | Should -Not -Throw
            }
        }
    }
}

Describe 'Update-SESConnectionActivity' -Tag 'Private' {
    BeforeEach {
        InModuleScope -ScriptBlock {
            Initialize-SESConnection
        }
    }

    AfterEach {
        InModuleScope -ScriptBlock {
            Remove-Variable -Name 'SESConnection' -Scope Global -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Activity Update' {
        It 'Should update LastActivity timestamp' {
            InModuleScope -ScriptBlock {
                $originalActivity = $Global:SESConnection.LastActivity
                Start-Sleep -Milliseconds 100
                Update-SESConnectionActivity
                $Global:SESConnection.LastActivity | Should -BeGreaterThan $originalActivity
            }
        }

        It 'Should handle missing connection object gracefully' {
            InModuleScope -ScriptBlock {
                Remove-Variable -Name 'SESConnection' -Scope Global -Force -ErrorAction SilentlyContinue
                { Update-SESConnectionActivity } | Should -Not -Throw
            }
        }
    }

    Context 'Verbose Output' {
        It 'Should write verbose messages when verbose preference is set' {
            InModuleScope -ScriptBlock {
                $VerbosePreference = 'Continue'
                $verboseOutput = Update-SESConnectionActivity -Verbose 4>&1
                $verboseOutput | Should -Not -BeNullOrEmpty
            }
        }
    }
}