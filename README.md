# PSSymantecSES

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PSSymantecSES?logo=powershell&logoColor=white)](https://www.powershellgallery.com/packages/PSSymantecSES)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/PSSymantecSES?logo=powershell&logoColor=white)](https://www.powershellgallery.com/packages/PSSymantecSES)
[![License](https://img.shields.io/github/license/Douda/PSSymantecSES)](https://github.com/Douda/PSSymantecSES/blob/main/LICENSE)

A PowerShell module that provides an API wrapper for Symantec Endpoint Security (SES) management. This module enables administrators to interact with SES through PowerShell, supporting device management, policy administration, and threat intelligence operations across multiple tenant regions.

## Overview

PSSymantecSES offers comprehensive functionality for managing Symantec Endpoint Security environments:

- **Device Management**: Query, scan, and manage endpoint devices
- **Policy Administration**: Retrieve and manage security policies
- **Threat Intelligence**: Access threat data, file insights, and protection information
- **Multi-Region Support**: Connect to Americas, Europe, and India tenant regions
- **Cross-Platform**: Compatible with Windows PowerShell 5.1 and PowerShell 7.x on Windows and Linux
- **Secure Authentication**: Uses encrypted credential storage with regional support

## Installation

### Install from PowerShell Gallery (Recommended)

```powershell
# Install for current user
Install-Module -Name PSSymantecSES -Scope CurrentUser

# Install system-wide (requires administrator privileges)
Install-Module -Name PSSymantecSES -Scope AllUsers
```

### Build from Source

If you prefer to build the module from source or contribute to development:

```powershell
# Clone the repository
git clone https://github.com/Douda/PSSymantecSES.git
cd PSSymantecSES

# Install build dependencies
./build.ps1 -ResolveDependency

# Build the module
./build.ps1

# Run tests
./build.ps1 -Tasks test
```

## Quick Start

### Authentication

Connect to your SES tenant using client credentials:

```powershell
# Connect using client ID and secret
Get-SESToken -ClientID "your-client-id" -SecretID "your-secret-key"

# Or check for stored credentials and select tenant
Get-SESToken
```

### Basic Usage Examples

#### Device Management

```powershell
# Get all devices (with automatic pagination)
Get-SESDevice

# Get specific device by computer name
Get-SESDevice -ComputerName "DESKTOP-ABC123"

# Get multiple devices
Get-SESDevice -ComputerName "DESKTOP-ABC123", "LAPTOP-DEF456"

# Get device by ID
Get-SESDevice -DeviceId "12345678-1234-1234-1234-123456789abc"

# Start a full scan on a device
Start-SESFullScan -ComputerName "DESKTOP-ABC123"

# Update definitions on a device
Start-SESDefinitionUpdate -ComputerName "DESKTOP-ABC123"
```

#### Policy Management

```powershell
# Get all policies
Get-SESPolicy

# Get specific policy details
Get-SESPolicyDetails -PolicyId "policy-12345"

# Get policies summary
Get-SESPoliciesSummary

# Get device groups
Get-SESDeviceGroup
```

#### Threat Intelligence

```powershell
# Get file insights
Get-SESThreatIntelFileInsight -FileHash "sha256-hash-here"

# Get file protection information
Get-SESThreatIntelFileProtection -FileHash "sha256-hash-here"

# Get CVE protection details
Get-SESThreatIntelCveProtection -CveId "CVE-2021-1234"

# Get network insights
Get-SESThreatIntelNetworkInsight -IpAddress "192.168.1.100"
```

## Available Commands

To see all available commands in the module:

```powershell
Get-Command -Module PSSymantecSES
```

For detailed help on any command:

```powershell
Get-Help Get-SESDevice -Full
Get-Help Connect-SESService -Examples
```

### Command Categories

- **Authentication**: `Connect-SESService`, `Disconnect-SESService`, `Get-SESToken`, `Test-SESConnection`
- **Device Management**: `Get-SESDevice`, `Get-SESDeviceDetails`, `Start-SESFullScan`, `Start-SESQuickScan`
- **Policy Management**: `Get-SESPolicy`, `Get-SESPolicyDetails`, `Get-SESGroup`
- **Threat Intelligence**: `Get-SESThreatIntelFileInsight`, `Get-SESThreatIntelFileProtection`, `Get-SESThreatIntelCveProtection`
- **System Operations**: `Get-SESIncidents`, `Get-SESEvents`, `Block-SESFile`

## Authentication & Configuration

The module supports secure credential storage using PowerShell's CliXml encryption. Credentials are stored per-user and support multiple tenant regions:

- **Americas**: Tenants with `.us.` in the URL
- **Europe**: Tenants with `.eu.` in the URL  
- **India**: Tenants with `.in.` in the URL

```powershell
# First-time setup - credentials will be securely stored
Get-SESToken -ClientID "your-client-id" -SecretID "your-secret-key"

# Subsequent connections can use stored credentials
Get-SESToken

# Test your connection
Test-SESConnection

# Clear stored authentication
Clear-SESAuthentication
```

## Requirements

- **Windows PowerShell 5.1** or **PowerShell 7.x** (Windows/Linux)
- **Internet connectivity** to reach SES API endpoints
- **Valid SES API credentials** (Client ID and Secret)

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.

## Support

- **Issues**: [GitHub Issues](https://github.com/Douda/PSSymantecSES/issues)
- **Documentation**: Use `Get-Help` for detailed command documentation
- **API Reference**: [Symantec Endpoint Security API Documentation](https://apidocs.securitycloud.symantec.com/)