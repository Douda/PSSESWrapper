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

Describe 'Reset-SESConnection' -Tag 'Private' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            # Initialize global connection variable
            $Global:SESConnection = @{
                BaseURI = 'https://api.test.com'
                Token = 'test-token'
                TokenExpiry = (Get-Date).AddHours(1)
                IsConnected = $true
            }
        }
    }

    Context 'When resetting connection' {
        It 'Should clear the global connection object' {
            InModuleScope -ScriptBlock {
                Reset-SESConnection
                
                $Global:SESConnection.IsConnected | Should -Be $false
                $Global:SESConnection.Token | Should -Be $null
                $Global:SESConnection.TokenExpiry | Should -Be $null
                $Global:SESConnection.BaseURI | Should -Be $null
            }
        }

        It 'Should handle when connection object does not exist' {
            InModuleScope -ScriptBlock {
                Remove-Variable -Name 'SESConnection' -Scope Global -ErrorAction SilentlyContinue
                
                { Reset-SESConnection } | Should -Not -Throw
            }
        }
    }
}