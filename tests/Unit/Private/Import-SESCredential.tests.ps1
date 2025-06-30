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

Describe 'Import-SESCredential' -Tag 'Private' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            # Mock dependencies
            Mock Get-SESCredentialPath { return 'TestDrive:\creds.xml' }
            Mock Test-Path { return $true }
            Mock Import-Clixml {
                return @{
                    ClientId = 'test-client-id'
                    SecretKey = 'test-secret-key'
                    Region = 'us'
                }
            }
        }
    }

    Context 'When importing credentials successfully' {
        It 'Should import credentials from the correct path' {
            InModuleScope -ScriptBlock {
                $result = Import-SESCredential
                
                Should -Invoke Import-Clixml -Exactly 1 -ParameterFilter {
                    $Path -eq 'TestDrive:\creds.xml'
                }
                
                $result.ClientId | Should -Be 'test-client-id'
                $result.SecretKey | Should -Be 'test-secret-key'
                $result.Region | Should -Be 'us'
            }
        }

        It 'Should return null when credential file does not exist' {
            InModuleScope -ScriptBlock {
                Mock Test-Path { return $false }
                
                $result = Import-SESCredential
                
                $result | Should -Be $null
            }
        }
    }

    Context 'When handling errors' {
        It 'Should handle import errors gracefully' {
            InModuleScope -ScriptBlock {
                Mock Import-Clixml { throw 'Import failed' }
                
                $result = Import-SESCredential
                
                $result | Should -Be $null
            }
        }
    }
}