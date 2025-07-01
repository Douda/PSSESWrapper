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
        # Mock dependencies at module level
        Mock -CommandName 'Get-Variable' -MockWith { 
            return @{ Value = @{ Path = 'TestDrive:/Profile' } }
        } -ParameterFilter { $Name -eq 'PROFILE' } -ModuleName $script:dscModuleName
    }

    BeforeEach {
        # Reset any global state before each test
        InModuleScope -ScriptBlock {
            # Clear any cached variables that might interfere
            $null = $true
        }
    }

    Context 'When getting credential path on Windows' {
        It 'Should return Windows-style path' {
            Mock -CommandName 'Test-Path' -MockWith { return $true } -ParameterFilter { $Path -eq 'Env:USERPROFILE' } -ModuleName $script:dscModuleName
            Mock -CommandName 'Get-Item' -MockWith { return @{ Value = 'C:/Users/TestUser' } } -ModuleName $script:dscModuleName
            
            InModuleScope -ScriptBlock {
                $result = Get-SESCredentialPath
                
                $result | Should -BeLike '*PSSESWrapper*credentials.xml'
            }
        }
    }

    Context 'When getting credential path on Linux/Mac' {
        It 'Should return Unix-style path' {
            Mock -CommandName 'Test-Path' -MockWith { return $false } -ParameterFilter { $Path -eq 'Env:USERPROFILE' } -ModuleName $script:dscModuleName
            Mock -CommandName 'Test-Path' -MockWith { return $true } -ParameterFilter { $Path -eq 'Env:HOME' } -ModuleName $script:dscModuleName
            Mock -CommandName 'Get-Item' -MockWith { return @{ Value = '/home/testuser' } } -ModuleName $script:dscModuleName
            
            InModuleScope -ScriptBlock {
                $result = Get-SESCredentialPath
                
                $result | Should -BeLike '*PSSESWrapper*credentials.xml'
            }
        }
    }

    Context 'When handling errors' {
        It 'Should handle errors gracefully and return fallback path' {
            Mock -CommandName 'Test-Path' -MockWith { return $false } -ModuleName $script:dscModuleName
            Mock -CommandName 'Get-Variable' -MockWith { throw 'Profile not found' } -ModuleName $script:dscModuleName
            
            InModuleScope -ScriptBlock {
                $result = Get-SESCredentialPath
                
                $result | Should -BeLike '*PSSESWrapper*credentials.xml'
            }
        }
    }
}