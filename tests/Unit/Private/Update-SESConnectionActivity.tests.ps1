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

Describe 'Update-SESConnectionActivity' -Tag 'Private' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            # Initialize global connection variable
            $Global:SESConnection = @{
                BaseURI = 'https://api.test.com'
                Token = 'test-token'
                TokenExpiry = (Get-Date).AddHours(1)
                IsConnected = $true
                LastActivity = (Get-Date).AddMinutes(-10)
            }
        }
    }

    Context 'When updating connection activity' {
        It 'Should update the LastActivity timestamp' {
            InModuleScope -ScriptBlock {
                $beforeUpdate = $Global:SESConnection.LastActivity
                Start-Sleep -Milliseconds 100
                
                Update-SESConnectionActivity
                
                $Global:SESConnection.LastActivity | Should -BeGreaterThan $beforeUpdate
            }
        }

        It 'Should handle when connection object does not exist' {
            InModuleScope -ScriptBlock {
                Remove-Variable -Name 'SESConnection' -Scope Global -ErrorAction SilentlyContinue
                
                { Update-SESConnectionActivity } | Should -Not -Throw
            }
        }

        It 'Should handle when LastActivity property does not exist' {
            InModuleScope -ScriptBlock {
                $Global:SESConnection = @{
                    IsConnected = $true
                }
                
                { Update-SESConnectionActivity } | Should -Not -Throw
                $Global:SESConnection.LastActivity | Should -Not -Be $null
            }
        }
    }
}