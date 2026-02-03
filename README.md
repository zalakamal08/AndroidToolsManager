# Android Pentesting Toolkit Manager

A PowerShell-based GUI application for automating installation, updating, and management of Android pentesting tools on Windows.

## Features

- **Modern Dark Theme UI** - WPF-based interface with 5 tabs
- **Tool Management** - Install, update, uninstall Android tools
- **Auto Updates** - GitHub API integration for latest releases
- **PATH Management** - Automatic PATH configuration
- **Offline Mode** - Embedded manifest fallback

## Requirements

- Windows 7/8/10/11 (x64)
- PowerShell 5.1+
- Internet connection (for downloads)

## Quick Start

```powershell
# Run the script
powershell -ExecutionPolicy Bypass -File AndroidToolsManager.ps1
```

## Included Tools

| Tool | Description |
|------|-------------|
| scrcpy | Screen mirroring for Android devices |
| Platform Tools | adb, fastboot, and more |
| Apktool | APK reverse engineering |
| JADX | Dex to Java decompiler |
| Frida | Dynamic instrumentation toolkit |

## Directory Structure

```
%USERPROFILE%\androidtools\
├── tools\           # Installed tools
├── downloads\       # Temporary downloads
├── cache\           # Cached manifest
├── logs\            # Application logs
├── settings.json    # User settings
└── installed-tools.json
```

## Settings

- **Installation Directory** - Where tools are installed
- **PATH Scope** - User or System PATH
- **Update Checks** - On startup or manual
- **Logging** - Enable/disable application logs

## Custom Manifest

To use your own tool manifest, update the Manifest URL in Settings. See `MANIFEST_TEMPLATE.json` for format.

## Compiling to EXE

See [BUILD.md](BUILD.md) for instructions on compiling to a standalone executable.

## License

MIT License
