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

Describe 'Export-SESCredential' -Tag 'Private' {
    BeforeAll {
        # Mock dependencies at module level
        Mock -CommandName 'Export-Clixml' -MockWith { } -ModuleName $script:dscModuleName
        Mock -CommandName 'Get-SESCredentialPath' -MockWith { return 'TestDrive:/creds.xml' } -ModuleName $script:dscModuleName
        Mock -CommandName 'New-Item' -MockWith { } -ModuleName $script:dscModuleName
        Mock -CommandName 'Split-Path' -MockWith { return 'TestDrive:' } -ModuleName $script:dscModuleName
        Mock -CommandName 'Test-Path' -MockWith { return $true } -ModuleName $script:dscModuleName
    }

    Context 'When exporting credentials successfully' {
        It 'Should export credentials to the correct path' {
            InModuleScope -ScriptBlock {
                $testCredentials = @{
                    ClientId = 'test-client-id'
                    SecretKey = 'test-secret-key'
                    Region = 'us'
                }
                
                Export-SESCredential -Credentials $testCredentials
                
                Should -Invoke Export-Clixml -Exactly 1 -ParameterFilter {
                    $Path -eq 'TestDrive:/creds.xml'
                }
            }
        }

        It 'Should create directory if it does not exist' {
            InModuleScope -ScriptBlock {
                Mock -CommandName 'Test-Path' -MockWith { return $false } -ModuleName $script:dscModuleName
                
                $testCredentials = @{
                    ClientId = 'test-client-id'
                    SecretKey = 'test-secret-key'
                    Region = 'us'
                }
                
                Export-SESCredential -Credentials $testCredentials
                
                Should -Invoke New-Item -Exactly 1 -ParameterFilter {
                    $ItemType -eq 'Directory'
                }
            }
        }
    }

    Context 'When handling errors' {
        It 'Should handle export errors gracefully' {
            InModuleScope -ScriptBlock {
                Mock -CommandName 'Export-Clixml' -MockWith { throw 'Export failed' } -ModuleName $script:dscModuleName
                
                $testCredentials = @{
                    ClientId = 'test-client-id'
                    SecretKey = 'test-secret-key'
                    Region = 'us'
                }
                
                { Export-SESCredential -Credentials $testCredentials } | Should -Throw
            }
        }
    }
}