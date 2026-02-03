# Building Android Pentesting Toolkit Manager

This guide explains how to compile the PowerShell script into a standalone executable.

## Prerequisites

- PowerShell 5.1+
- ps2exe module

## Install ps2exe

```powershell
Install-Module ps2exe -Scope CurrentUser
```

## Basic Compilation

```powershell
Invoke-ps2exe -inputFile "AndroidToolsManager.ps1" -outputFile "AndroidToolsManager.exe"
```

## Full Build with Options

```powershell
Invoke-ps2exe `
    -inputFile "AndroidToolsManager.ps1" `
    -outputFile "AndroidToolsManager.exe" `
    -title "Android Pentesting Toolkit Manager" `
    -description "Automated installer for Android pentesting tools" `
    -company "Your Name" `
    -version "1.0.0.0" `
    -noConsole `
    -requireAdmin `
    -x64
```

## Build Options

| Option | Description |
|--------|-------------|
| `-noConsole` | Hide console window (GUI only) |
| `-requireAdmin` | Require admin elevation |
| `-x64` | Build 64-bit executable |
| `-iconFile` | Custom .ico file for the exe |

## Optional: Add Icon

1. Create or obtain an `.ico` file
2. Add `-iconFile "path\to\icon.ico"` to the build command

## Output

The compiled `.exe` will be a standalone executable that includes all dependencies. Users can run it without installing PowerShell modules.

## Notes

- The executable may trigger antivirus warnings (false positive)
- Test thoroughly before distribution
- Keep the original .ps1 for modifications
