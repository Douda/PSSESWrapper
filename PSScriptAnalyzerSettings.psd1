@{
    # Script Analyzer Settings for PSSymantecSES Module

    # Rules to exclude
    ExcludeRules = @(
        # Module uses global variables for session state management (standard practice for PowerShell modules)
        'PSAvoidGlobalVars',
        # Parameter set binding parameters may appear unused but are required for PowerShell parameter set functionality
        'PSReviewUnusedParameter'
    )

    # Rules to include (all other rules)
    IncludeRules = @('*')

    # Severity levels to include
    Severity = @('Warning', 'Error', 'Information')

    # Custom rule path (if needed for future expansion)
    # CustomRulePath = ''
}