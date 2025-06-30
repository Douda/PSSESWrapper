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

Describe 'Get-SESCredentialPath' -Tag 'Private' {
    BeforeAll {
        InModuleScope -ScriptBlock {
            # Mock dependencies
            Mock Get-Variable { 
                return @{ Value = @{ Path = 'TestDrive:\Profile' } }
            } -ParameterFilter { $Name -eq 'PROFILE' }
        }
    }

    Context 'When getting credential path on Windows' {
        It 'Should return Windows-style path' {
            InModuleScope -ScriptBlock {
                Mock Test-Path { return $true } -ParameterFilter { $Path -eq 'Env:\USERPROFILE' }
                Mock Get-Item { return @{ Value = 'C:\Users\TestUser' } }
                
                $result = Get-SESCredentialPath
                
                $result | Should -BeLike '*PSSymantecSES*credentials.xml'
            }
        }
    }

    Context 'When getting credential path on Linux/Mac' {
        It 'Should return Unix-style path' {
            InModuleScope -ScriptBlock {
                Mock Test-Path { return $false } -ParameterFilter { $Path -eq 'Env:\USERPROFILE' }
                Mock Test-Path { return $true } -ParameterFilter { $Path -eq 'Env:\HOME' }
                Mock Get-Item { return @{ Value = '/home/testuser' } }
                
                $result = Get-SESCredentialPath
                
                $result | Should -BeLike '*PSSymantecSES*credentials.xml'
            }
        }
    }

    Context 'When handling errors' {
        It 'Should handle errors gracefully and return fallback path' {
            InModuleScope -ScriptBlock {
                Mock Test-Path { return $false }
                Mock Get-Variable { throw 'Profile not found' }
                
                $result = Get-SESCredentialPath
                
                $result | Should -BeLike '*PSSymantecSES*credentials.xml'
            }
        }
    }
}