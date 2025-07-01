# Changelog for PSSymantecSES

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Phase 1.5 test isolation improvements achieving 54% reduction in test failures (69→32)
- Complete Submit-SESRequest test suite stabilization with 100% pass rate (18/18 tests)
- Enhanced Pester 5.x syntax compatibility for error handling tests
- Improved global state management in test infrastructure

### Fixed

- Fixed Submit-SESRequest test isolation by implementing proper WebException mocking with StatusCode properties
- Fixed Connect-SESService context-specific mock overrides for authentication failure scenarios
- Fixed Invoke-SESWebRequest Pester syntax compatibility with ExpectedMessage parameter format
- Fixed Export-SESCredential parameter validation in unit tests - Corrected test parameter usage to match actual function signature (ClientId, ClientSecret, Region parameters instead of Credentials hashtable)
- Fixed Export-SESCredential error handling test mock configuration - Moved mock setup outside InModuleScope for proper error simulation
- Fixed Get-SESCredentialPath cross-platform test isolation - Resolved test interference when run as part of full test suite
- Improved Connect-SESService connection state management test reliability - Enhanced test setup to properly simulate existing connection scenarios

### Changed

- Enhanced test framework reliability with improved mock implementation patterns
- Updated test infrastructure to support test-driven development for Phase 2 API wrapper development
- Improved cross-platform test compatibility and error handling

