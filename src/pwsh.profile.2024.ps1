<#
  .SYNOPSIS
    Script to configure the PowerShell environment.

  .PARAMETER StartupPath
    When script done, this path will be set as the current location, if it was default on startup.
#>
param(
  $StartupPath
)

#################################################
### Configure Env and global variables        ###
#################################################

# LC_ALL is used by Linux to override all locale settings. SSH (and related) should pass this value on to servers, if set.
# en_DK.UTF8 = English language with danish charset, collation, formats, etc. using UTF8 encoding.
if (!$Env:LC_ALL) { $Env:LC_ALL = 'en_DK.UTF8' }
# Disable telemetry by dotnet CLI.
$Env:DOTNET_CLI_TELEMETRY_OPTOUT = 1
# Set encoding for console input and output to UTF8, which is typically used by native tools. (UTF8 is defailt in PWSH)
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8


#################################################
### Declare global functions and aliases      ###
#################################################

function Import-ModuleSafe {
  <#
  .SYNOPSIS
    Imports a module, but only if it exists. Displays a warning if the minimum version is not satisfied.
    Returns $true if the module was imported; otherwise $false.

  .PARAMETER Name
    Name of the module to import.

  .PARAMETER MinimumVersion
    Expected minimum version of the module. Version is not checked if this parameter is not specified.
  #>
  param (
    [string]$Name,
    [version]$MinimumVersion = $null
  )
  # Find newest version of the module.
  $moduleRef = (Get-Module -ListAvailable -Name $Name | Sort-Object -Property Version -Descending | Select-Object -First 1)
  if ($moduleRef) {
    if ($MinimumVersion -and $moduleRef.Version -lt $MinimumVersion) {
      Write-Warning "$Name module version $($moduleRef.Version) is untested and may cause errors. Update to $MinimumVersion or newer.`n  Update-Module $Name"
    }
    Import-Module $moduleRef
    return $true
  }
  elseif (!$SkipMissingModuleWarning) {
    Write-Warning "$Name module could not be found. Install module or set `$SkipMissingModuleWarning = `$true.`n  Install-Module $Name"
  }
  return $false
}

function Set-AliasIfValid {
  <#
    .SYNOPSIS
      Creates or updates an alias for an executable; but only if it exists.
  #>
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Command
  )
  If ((Test-Path -PathType Leaf $Command)) {
    Set-Alias -Name $Name -Value $Command -Scope Global -Force
  }
}

function Set-ParentLocation {
  <#
    .SYNOPSIS
      Sets the current location to the parent of the current location.

    .NOTES
      This is a workaround for the fact that PowerShell doesn't support arguments to commands when defining an alias.
  #>
  Set-Location ..
}

function Test-GitRepository {
  <#
    .SYNOPSIS
      Tests if a given path is a git repository.

    .PARAMETER Path
      The path to test. Defaults to the current location.

    .PARAMETER Mode
      Set how the test is performed. Defaults to 'Reliable'.
      'Simple' is very fast, but will fail if not checking the root of the repository or it has a special .GIT_DIR configured.
      'SimpleRecursive' is like 'Simple', but will also check all parent directories.
      'Reliable' uses git commands for the check, which makes it reliable, but is about 10 times slower.
  #>
  param(
    $Path = (Get-Location),
    [ValidateSet('Simple', 'SimpleRecursive', 'Reliable')]$Mode = 'Reliable'
  )
  $fullPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
  if (!$fullPath) { return $false }

  if ($Mode -eq 'Reliable') {
    # Backup the last exit code, because git will override it
    $ec = $LASTEXITCODE
    # "rev-parse" will set exit code to 0 if the path is a git repository (including children); otherwise 128
    & git -C $fullPath rev-parse --is-inside-work-tree 2>nul | Out-Null
    $isGitRepo = $LASTEXITCODE -eq 0
    # Restore the last exit code
    $LASTEXITCODE = $ec
    return $isGitRepo
  }

  $simpleCheck = Test-Path -LiteralPath "$fullPath\.git" -PathType Container
  # Return the result of the simple check, if it's true or there are no more parent folders to check.
  if ($simpleCheck -or $Mode -eq 'Simple' -or ($parentPath = Split-Path -Path $fullPath -Parent) -eq '') {
    return $simpleCheck
  }

  # Recurse to the parent folder.
  return Test-GitRepository -Path $parentPath -Mode SimpleRecursive
}

function Get-GitRepositories {
  param(
    $Path = (Get-Location),
    $RecurseLevel = 0
  )
  $repos = @()
  foreach ($childPath in (Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)) {
    if (Test-GitRepository -Path $childPath -Mode Simple) {
      $repos += $childPath
    }
    elseif ($RecurseLevel -gt 0) {
      $repos += Get-GitRepositories -Path $childPath -RecurseLevel ($RecurseLevel - 1)
    }
  }
  return $repos
}

Set-AliasIfValid -Name 'npp' -Command "${Env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
Set-AliasIfValid -Name 'npp' -Command "$Env:ProgramFiles\Notepad++\notepad++.exe"
Set-AliasIfValid -Name '7z' -Command "$Env:ProgramFiles\7-Zip\7z.exe"

Set-Alias -Name '..' -Value Set-ParentLocation -Scope Global -Force


#################################################
### Configure look and feel                   ###
#################################################

# Load and configure oh-my-posh, for fancy prompt. Requires a Nerd Font.
if (Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue) {
  & oh-my-posh --init --shell pwsh --config $PSScriptRoot\simonbondo.omp.json | Invoke-Expression
}
elseif (!$SkipMissingModuleWarning) {
  Write-Warning "oh-my-posh could not be found. See https://ohmyposh.dev/ to install or set `$SkipMissingModuleWarning = `$true`n  iex ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))"
}

# Configure the behavior of PSReadLine, which is responsible for almost all of command line editing.
# PSReadLine is included in PowerShell 5.1 and newer, but doesn't seem to be updated when PowerShell is updated.
if (Import-ModuleSafe -Name PSReadLine -MinimumVersion 2.3.4) {
  # See: https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption?view=powershell-7.4
  # Use "Get-PSReadLineOption" to see current settings.
  $options = @{
    # Disable beeps (e.g. when pressing backspace on empty line).
    BellStyle            = 'None'

    # Sets some key bindings, controlling how to navigate and edit the command line.
    EditMode             = 'Windows'

    # Shown at the start of new lines in multi-line input.
    ContinuationPrompt   = '» '

    # Show command auto-completion in a list, rather than inline.
    PredictionViewStyle  = 'ListView'
    PredictionSource     = 'HistoryAndPlugin'

    # If the prompt spans more than one line, specify a value for this parameter. Default is 0
    # It doesn't really seem to do anything.
    ExtraPromptLineCount = 2

    # Set colors for the prompt.
    <#
    Colors = @{
      ContinuationPrompt = "`e[37m"             # The color of the continuation prompt.
      Emphasis = "`e[96m"                       # The emphasis color. For example, the matching text when searching history.
      Error = "`e[91m"                          # The error color. For example, in the prompt.
      Selection = "`e[30;47m"                   # The color to highlight the menu selection or selected text.
      Default = "`e[37m"                        # The default token color.
      Comment = "`e[32m"                        # The comment token color.
      Keyword = "`e[92m"                        # The keyword token color.
      String = "`e[36m"                         # The string token color.
      Operator = "`e[90m"                       # The operator token color.
      Variable = "`e[92m"                       # The variable token color.
      Command = "`e[93m"                        # The command token color.
      Parameter = "`e[90m"                      # The parameter token color.
      Type = "`e[37m"                           # The type token color.
      Number = "`e[97m"                         # The number token color.
      Member = "`e[37m"                         # The member name token color.
      InlinePrediction = "`e[97;2;3m"           # The color for the inline view of the predictive suggestion.
      ListPrediction = "`e[33m"                 # The color for the leading > character and prediction source name.
      ListPredictionSelected = "`e[48;5;238m"   # The color for the selected prediction in list view.
      ListPredictionTooltipColor = "`e[97;2;3m" # Undocumented.
    } #>
  }
  Set-PSReadLineOption @options
}

# Load and configure posh-git, for git status and tab completion.
if (Import-ModuleSafe -Name posh-git -MinimumVersion 1.1.0) {
  # All this config might not be necessary when using oh-my-posh.
  $GitPromptSettings.DefaultPromptPrefix.Text = "`n" + $GitPromptSettings.DefaultPromptPrefix.Text
  $GitPromptSettings.DefaultPromptWriteStatusFirst = $true
  $GitPromptSettings.PathStatusSeparator.Text = '`n'
  $GitPromptSettings.BranchBehindAndAheadDisplay = 'Compact'
  $GitPromptSettings.DefaultPromptBeforeSuffix = '`n'
  $GitPromptSettings.ShowStatusWhenZero = $false
  $GitPromptSettings.DefaultPromptSuffix.Text = 'λ ' # [char]0x3bb
  $GitPromptSettings.SetEnvColumns = $true # Adds environment variables with size of terminal.
  # POSH_GIT_ENABLED makes oh-my-posh use posh-git for git status (avoids fetching data twice?)
  $Env:POSH_GIT_ENABLED = $true
}

# Terminal-Icons module adds icons to the prompt. Requires a Nerd Font.
Import-ModuleSafe -Name Terminal-Icons -MinimumVersion 0.11.0 | Out-Null


#################################################
### Register argument and tab completers      ###
#################################################

# Register argument completer for dotnet CLI
if ((Get-Command -Name 'dotnet.exe' -CommandType Application -ErrorAction Ignore)) {
  Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition "$commandAst" | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
  }
}

# CompletionPredictor module provides IntelliSense and auto-completion for almost anything that can be tab-completed
Import-ModuleSafe -Name CompletionPredictor | Out-Null


#################################################
### Cleanup                                   ###
#################################################

Remove-Item Function:\Import-ModuleSafe -ErrorAction SilentlyContinue

# Change the startup location, if specified and current location is the default.
if ($StartupPath -and $PWD.Path -eq $Env:USERPROFILE) {
  Set-Location $StartupPath
}
