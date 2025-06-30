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

    # Unload the module being tested so that it doesn't impact other tests.
    Get-Module -Name $script:dscModuleName -All | Remove-Module -Force
}

Describe 'Export-SESCredentials' -Tag 'Private' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            # Mock dependencies
            Mock Export-Clixml {}
            Mock Get-SESCredentialPath { return 'TestDrive:\creds.xml' }
            Mock New-Item {}
            Mock Split-Path { return 'TestDrive:' }
        }
    }

    Context 'When exporting credentials successfully' {
        It 'Should export credentials to the correct path' {
            InModuleScope -ScriptBlock {
                $testCredentials = @{
                    ClientId = 'test-client-id'
                    SecretKey = 'test-secret-key'
                    Region = 'us'
                }
                
                Export-SESCredentials -Credentials $testCredentials
                
                Should -Invoke Export-Clixml -Exactly 1 -ParameterFilter {
                    $Path -eq 'TestDrive:\creds.xml'
                }
            }
        }

        It 'Should create directory if it does not exist' {
            InModuleScope -ScriptBlock {
                Mock Test-Path { return $false }
                
                $testCredentials = @{
                    ClientId = 'test-client-id'
                    SecretKey = 'test-secret-key'
                    Region = 'us'
                }
                
                Export-SESCredentials -Credentials $testCredentials
                
                Should -Invoke New-Item -Exactly 1 -ParameterFilter {
                    $ItemType -eq 'Directory'
                }
            }
        }
    }

    Context 'When handling errors' {
        It 'Should handle export errors gracefully' {
            InModuleScope -ScriptBlock {
                Mock Export-Clixml { throw 'Export failed' }
                
                $testCredentials = @{
                    ClientId = 'test-client-id'
                    SecretKey = 'test-secret-key'
                    Region = 'us'
                }
                
                { Export-SESCredentials -Credentials $testCredentials } | Should -Throw
            }
        }
    }
}