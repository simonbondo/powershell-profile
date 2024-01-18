# Get nerd font from here: https://www.nerdfonts.com/font-downloads
# Configure Windows Terminal to use that font.
# "CaskaydiaCove Nerd Font" is recommended.

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
  #>
  param(
    $Path = (Get-Location)
  )
  $fullPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
  if (!$fullPath) { return $false }

  # Check for a ".git" child folder, which is MUCH faster that invoking a git command.
  if (Test-Path -LiteralPath "$fullPath\.git" -PathType Container) { return $true }

  return $false

  # This is the slow way to do it, but it's more reliable.
  # "Test-Path" uses ~0.5ms, while "git rev-parse" uses 35+ms.
  <#
    # Backup the last exit code, because git will override it
    $ec = $LASTEXITCODE
    # "rev-parse" will set exit code to 0 if the path is a git repository (including children); otherwise 128
    & git -C $fullPath rev-parse --is-inside-work-tree 2>nul | Out-Null
    $isGitRepo = $LASTEXITCODE -eq 0
    # Restore the last exit code
    $LASTEXITCODE = $ec

    return $isGitRepo
  #>
}

function Get-GitRepositories {
  param(
    $Path = (Get-Location),
    $RecurseLevel = 0
  )
  $repos = @()
  foreach ($childPath in (Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue)) {
    if (Test-GitRepository -Path $childPath) {
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

# Configure the behavior of PSReadLine, which is responsible for almost all of command line editing.
& {
  # See: https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption?view=powershell-7.4
  # Use "Get-PSReadLineOption" to see current settings.
  $psReadLineOptions = @{
    # Disable beeps (e.g. when pressing backspace on empty line).
    BellStyle            = 'None'

    # Sets some key bindings, controlling how to navigate and edit the command line.
    EditMode             = 'Windows'

    # Shown at the start of new lines in multi-line input.
    ContinuationPrompt   = '» '

    # Show command auto-completion in a list, rather than inline.
    PredictionViewStyle  = 'ListView'

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
  Set-PSReadLineOption @psReadLineOptions
}

# Load and configure oh-my-posh, for fancy prompt. Requires a Nerd Font.
if (Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue) {
  & oh-my-posh --init --shell pwsh --config $PSScriptRoot\simonbondo.omp.json | Invoke-Expression
}
elseif (!$SkipMissingModuleWarning) {
  Write-Warning "oh-my-posh missing.`n  See https://ohmyposh.dev/docs/installation/windows to install or set `$SkipMissingModuleWarning = `$true"
}

# Load and configure posh-git, for git status and tab completion.
Import-Module (Join-Path $PSScriptRoot '..\..\GitHome\posh-git.git\src\posh-git.psd1')
# All this config might not be necessary when using oh-my-posh.
$GitPromptSettings.DefaultPromptPrefix.Text = "`n" + $GitPromptSettings.DefaultPromptPrefix.Text
$GitPromptSettings.DefaultPromptWriteStatusFirst = $true
$GitPromptSettings.PathStatusSeparator.Text = '`n'
$GitPromptSettings.BranchBehindAndAheadDisplay = 'Compact'
$GitPromptSettings.DefaultPromptBeforeSuffix = '`n'
$GitPromptSettings.ShowStatusWhenZero = $false
$GitPromptSettings.DefaultPromptSuffix.Text = 'λ ' # [char]0x3bb
$GitPromptSettings.SetEnvColumns = $true # Adds environment variables with size of terminal.
# POSH_GIT_ENABLED makes oh-my-posh use posh-git for git status, to avoid doing it twice.
$env:POSH_GIT_ENABLED = $true

# Terminal-Icons module adds icons to the prompt. Requires a Nerd Font.
& {
  if ($moduleRef = (Get-Module -ListAvailable -Name Terminal-Icons | Sort-Object -Property Version -Descending | Select-Object -First 1)) {
    Import-Module $moduleRef
  }
  elseif (!$SkipMissingModuleWarning) {
    Write-Warning "Terminal-Icons module missing.`n  Install with 'Install-Module Terminal-Icons' or set `$SkipMissingModuleWarning = `$true"
  }
}

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
& {
  if ($moduleRef = (Get-Module -ListAvailable -Name CompletionPredictor | Sort-Object -Property Version -Descending | Select-Object -First 1)) {
    Import-Module $moduleRef
  }
  elseif (!$SkipMissingModuleWarning) {
    Write-Warning "CompletionPredictor module missing.`n  Install with 'Install-Module CompletionPredictor' or set `$SkipMissingModuleWarning = `$true"
  }
}