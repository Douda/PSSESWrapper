# Changelog for PSSymantecSES

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Fixed Export-SESCredential parameter validation in unit tests - Corrected test parameter usage to match actual function signature (ClientId, ClientSecret, Region parameters instead of Credentials hashtable)
- Fixed Export-SESCredential error handling test mock configuration - Moved mock setup outside InModuleScope for proper error simulation
- Fixed Get-SESCredentialPath cross-platform test isolation - Resolved test interference when run as part of full test suite
- Improved Connect-SESService connection state management test reliability - Enhanced test setup to properly simulate existing connection scenarios

