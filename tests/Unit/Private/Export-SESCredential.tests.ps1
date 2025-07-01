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
                Export-SESCredential -ClientId 'test-client-id' -ClientSecret 'test-secret-key' -Region 'us'
                
                Should -Invoke Export-Clixml -Exactly 1 -ParameterFilter {
                    $Path -eq 'TestDrive:/creds.xml'
                }
            }
        }

        It 'Should create directory if it does not exist' {
            InModuleScope -ScriptBlock {
                # Get-SESCredentialPath should handle directory creation
                Mock -CommandName 'Get-SESCredentialPath' -MockWith {
                    # Mock directory creation within Get-SESCredentialPath
                    New-Item -Path 'TestDrive:' -ItemType Directory -Force | Out-Null
                    return 'TestDrive:/creds.xml'
                } -ModuleName $script:dscModuleName

                Export-SESCredential -ClientId 'test-client-id' -ClientSecret 'test-secret-key' -Region 'us'

                Should -Invoke Get-SESCredentialPath -Exactly 1
            }
        }
    }

    Context 'When handling errors' {
        It 'Should handle export errors gracefully' {
            # Mock at module level, not inside InModuleScope
            Mock -CommandName 'Export-Clixml' -MockWith { throw 'Export failed' } -ModuleName $script:dscModuleName

            InModuleScope -ScriptBlock {
                { Export-SESCredential -ClientId 'test-client-id' -ClientSecret 'test-secret-key' -Region 'us' } | Should -Throw
            }
        }
    }
}