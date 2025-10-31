@{
    # PSScriptAnalyzer Settings for HMG RBCMS Framework
    # Author: Joshua Dore
    # Date: October 2025
    # Compatible with PowerShell 5.1 and 7.x

    # Show all severities in Problems pane
    Severity = @('Error', 'Warning', 'Information')

    # Start from defaults, then exclude what conflicts with our design
    IncludeDefaultRules = $true

    # Framework-specific exclusions
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',                       # UI: allowed for our console UX
        'PSAvoidGlobalVars',                           # Global state used intentionally
        'PSUseShouldProcessForStateChangingFunctions', # Not all state changes expose -WhatIf
        'PSAvoidUsingPositionalParameters'             # OK in internal helpers
    )

    # Extra rules we want even if not in default set
    IncludeRules = @(
        'PSUseOutputTypeCorrectly',
        'PSMissingModuleManifestField',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSAlignAssignmentStatement',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUsePSCredentialType'
    )

    # Tuned rule configuration
    Rules = @{

        # Style / layout ------------------------------------------------------
        PSPlaceOpenBrace = @{
            Enable           = $true
            OnSameLine       = $true
            NewLineAfter     = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }

        PSUseConsistentIndentation = @{
            Enable                = $true
            IndentationSize       = 2
            PipelineIndentation   = 'IncreaseIndentationForFirstPipeline'
            Kind                  = 'space'
        }

        PSUseConsistentWhitespace = @{
            Enable                         = $true
            CheckInnerBrace                = $true
            CheckOpenBrace                 = $true
            CheckOpenParen                 = $true
            CheckOperator                  = $true
            CheckPipe                      = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator                 = $true
            CheckParameter                 = $false
        }

        PSAlignAssignmentStatement = @{
            Enable        = $true
            CheckHashtable = $true
        }

        PSUseCorrectCasing = @{
            Enable = $true
        }

        # Naming / API surface -----------------------------------------------
        PSUseApprovedVerbs = @{
            Enable = $true
        }

        # Detect likely cmdlet misuse (noisy sometimes; keep enabled by default)
        PSUseCmdletCorrectly = @{
            Enable = $true
        }

        # Aliases & parameters
        PSAvoidUsingCmdletAliases = @{
            Enable = $true
        }

        PSAvoidDefaultValueForMandatoryParameter = @{
            Enable = $true
        }

        PSReservedCmdletChar = @{
            Enable = $true
        }

        PSReservedParams = @{
            Enable = $true
        }

        # Security ------------------------------------------------------------
        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
        }

        PSAvoidUsingInvokeExpression = @{
            Enable = $true
        }

        PSUsePSCredentialType = @{
            Enable = $true
        }

        PSAvoidAssignmentToAutomaticVariable = @{
            Enable = $true
        }

        # Documentation -------------------------------------------------------
        PSProvideCommentHelp = @{
            Enable                 = $true
            ExportedOnly           = $true
            BlockComment           = $true
            VSCodeSnippetCorrection = $true
            Placement              = 'before'
        }

        # Reliability / correctness ------------------------------------------
        PSAvoidUsingEmptyCatchBlock = @{
            Enable = $true
        }

        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }
    }
}
