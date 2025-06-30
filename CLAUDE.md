# Module Name: PSSESWrapper

## Description
Develop a PowerShell module named PSSESWrapper that serves as an API wrapper around the Symantec Endpoint Security (SES) API. The module should support Windows PowerShell 5.1 and PowerShell 7.x on both Windows and Linux platforms. The module will use Git for version control, GitVersion for versioning, and GitHub Actions for CI/CD.

## Project progression tracking
- prior to any changes update the `CLAUD-IN-PROGRESS.md` file with the planned changes, and add checkboxes

## Changelog Management
- **MANDATORY**: Update `CHANGELOG.md` for every commit with meaningful information
- Follow the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format strictly
- **Structure Requirements**:
  - Maintain an `## [Unreleased]` section at the top for ongoing changes
  - Create versioned sections with format: `## [X.Y.Z] - YYYY-MM-DD`
  - List versions in reverse chronological order (newest first)
- **Change Categories** (use relevant sections for every commit):
  - **Added** for new features
  - **Changed** for changes in existing functionality  
  - **Deprecated** for soon-to-be removed features
  - **Removed** for now removed features
  - **Fixed** for any bug fixes
  - **Security** in case of vulnerabilities
- **Content Guidelines**:
  - Write for humans, not machines - avoid raw git commit messages
  - Each entry should be descriptive and explain the impact/value of the change
  - Use clear, concise language that users and contributors can understand
  - Highlight breaking changes and deprecations prominently
- **Formatting**:
  - Use ISO date format (YYYY-MM-DD) for release dates
  - Make versions linkable when possible
  - Group similar changes under appropriate category headers

## API documentation
here is the list of all the API endpoints we have access to :
#### authentication
- https://apidocs.securitycloud.symantec.com/#/doc?id=ses_auth
#### devices information
- https://apidocs.securitycloud.symantec.com/#/doc?id=ses_devicesinfo
- https://apidocs.securitycloud.symantec.com/#/doc?id=ses_devicecommands
#### device groups information
- https://apidocs.securitycloud.symantec.com/#/doc?id=ses_devicegroupsinfo
#### policies information
- https://apidocs.securitycloud.symantec.com/#/doc?id=ses_policies
#### threat intel
- https://apidocs.securitycloud.symantec.com/#/doc?id=related_api
- https://apidocs.securitycloud.symantec.com/#/doc?id=insight_api
- https://apidocs.securitycloud.symantec.com/#/doc?id=process_chain_api
- https://apidocs.securitycloud.symantec.com/#/doc?id=protection

## Core Development Rules

### Code Quality
  - Functions must be focused and small
  - Follow existing patterns exactly
  - Include comprehensive documentation and comments
  - Write tests for every functions
  - **All functions must support ShouldProcess** where applicable (functions that make changes)
  - **Every command must have complete Get-Help documentation for all parameters** including:
    - Synopsis, Description, Parameter descriptions, Examples, Notes, Links
    - All parameters must have HelpMessage attribute for detailed explanations
  - **Use built-in PowerShell commands when appropriate** - Do not reinvent the wheel, leverage existing cmdlets like `Invoke-RestMethod`, `ConvertTo-Json`, `ConvertFrom-Json`, `Export-CliXml`, `Import-CliXml`, etc.
  - **All information, configuration, and parameters must be in English** - Documentation, error messages, parameter names, help text, and user-facing content
  - **PowerShell Code Style Standards**:
    - Use OTBS (One True Brace Style) formatting preset
    - Align property-value pairs for readability
    - Use correct casing for PowerShell cmdlets and keywords
    - Auto-correct aliases to full cmdlet names
    - New line after opening brrace `{`
    - Increase indentation for first pipeline element
    - No whitespace between parameters
    - Add whitespace around pipe operators `|`
    - Trim unnecessary whitespace around pipes
    - Enable PowerShell Script Analyzer compliance
  - All public functions should follow the template pattern from: https://raw.githubusercontent.com/Douda/PSSEPCloud/refs/heads/main/source/Public/Get-SEPCloudDevice.ps1
  - Use centralized API data repository pattern from: https://raw.githubusercontent.com/Douda/PSSEPCloud/refs/heads/main/source/Private/Get-SEPCloudAPIData.ps1

### API Design Patterns (Based on Rubrik SDK Analysis)
  - **Module Organization**: Use clear separation between Public, Private, ObjectDefinitions, and OptionsDefault folders
  - **Core Request Functions**: Implement centralized request handling similar to Submit-Request.ps1 and Invoke-RubrikWebRequest.ps1
  - **Connection Management**: Create global connection object to store authentication state and session information
  - **Parameter Sets**: Use multiple parameter sets for different query scenarios (ID, Name, Filter)
  - **Error Handling**: Implement comprehensive error parsing with verbose logging and DoNotThrow options
  - **Cross-Platform Support**: Handle different PowerShell versions (5.1, 6, 7) and platforms (Windows, Linux)
  - **Response Processing**: Convert API responses to PowerShell objects with proper type definitions
  - **Helper Functions**: Create utility functions for date conversion, JSON formatting, and data transformation

### Testing requierements
  - New features require tests
  - Bug fixes require regression tests
  - All commands must include pagination handling verification and Pester tests
  - Test pagination scenarios: single page, multiple pages, empty results
  - Validate correct handling of API response structures

### Function Examples & Expected Behavior

#### Authentication & Connection Functions
- `Connect-SESService -ClientID "client123" -SecretID "secret456" -Region "us"` - Connect to SES service with credentials
- `Disconnect-SESService` - Disconnect from current SES session
- `Test-SESConnection` - Verify current connection status and API availability
- `Clear-SESAuthentication` - Remove stored authentication credentials
- `Get-SESToken -ClientID "client123" -SecretID "secret456"` - Authenticate and retrieve access token
- `Get-SESToken` - Check for local credentials and provide tenant selection
- `Set-SESRegion -Region "eu"` - Set default region for API calls

#### Device Management Functions
- `Get-SESDevice` - Retrieve full list of endpoints with automatic pagination
- `Get-SESDevice -ComputerName "computer01"` - Query specific computer by name
- `Get-SESDevice -ComputerName "computer01", "computer02"` - Query multiple computers
- `Get-SESDevice -DeviceId "12345678-1234-1234-1234-123456789abc"` - Query by device ID
- `Get-SESDeviceDetails -DeviceId "12345"` - Get detailed information for specific device
- `Get-SESDeviceGroup` - List all device groups
- `Get-SESDeviceGroup -GroupName "Servers"` - Get specific device group information
- `Move-SESDevice -DeviceId "12345" -TargetGroup "NewGroup"` - Move device to different group
- `Start-SESFullScan -ComputerName "computer01"` - Initiate full antivirus scan
- `Start-SESQuickScan -DeviceId "12345"` - Initiate quick scan on device
- `Start-SESDefinitionUpdate -ComputerName "computer01"` - Update virus definitions
- `Invoke-SESDeviceCommand -DeviceId "12345" -Command "isolate"` - Execute command on device
- `Set-SESDeviceGroup -DeviceId "12345" -GroupName "Quarantine"` - Assign device to group
- `Remove-SESDevice -DeviceId "12345" -Confirm` - Remove device from management

#### Policy Management Functions
- `Get-SESPolicy` - List all security policies with pagination
- `Get-SESPolicy -PolicyName "Standard Workstation"` - Get specific policy by name
- `Get-SESPolicyDetails -PolicyId "policy-12345"` - Get detailed policy configuration
- `Get-SESPoliciesSummary` - Get summary of all policies and their assignments
- `Get-SESGroup` - List all groups in the tenant
- `Get-SESGroup -GroupName "Servers"` - Get specific group information
- `Get-SESGroupPolicies -GroupId "group-123"` - Get policies assigned to group
- `Set-SESPolicy -PolicyId "policy-123" -Settings @{enabled=$true}` - Modify policy settings
- `New-SESPolicy -Name "Custom Policy" -Template "Workstation"` - Create new policy
- `Remove-SESPolicy -PolicyId "policy-123" -Confirm` - Delete policy
- `Update-SESAllowListPolicyByFileHash -PolicyId "policy-123" -FileHash "sha256hash"` - Add file hash to allowlist
- `Update-SESAllowListPolicyByFileName -PolicyId "policy-123" -FileName "trusted.exe"` - Add filename to allowlist

#### Threat Intelligence & Protection Functions
- `Get-SESThreatIntelCveProtection -CveId "CVE-2021-1234"` - Get CVE protection information
- `Get-SESThreatIntelFileInsight -FileHash "sha256hash"` - Get file reputation and insights
- `Get-SESThreatIntelFileProcessChain -FileHash "sha256hash"` - Get process execution chain
- `Get-SESThreatIntelFileProtection -FileHash "sha256hash"` - Get file protection status
- `Get-SESThreatIntelFileRelated -FileHash "sha256hash"` - Get related files and threats
- `Get-SESThreatIntelNetworkInsight -IpAddress "192.168.1.100"` - Get network threat intelligence
- `Get-SESThreatIntelNetworkProtection -Domain "malicious.com"` - Get domain protection status

#### Incident & Event Management Functions
- `Get-SESIncidents` - List all security incidents with pagination
- `Get-SESIncidents -Severity "High"` - Filter incidents by severity
- `Get-SESIncidentDetails -IncidentId "incident-123"` - Get detailed incident information
- `Get-SESEvents` - Retrieve security events with pagination
- `Get-SESEvents -EventType "Malware" -StartDate (Get-Date).AddDays(-7)` - Filter events by type and date

#### File & Hash Management Functions
- `Block-SESFile -FileHash "sha256hash" -Reason "Malware detected"` - Block file globally
- `Get-SESFileHashDetails -FileHash "sha256hash"` - Get detailed file information

#### System & Configuration Functions
- `Get-SESComponentType` - List available component types
- `Get-SESEDRDumpsList -DeviceId "12345"` - Get EDR memory dumps for device
- `Get-SESTargetRules` - List all targeting rules
- `Get-SESFeatureList` - Get available features and their status

#### Additional Commands Functions
- `Export-SESReport -ReportType "DeviceInventory" -Format "CSV"` - Export various reports
- `New-SESIncidentResponse -IncidentId "incident-123" -Action "Quarantine"` - Create incident response
- `Update-SESDeviceConfiguration -DeviceId "12345" -Settings @{autoUpdate=$true}` - Update device config
- `Disable-SESThreat -ThreatId "threat-123"` - Disable threat detection
- `Enable-SESThreat -ThreatId "threat-123"` - Enable threat detection
- `Invoke-SESQuarantine -DeviceId "12345" -Duration 24` - Quarantine device
- `Remove-SESQuarantine -DeviceId "12345"` - Remove device from quarantine
- `Get-SESComplianceReport -ReportType "PolicyCompliance"` - Get compliance reports
- `Export-SESDeviceInventory -Format "JSON" -Path "C:\Reports"` - Export device inventory
- `Get-SESAuditLog -StartDate (Get-Date).AddDays(-30)` - Get audit log entries
- `Set-SESNotificationSettings -EmailEnabled $true -Recipients @("admin@company.com")` - Configure notifications
- `Get-SESHealthStatus` - Get overall system health status
- `Test-SESConnectivity -Endpoint "api"` - Test connectivity to specific endpoints
- `Backup-SESConfiguration -Path "C:\Backup"` - Backup current configuration
- `Restore-SESConfiguration -Path "C:\Backup\config.xml"` - Restore configuration

#### Utility Functions
- `Import-SESConfiguration -Path "C:\Config\ses-config.json"` - Import configuration from file
- `Export-SESConfiguration -Path "C:\Config\ses-config.json"` - Export current configuration
- `ConvertTo-SESQuery -Filter @{status="active"; type="workstation"}` - Convert hashtable to API query
- `Format-SESResponse -InputObject $apiResponse -Format "Table"` - Format API responses
- `ConvertFrom-SESDate -SESTimestamp "2024-01-15T10:30:00Z"` - Convert SES timestamp to DateTime
- `ConvertTo-SESDate -DateTime (Get-Date)` - Convert DateTime to SES timestamp format

## Pull Requests

- Create a detailed message of what changed. Focus on the high level description of
  the problem it tries to solve, and how it is solved. Don't go into the specifics of the
  code unless it adds clarity.

- NEVER ever mention a `co-authored-by` or similar aspects. In particular, never
  mention the tool used to create the commit message or PR.


## Development Commands

### Build Commands
```powershell
# Build the module
./build.ps1

# Install dependencies
./build.ps1 -ResolveDependency

# Run tests
./build.ps1 -Tasks test

# Run test for a specific  function
./build.ps1 -Tasks test -PesterPath ./tests/Unit/Private/Get-Something.tests.ps1 -CodeCoverageThreshold 0

# Build and package
./build.ps1 -Tasks build

# Publish to gallery
./build.ps1 -Tasks publish
```

## Requirements

### Module Framework
Use the Sampler PowerShell module framework to scaffold the module structure. Ensure the module follows best practices for PowerShell module development.

### Version Control
Initialize a Git repository for the module. Use GitVersion for versioning the module.

### CI/CD Pipeline
Set up GitHub Actions for continuous integration and continuous deployment. Include tasks for building, testing, and deploying the module.

### API Wrapper
Design the module to interact with the Symantec Endpoint Security (SES) API. Follow the design pattern similar to the provided PowerShell function (Get-RubrikAPIData.ps1) for API interactions.

### Authentication
Implement an authentication system that supports multiple sessions. Securely store credentials in the user's profile using PowerShell's CliXml encryption (Export-CliXml/Import-CliXml). Support authentication against different tenant regions (Americas, Europe, India) based on the URLs containing .us., .eu., or .in.

### Platform Support
Ensure compatibility with Windows PowerShell 5.1 and PowerShell 7.x on both Windows and Linux.

### Testing
Write Pester tests for each function to ensure code quality and functionality. Ensure high code coverage with unit tests.
Live testing is using credentials with read-only access so any modification won't work. Also the environment used for testing contains no devices, only a few policies.

### Development Environment
Develop the module on PowerShell on Linux (Ubuntu).

**Required Dependencies for Ubuntu WSL Development:**
- PowerShell 7.5.1 or later
- Git 2.43.0 or later  
- .NET SDK 8.0 or later (required for GitVersion)
- GitVersion global tool for module versioning

**Installation Commands:**
```bash
# Install .NET SDK
sudo apt update && sudo apt install -y dotnet-sdk-8.0

# Install GitVersion global tool (version 5.x to avoid v6 breaking changes)
dotnet tool install --global GitVersion.Tool --version 5.12.0

# Add GitVersion to PATH (add to ~/.bash_profile for persistence)
export PATH="$PATH:/home/douda/.dotnet/tools"
```

## Authentication Credentials
Authentication credentials are stored in `CLAUDE-CREDENTIALS.md` (excluded from version control for security).

## Development Plan & Progress Tracking

### Phase 0: Environment Validation & CI/CD Setup (Ubuntu WSL)
- [ ] ✅ Verify PowerShell 7.5.1 or later is installed and working
- [ ] ✅ Confirm Git 2.43.0 or later is available for version control
- [ ] Verify GitVersion configuration and functionality for proper module versioning
- [ ] Initialize/switch to "dev" branch for development
- [ ] **Initial Commit: Create project baseline snapshot (excluding credentials)**
- [ ] Configure GitHub Actions CI/CD pipeline for multi-platform testing:
  - [ ] Ubuntu (PowerShell 7.x) - for development validation
  - [ ] Windows (PowerShell 5.1) - for compatibility validation
  - [ ] Windows (PowerShell 7.x) - for cross-version validation
- [ ] Test build.ps1 script execution in WSL environment
- [ ] Validate Pester testing framework availability
- [ ] Test live API connection using provided credentials (Linux)
- [ ] Update CLAUDE.md with WSL-specific development notes
- [ ] Create CLAUDE-IN-PROGRESS.md tracking file
- [ ] **Commit: "Initialize development environment and CI/CD pipeline"**

### Phase 1: Foundation Setup + Cross-Platform Testing
- [ ] Implement core request handling infrastructure:
  - [ ] Create Submit-SESRequest function (similar to Rubrik's Submit-Request.ps1)
  - [ ] Create Invoke-SESWebRequest function for cross-platform HTTP calls
  - [ ] Implement comprehensive error handling and response processing
- [ ] Implement core authentication module (Connect-SESService, Disconnect-SESService, Test-SESConnection)
  - [ ] Create global connection object for session management
  - [ ] Support multiple authentication methods (credentials, tokens)
- [ ] Test authentication against live SES API (Linux validation)
- [ ] Trigger CI/CD pipeline to validate Windows PowerShell 5.1 compatibility
- [ ] **Commit: "Add core authentication functions with cross-platform validation"**
- [ ] Set up secure credential storage system with regional support
- [ ] CI/CD validation on Windows PowerShell 5.1
- [ ] **Commit: "Implement secure credential storage with Windows PS 5.1 support"**
- [ ] Create base API communication framework with helper functions:
  - [ ] Date/time conversion utilities
  - [ ] JSON formatting functions
  - [ ] Response transformation helpers
- [ ] Full CI/CD pipeline validation (Linux PS7, Windows PS5.1, Windows PS7)
- [ ] **Commit: "Add base API communication framework with full cross-platform support"**

### Phase 2: Core API Wrappers + Multi-Platform Validation
- [ ] Create centralized API data repository function (Get-SESAPIData) following template pattern
- [ ] Develop device management functions with Rubrik-inspired patterns:
  - [ ] Implement multiple parameter sets (ID, Name, Filter)
  - [ ] Add comprehensive parameter validation and aliases
  - [ ] Linux testing with live API
  - [ ] Verify pagination handling for large datasets
  - [ ] CI/CD pipeline validation on Windows PowerShell 5.1
  - [ ] **Commit: "Add device management functions with Windows PS 5.1 compatibility"**
- [ ] Implement policy management functions:
  - [ ] Use Begin/Process/End blocks for pipeline support
  - [ ] Implement verbose logging and error handling
  - [ ] Linux live API validation
  - [ ] Test pagination scenarios (single page, multiple pages, empty results)
  - [ ] CI/CD Windows PowerShell 5.1 validation
  - [ ] **Commit: "Add policy management functions with cross-platform support"**
- [ ] Create threat intelligence functions:
  - [ ] Apply consistent parameter patterns across all functions
  - [ ] Implement proper object type definitions
  - [ ] Linux live API testing
  - [ ] Validate pagination handling with live data
  - [ ] CI/CD multi-platform validation
  - [ ] **Commit: "Add threat intelligence functions with full platform support"**

### Phase 3: Testing & Quality + Comprehensive Platform Testing
- [ ] Write comprehensive Pester tests for all functions
- [ ] Create specific Pester tests for pagination handling:
  - [ ] Test single page responses
  - [ ] Test multi-page responses with proper data aggregation
  - [ ] Test empty result sets
  - [ ] Test pagination edge cases (last page, offset boundaries)
- [ ] Create CI/CD jobs that run tests on all platforms:
  - [ ] Live API integration tests (Linux)
  - [ ] Pagination tests with live API data
  - [ ] Compatibility tests (Windows PowerShell 5.1)
  - [ ] Feature tests (Windows PowerShell 7.x)
- [ ] **Commit: "Add comprehensive test suite with multi-platform CI/CD validation"**
- [ ] Implement error handling and retry logic
- [ ] Validate error handling across all platforms via CI/CD
- [ ] **Commit: "Enhance error handling with cross-platform compatibility"**

### Phase 4: Finalization + Production Readiness
- [ ] Final end-to-end testing:
  - [ ] Linux development environment
  - [ ] CI/CD pipeline validation on Windows PowerShell 5.1 & 7.x
- [ ] Update module manifest and documentation
- [ ] **Commit: "Complete PSSESWrapper v1.0 with full cross-platform support"**

### Development Flow Notes
- Start with initial commit to "dev" branch containing complete project baseline (credentials excluded via .gitignore)
- Develop on Linux/WSL with PowerShell 7.5.1
- Validate locally with live API
- Commit to "dev" branch after each validated step
- CI/CD automatically tests Windows PowerShell 5.1 & 7.x compatibility
- Only proceed to next phase after CI/CD passes

### PowerShell Approved Verb Commands (Based on PSSEPCloud Analysis)

#### Authentication & Connection
- [ ] `Connect-SESService`
- [ ] `Disconnect-SESService`
- [ ] `Test-SESConnection`
- [ ] `Clear-SESAuthentication`
- [ ] `Get-SESToken`
- [ ] `Set-SESRegion`

#### Device Management
- [ ] `Get-SESDevice`
- [ ] `Get-SESDeviceDetails`
- [ ] `Get-SESDeviceGroup`
- [ ] `Move-SESDevice`
- [ ] `Start-SESFullScan`
- [ ] `Start-SESQuickScan`
- [ ] `Start-SESDefinitionUpdate`
- [ ] `Invoke-SESDeviceCommand`
- [ ] `Set-SESDeviceGroup`
- [ ] `Remove-SESDevice`

#### Policy Management
- [ ] `Get-SESPolicy`
- [ ] `Get-SESPolicyDetails`
- [ ] `Get-SESPoliciesSummary`
- [ ] `Get-SESGroup`
- [ ] `Get-SESGroupPolicies`
- [ ] `Set-SESPolicy`
- [ ] `New-SESPolicy`
- [ ] `Remove-SESPolicy`
- [ ] `Update-SESAllowListPolicyByFileHash`
- [ ] `Update-SESAllowListPolicyByFileName`

#### Threat Intelligence & Protection
- [ ] `Get-SESThreatIntelCveProtection`
- [ ] `Get-SESThreatIntelFileInsight`
- [ ] `Get-SESThreatIntelFileProcessChain`
- [ ] `Get-SESThreatIntelFileProtection`
- [ ] `Get-SESThreatIntelFileRelated`
- [ ] `Get-SESThreatIntelNetworkInsight`
- [ ] `Get-SESThreatIntelNetworkProtection`

#### Incident & Event Management
- [ ] `Get-SESIncidents`
- [ ] `Get-SESIncidentDetails`
- [ ] `Get-SESEvents`

#### File & Hash Management
- [ ] `Block-SESFile`
- [ ] `Get-SESFileHashDetails`

#### System & Configuration
- [ ] `Get-SESComponentType`
- [ ] `Get-SESEDRDumpsList`
- [ ] `Get-SESTargetRules`
- [ ] `Get-SESFeatureList`

#### Additional Commands (Gaps Identified)
- [ ] `Export-SESReport`
- [ ] `New-SESIncidentResponse`
- [ ] `Update-SESDeviceConfiguration`
- [ ] `Disable-SESThreat`
- [ ] `Enable-SESThreat`
- [ ] `Invoke-SESQuarantine`
- [ ] `Remove-SESQuarantine`
- [ ] `Get-SESComplianceReport`
- [ ] `Export-SESDeviceInventory`
- [ ] `Get-SESAuditLog`
- [ ] `Set-SESNotificationSettings`
- [ ] `Get-SESHealthStatus`
- [ ] `Test-SESConnectivity`
- [ ] `Backup-SESConfiguration`
- [ ] `Restore-SESConfiguration`

#### Utility Functions
- [ ] `Import-SESConfiguration`
- [ ] `Export-SESConfiguration`
- [ ] `ConvertTo-SESQuery`
- [ ] `Format-SESResponse`
- [ ] `ConvertFrom-SESDate`
- [ ] `ConvertTo-SESDate`
