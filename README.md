# Personal PowerShell Profile

This is my personal developer focused PowerShell profile.

It has only been tested with PowerShell 7.4.1 on Windows 11.  
Some features and customizations will not work with older versions of PowerShell.

## Font

Many features depends on using a [Nerd Font] in your terminal.
Install any one from their page, and configure your terminal to use that font.

I recommend _CaskaydiaCove Nerd Font_, which is based on the excellent [CascadiaCode] programmer font from Microsoft.

## Features Overview

- [oh-my-posh] is used to apply a custom theme to the prompt itself.  
  ![ohmyposh-theme]

- [posh-git] is used primarily for providing tab completion for most git commands.

- [Terminal-Icons] will enrich file and folder views in the terminal with icons.  
  ![terminal-icons-theme]

- [CompletionPredictor] will enrich the prompt with completion options for almost anything that can be auto-completed in PowerShell. Use of this module mostly makes sense when using `ListView` as the prediction view in [PSReadLine].  
  ![completion-predictor]

- Multiple directories can be scanned for executables or scripts, and be automatically assigned aliases.  
  In my case, I have a cloud synchronized folder, where I put various small command line tools and scripts. These will always be available as aliases without maintenance.

- Provides some helper functions related to working with Git repositories. Specifically, the function `Set-RepositoryLocation` (aliased to `r`), can set the current location to a repository from anywhere.  
  What makes the function special, is that the repository has an automatic argument completer attached, which will list all repositories recursively, ordered by changed time (most recent first).  
  ![r-command]  
  E.g.: Typing `r` and then pressing `ctrl+space` will show all repositories, regardless of current location. Selecting something in the completion list, will show the full path in the tool-tip (cyan text at the bottom).

- PowerShell and the Console type is forced to use UTF-8 encoding.  
  UTF-8 is already the default for PowerShell Core cmdlets. To fix native commands, `InputEncoding` and `OutputEncoding` on the `Console` type is also set to use UTF-8, which is not default.  
  Have you ever had trouble passing arguments as strings from PowerShell to native commands? Well this is probably why.

- Registers native argument completer for the dotnet CLI, if it is detected.

- Includes a `Update-Profile` function, which can check for new versions of the used modules, and update them if available.
  - **Please let me know, if there is a better way to check for new versions of oh-my-posh.**  
    It caches the latest update check for a week. Any check for new versions are silently ignored within this time. My hacky workaround is to clear the oh-my-posh cache and then trigger an update check. This will cause the update instructions to be printed in the terminal. I can then capture and check if this notice was printed or not.

[ohmyposh-theme]:.attachments/omp-theme.png
[terminal-icons-theme]:.attachments/terminal-icons-theme.png
[r-command]:.attachments/r-command.png
[completion-predictor]:.attachments/completion-predictor.png

[Nerd Font]:<https://www.nerdfonts.com/>
[CascadiaCode]:<https://github.com/microsoft/cascadia-code>
[oh-my-posh]:<https://ohmyposh.dev/>
[posh-git]:<https://dahlbyk.github.io/posh-git/>
[Terminal-Icons]:<https://github.com/devblackops/Terminal-Icons>
[CompletionPredictor]:<https://github.com/PowerShell/CompletionPredictor>
[PSReadLine]:<https://github.com/PowerShell/PSReadLine>
