#Requires -Version 5.1
<#
.SYNOPSIS
    Android Pentesting Toolkit Manager v1.0
.DESCRIPTION
    GUI application for managing Android pentesting tools on Windows
#>

# ============================================================================
# SCRIPT-LEVEL VARIABLES
# ============================================================================
$script:AppVersion = "1.0.0"
$script:BaseDir = "$env:USERPROFILE\androidtools"
$script:ToolsDir = "$script:BaseDir\tools"
$script:DownloadDir = "$script:BaseDir\downloads"
$script:CacheDir = "$script:BaseDir\cache"
$script:LogDir = "$script:BaseDir\logs"
$script:Settings = @{}

$script:DefaultSettings = @{
    ManifestUrl           = "https://raw.githubusercontent.com/example/android-tools-manifest/main/tools-manifest.json"
    InstallDirectory      = "$env:USERPROFILE\androidtools\tools"
    DownloadDirectory     = "$env:USERPROFILE\androidtools\downloads"
    KeepDownloads         = $false
    PathScope             = "User"
    CheckUpdatesOnStartup = $true
    UpdateCheckInterval   = 86400
    EnableLogging         = $true
    VerifyChecksums       = $true
    DownloadTimeout       = 300
}

# ============================================================================
# ADD REQUIRED ASSEMBLIES
# ============================================================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================
Function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("Info", "Warning", "Error")][string]$Level = "Info"
    )
    if (-not $script:Settings.EnableLogging) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $logFile = "$script:LogDir\toolkit-manager.log"
    try {
        Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {}
}

Function Start-Logging {
    $logFile = "$script:LogDir\toolkit-manager.log"
    if (Test-Path $logFile) {
        $logSize = (Get-Item $logFile).Length / 1MB
        if ($logSize -gt 5) {
            $archiveFile = "$script:LogDir\toolkit-manager_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Move-Item $logFile $archiveFile -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Log "========== Application Started =========="
    Write-Log "Version: $script:AppVersion"
    Write-Log "PowerShell: $($PSVersionTable.PSVersion)"
}

# ============================================================================
# SETTINGS FUNCTIONS
# ============================================================================
Function Load-Settings {
    $settingsFile = "$script:BaseDir\settings.json"
    if (Test-Path $settingsFile) {
        try {
            $loaded = Get-Content $settingsFile -Raw | ConvertFrom-Json
            $script:Settings = $script:DefaultSettings.Clone()
            foreach ($key in $loaded.PSObject.Properties.Name) {
                $script:Settings[$key] = $loaded.$key
            }
        }
        catch {
            $script:Settings = $script:DefaultSettings.Clone()
        }
    }
    else {
        $script:Settings = $script:DefaultSettings.Clone()
        Save-Settings
    }
}

Function Save-Settings {
    $settingsFile = "$script:BaseDir\settings.json"
    try {
        $script:Settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile
        return $true
    }
    catch { return $false }
}

# ============================================================================
# INITIALIZATION
# ============================================================================
Function Initialize-Application {
    $dirs = @($script:BaseDir, $script:ToolsDir, $script:DownloadDir, $script:CacheDir, $script:LogDir)
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    $installedFile = "$script:BaseDir\installed-tools.json"
    if (-not (Test-Path $installedFile)) {
        @{ last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"); tools = @() } | 
        ConvertTo-Json -Depth 10 | Set-Content $installedFile
    }
    Load-Settings
    Start-Logging
}

# ============================================================================
# EMBEDDED DEFAULT MANIFEST
# ============================================================================
Function Get-EmbeddedManifest {
    $json = @'
{
  "manifest_version": "1.0.0",
  "last_updated": "2025-01-31T00:00:00Z",
  "update_check_interval": 86400,
  "categories": ["APK Analysis", "SDK Tools", "Remote Control", "Reverse Engineering", "Utilities"],
  "tools": [
    {
      "id": "scrcpy",
      "name": "scrcpy",
      "display_name": "scrcpy - Screen Copy",
      "description": "Display and control Android devices connected via USB or TCP/IP. High performance screen mirroring without root.",
      "category": "Remote Control",
      "homepage": "https://github.com/Genymobile/scrcpy",
      "update_source": "github_releases",
      "github_repo": "Genymobile/scrcpy",
      "asset_pattern": "scrcpy-win64-v[\\d\\.]+\\.zip",
      "current_version": "3.1",
      "release_date": "2025-01-15",
      "download_size_mb": 8.5,
      "install_type": "extract_zip",
      "install_path": "scrcpy",
      "executables": ["scrcpy.exe", "scrcpy-console.exe"],
      "add_to_path": true,
      "post_install_message": "scrcpy installed. Connect Android device and run 'scrcpy' from terminal."
    },
    {
      "id": "platform-tools",
      "name": "platform-tools",
      "display_name": "Android SDK Platform Tools",
      "description": "Official Android SDK tools including adb, fastboot, and other essential debugging utilities.",
      "category": "SDK Tools",
      "homepage": "https://developer.android.com/studio/releases/platform-tools",
      "update_source": "direct_url",
      "download_url": "https://dl.google.com/android/repository/platform-tools-latest-windows.zip",
      "current_version": "35.0.0",
      "release_date": "2024-12-10",
      "download_size_mb": 12.3,
      "install_type": "extract_zip",
      "install_path": "platform-tools",
      "executables": ["adb.exe", "fastboot.exe"],
      "add_to_path": true,
      "post_install_message": "Platform Tools installed. Use 'adb' and 'fastboot' from any terminal."
    },
    {
      "id": "apktool",
      "name": "apktool",
      "display_name": "Apktool",
      "description": "Tool for reverse engineering Android APK files. Decode resources and rebuild after modifications.",
      "category": "APK Analysis",
      "homepage": "https://apktool.org/",
      "update_source": "github_releases",
      "github_repo": "iBotPeaches/Apktool",
      "asset_pattern": "apktool_[\\d\\.]+\\.jar",
      "current_version": "2.9.3",
      "release_date": "2024-01-10",
      "download_size_mb": 9.2,
      "install_type": "jar_with_wrapper",
      "install_path": "apktool",
      "executables": ["apktool.bat"],
      "add_to_path": true,
      "dependencies": [{"name": "Java Runtime", "check_command": "java -version"}],
      "post_install_message": "Apktool installed. Requires Java Runtime Environment."
    },
    {
      "id": "jadx",
      "name": "jadx",
      "display_name": "JADX - Dex to Java Decompiler",
      "description": "Command line and GUI tools for producing Java source code from Android Dex and APK files.",
      "category": "Reverse Engineering",
      "homepage": "https://github.com/skylot/jadx",
      "update_source": "github_releases",
      "github_repo": "skylot/jadx",
      "asset_pattern": "jadx-[\\d\\.]+\\.zip",
      "current_version": "1.5.0",
      "release_date": "2024-08-20",
      "download_size_mb": 25.4,
      "install_type": "extract_zip",
      "install_path": "jadx",
      "executables": ["bin/jadx.bat", "bin/jadx-gui.bat"],
      "add_to_path": true,
      "post_install_message": "JADX installed. Run 'jadx-gui' for graphical interface."
    },
    {
      "id": "frida",
      "name": "frida-tools",
      "display_name": "Frida Tools",
      "description": "Dynamic instrumentation toolkit for developers, reverse-engineers, and security researchers.",
      "category": "Dynamic Analysis",
      "homepage": "https://frida.re/",
      "update_source": "pip",
      "pip_package": "frida-tools",
      "current_version": "12.4.0",
      "install_type": "pip_install",
      "install_path": "frida",
      "executables": ["frida.exe", "frida-ps.exe"],
      "add_to_path": false,
      "dependencies": [{"name": "Python", "check_command": "python --version"}],
      "post_install_message": "Frida installed via pip. Requires Python in PATH."
    }
  ]
}
'@
    return ($json | ConvertFrom-Json)
}

# ============================================================================
# MANIFEST FUNCTIONS
# ============================================================================
Function Get-OnlineManifest {
    param([switch]$ForceRefresh)
    $cacheFile = "$script:CacheDir\tools-manifest.json"
    $cacheMaxAge = $script:Settings.UpdateCheckInterval
    
    try {
        if ((Test-Path $cacheFile) -and -not $ForceRefresh) {
            $cacheAge = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
            if ($cacheAge.TotalSeconds -lt $cacheMaxAge) {
                Write-Log "Using cached manifest"
                return (Get-Content $cacheFile -Raw | ConvertFrom-Json)
            }
        }
        Write-Log "Downloading manifest from: $($script:Settings.ManifestUrl)"
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "AndroidToolsManager/$script:AppVersion")
        $json = $wc.DownloadString($script:Settings.ManifestUrl)
        $json | Set-Content $cacheFile -Force
        return ($json | ConvertFrom-Json)
    }
    catch {
        Write-Log "Manifest download failed: $($_.Exception.Message)" -Level Error
        if (Test-Path $cacheFile) { return (Get-Content $cacheFile -Raw | ConvertFrom-Json) }
        return Get-EmbeddedManifest
    }
}

# ============================================================================
# GITHUB API FUNCTIONS
# ============================================================================
Function Get-GitHubLatestRelease {
    param([string]$Repo, [string]$AssetPattern)
    try {
        $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "AndroidToolsManager/$script:AppVersion")
        $wc.Headers.Add("Accept", "application/vnd.github.v3+json")
        $release = $wc.DownloadString($apiUrl) | ConvertFrom-Json
        $version = $release.tag_name -replace '^v', ''
        $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
        if (-not $asset) { throw "No matching asset found" }
        return [PSCustomObject]@{
            Version      = $version
            DownloadUrl  = $asset.browser_download_url
            AssetName    = $asset.name
            AssetSize    = [Math]::Round($asset.size / 1MB, 2)
            ReleaseNotes = $release.body
        }
    }
    catch {
        Write-Log "GitHub API error: $($_.Exception.Message)" -Level Error
        return $null
    }
}

# ============================================================================
# VERSION COMPARISON
# ============================================================================
Function Compare-Version {
    param([string]$Version1, [string]$Version2)
    try {
        $v1 = $Version1 -replace '^v', '' -replace '\+.*$', '' -replace '[^\d\.]', ''
        $v2 = $Version2 -replace '^v', '' -replace '\+.*$', '' -replace '[^\d\.]', ''
        # Pad versions to have same number of parts
        $parts1 = $v1.Split('.') | ForEach-Object { [int]$_ }
        $parts2 = $v2.Split('.') | ForEach-Object { [int]$_ }
        $max = [Math]::Max($parts1.Count, $parts2.Count)
        for ($i = 0; $i -lt $max; $i++) {
            $p1 = if ($i -lt $parts1.Count) { $parts1[$i] } else { 0 }
            $p2 = if ($i -lt $parts2.Count) { $parts2[$i] } else { 0 }
            if ($p1 -lt $p2) { return -1 }
            if ($p1 -gt $p2) { return 1 }
        }
        return 0
    }
    catch { return 0 }
}

# ============================================================================
# DOWNLOAD FUNCTIONS
# ============================================================================
Function Download-File {
    param([string]$Url, [string]$OutputPath, [string]$ExpectedChecksum)
    
    try {
        Write-Log "Downloading: $Url"
        $outDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
        
        # Update status
        if ($script:StatusText) {
            $script:StatusText.Text = "Downloading..."
            $script:Window.Dispatcher.Invoke([action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
        }
        
        # Use simple synchronous download - more reliable
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "AndroidToolsManager/$script:AppVersion")
        $wc.DownloadFile($Url, $OutputPath)
        
        # Verify checksum if provided
        if ($ExpectedChecksum -and $script:Settings.VerifyChecksums) {
            $hash = (Get-FileHash -Path $OutputPath -Algorithm SHA256).Hash
            $expected = $ExpectedChecksum -replace '^sha256:', ''
            if ($hash -ne $expected) { throw "Checksum mismatch" }
        }
        
        Write-Log "Download complete: $OutputPath"
        return $true
    }
    catch {
        Write-Log "Download failed: $($_.Exception.Message)" -Level Error
        if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================
Function Install-FromZip {
    param([string]$ZipPath, [string]$DestinationPath)
    try {
        Write-Log "Extracting ZIP to: $DestinationPath"
        if (Test-Path $DestinationPath) { Remove-Item $DestinationPath -Recurse -Force }
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $DestinationPath)
        
        # Flatten if single subdirectory
        $items = Get-ChildItem -Path $DestinationPath
        if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
            $subDir = $items[0].FullName
            Get-ChildItem -Path $subDir | Move-Item -Destination $DestinationPath -Force
            Remove-Item $subDir -Force -ErrorAction SilentlyContinue
        }
        return $true
    }
    catch {
        Write-Log "ZIP extraction failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

Function Install-JarWithWrapper {
    param([string]$JarPath, [string]$DestinationPath, [string]$ToolName)
    try {
        if (-not (Test-Path $DestinationPath)) { New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null }
        $jarDest = "$DestinationPath\$ToolName.jar"
        Copy-Item $JarPath $jarDest -Force
        $batchContent = "@echo off`r`njava -jar `"%~dp0$ToolName.jar`" %*"
        Set-Content "$DestinationPath\$ToolName.bat" $batchContent -Force
        return $true
    }
    catch {
        Write-Log "JAR install failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# ============================================================================
# PATH MANAGEMENT
# ============================================================================
Function Add-ToPath {
    param([string]$ToolPath)
    try {
        $scope = $script:Settings.PathScope
        if ($scope -eq "Machine") {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $isAdmin) { $scope = "User" }
        }
        $current = [Environment]::GetEnvironmentVariable("Path", $scope)
        $entries = $current -split ';' | Where-Object { $_ }
        if ($entries -contains $ToolPath) { return $true }
        $new = "$current;$ToolPath"
        [Environment]::SetEnvironmentVariable("Path", $new, $scope)
        $env:Path = "$env:Path;$ToolPath"
        Write-Log "Added to $scope PATH: $ToolPath"
        return $true
    }
    catch {
        Write-Log "PATH update failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

Function Remove-FromPath {
    param([string]$ToolPath)
    try {
        foreach ($scope in @("User", "Machine")) {
            if ($scope -eq "Machine") {
                $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                if (-not $isAdmin) { continue }
            }
            $current = [Environment]::GetEnvironmentVariable("Path", $scope)
            $entries = $current -split ';' | Where-Object { $_ -and $_ -ne $ToolPath }
            $new = $entries -join ';'
            if ($current -ne $new) {
                [Environment]::SetEnvironmentVariable("Path", $new, $scope)
            }
        }
        $env:Path = ($env:Path -split ';' | Where-Object { $_ -ne $ToolPath }) -join ';'
        return $true
    }
    catch { return $false }
}

# ============================================================================
# TOOL MANAGEMENT FUNCTIONS
# ============================================================================
Function Get-InstalledTools {
    $file = "$script:BaseDir\installed-tools.json"
    if (Test-Path $file) { return (Get-Content $file -Raw | ConvertFrom-Json) }
    return @{ last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"); tools = @() }
}

Function Save-InstalledTools {
    param($Data)
    $Data | ConvertTo-Json -Depth 10 | Set-Content "$script:BaseDir\installed-tools.json"
}

Function Install-Tool {
    param([string]$ToolId)
    Write-Log "Installing: $ToolId"
    $manifest = Get-OnlineManifest
    $tool = $manifest.tools | Where-Object { $_.id -eq $ToolId }
    if (-not $tool) { return $false }
    
    $installedData = Get-InstalledTools
    $existing = $installedData.tools | Where-Object { $_.id -eq $ToolId }
    if ($existing) { Uninstall-Tool -ToolId $ToolId -Silent }
    
    # Check dependencies
    if ($tool.dependencies) {
        foreach ($dep in $tool.dependencies) {
            try { Invoke-Expression $dep.check_command 2>&1 | Out-Null }
            catch {
                [System.Windows.MessageBox]::Show("Missing dependency: $($dep.name)", "Dependency Required", "OK", "Warning")
                return $false
            }
        }
    }
    
    # Get download URL
    $downloadUrl = $null
    $version = $tool.current_version
    
    switch ($tool.update_source) {
        "github_releases" {
            $release = Get-GitHubLatestRelease -Repo $tool.github_repo -AssetPattern $tool.asset_pattern
            if ($release) { $downloadUrl = $release.DownloadUrl; $version = $release.Version }
            else { $downloadUrl = $tool.fallback_url }
        }
        "direct_url" { $downloadUrl = $tool.download_url }
        "pip" { 
            # Handle pip install separately
            try {
                $result = & pip install --upgrade $tool.pip_package 2>&1
                Write-Log "Pip install result: $result"
            }
            catch { return $false }
        }
    }
    
    if ($downloadUrl) {
        $fileName = Split-Path $downloadUrl -Leaf
        $downloadPath = "$script:DownloadDir\$fileName"
        $installPath = "$script:ToolsDir\$($tool.install_path)"
        
        # Step 1: Download
        Write-OperationLog "Step 1: Downloading $fileName..." -Level "PROGRESS"
        if (-not (Download-File -Url $downloadUrl -OutputPath $downloadPath)) { 
            Write-OperationLog "Download failed for $ToolId" -Level "ERROR"
            return $false 
        }
        Write-OperationLog "Download complete: $fileName" -Level "SUCCESS"
        
        # Step 2: Extract/Install
        Write-OperationLog "Step 2: Extracting to $installPath..." -Level "PROGRESS"
        $success = switch ($tool.install_type) {
            "extract_zip" { Install-FromZip -ZipPath $downloadPath -DestinationPath $installPath }
            "jar_with_wrapper" { Install-JarWithWrapper -JarPath $downloadPath -DestinationPath $installPath -ToolName $tool.name }
            default { $false }
        }
        
        if (-not $success) { 
            Write-OperationLog "Extraction failed for $ToolId" -Level "ERROR"
            return $false 
        }
        Write-OperationLog "Extraction complete" -Level "SUCCESS"
        
        # Step 3: Add to PATH if configured
        if ($tool.add_to_path) { 
            Write-OperationLog "Step 3: Adding to PATH: $installPath" -Level "PROGRESS"
            Add-ToPath -ToolPath $installPath 
            Write-OperationLog "Added to PATH successfully" -Level "SUCCESS"
        }
        
        # Step 4: Remove downloaded zip to save space
        if (-not $script:Settings.KeepDownloads) { 
            Write-OperationLog "Step 4: Removing downloaded zip file..." -Level "PROGRESS"
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue 
            Write-OperationLog "Zip file removed" -Level "SUCCESS"
        }
    }
    
    # Update installed tools record
    $installPath = "$script:ToolsDir\$($tool.install_path)"
    $installedTool = [PSCustomObject]@{
        id                = $tool.id
        installed_version = $version
        install_date      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        install_path      = $installPath
        executables       = $tool.executables
        in_path           = $tool.add_to_path
        size_mb           = if (Test-Path $installPath) { [Math]::Round((Get-ChildItem -Path $installPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB, 2) } else { 0 }
    }
    
    $installedData.tools = @($installedData.tools | Where-Object { $_.id -ne $ToolId }) + $installedTool
    Save-InstalledTools $installedData
    
    Write-Log "Installation complete: $ToolId v$version"
    if ($tool.post_install_message) {
        [System.Windows.MessageBox]::Show($tool.post_install_message, "Installation Complete", "OK", "Information")
    }
    return $true
}

Function Uninstall-Tool {
    param([string]$ToolId, [switch]$Silent)
    Write-Log "Uninstalling: $ToolId"
    $installedData = Get-InstalledTools
    $tool = $installedData.tools | Where-Object { $_.id -eq $ToolId }
    if (-not $tool) { return $false }
    
    if (-not $Silent) {
        $result = [System.Windows.MessageBox]::Show("Uninstall $ToolId ?", "Confirm", "YesNo", "Question")
        if ($result -ne "Yes") { return $false }
    }
    
    try {
        if ($tool.in_path) { Remove-FromPath -ToolPath $tool.install_path }
        if (Test-Path $tool.install_path) { Remove-Item $tool.install_path -Recurse -Force }
        $installedData.tools = @($installedData.tools | Where-Object { $_.id -ne $ToolId })
        Save-InstalledTools $installedData
        Write-Log "Uninstall complete: $ToolId"
        return $true
    }
    catch {
        Write-Log "Uninstall failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

Function Update-Tool {
    param([string]$ToolId)
    Write-Log "Updating: $ToolId"
    Uninstall-Tool -ToolId $ToolId -Silent
    return (Install-Tool -ToolId $ToolId)
}

Function Check-ToolUpdates {
    $installedData = Get-InstalledTools
    $manifest = Get-OnlineManifest
    $updates = @()
    
    foreach ($installed in $installedData.tools) {
        $online = $manifest.tools | Where-Object { $_.id -eq $installed.id }
        if (-not $online) { continue }
        
        $latestVersion = $online.current_version
        if ($online.update_source -eq "github_releases") {
            $release = Get-GitHubLatestRelease -Repo $online.github_repo -AssetPattern $online.asset_pattern
            if ($release) { $latestVersion = $release.Version }
        }
        
        if ((Compare-Version $installed.installed_version $latestVersion) -lt 0) {
            $updates += [PSCustomObject]@{
                ToolId         = $installed.id
                ToolName       = $online.display_name
                CurrentVersion = $installed.installed_version
                LatestVersion  = $latestVersion
            }
        }
    }
    return $updates
}

# ============================================================================
# XAML UI DEFINITION
# ============================================================================
$script:XAML = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Android Pentesting Toolkit Manager v1.0" 
        Height="650" Width="900" MinHeight="600" MinWidth="800"
        WindowStartupLocation="CenterScreen"
        Background="#000000">
    <Window.Resources>
        <!-- Button Style -->
        <Style TargetType="Button">
            <Setter Property="Background" Value="#007ACC"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="15,8"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#1C97EA"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Background" Value="#3E3E3E"/>
                    <Setter Property="Foreground" Value="#888888"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <!-- TextBox Style -->
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#111111"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
        <!-- ListBox Style -->
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="#0A0A0A"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#222222"/>
        </Style>
        <Style TargetType="ListBoxItem">
            <Setter Property="Padding" Value="10"/>
            <Setter Property="Margin" Value="2"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="White"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#0066CC"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#1A1A1A"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <!-- ComboBox Style with dark dropdown -->
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#111111"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#333333"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,5"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleButton" 
                                Grid.Column="2" 
                                Focusable="false"
                                IsChecked="{Binding Path=IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                ClickMode="Press"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="1">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="3">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition/>
                                                    <ColumnDefinition Width="20"/>
                                                </Grid.ColumnDefinitions>
                                                <ContentPresenter Grid.Column="0"/>
                                                <Path Grid.Column="1" Fill="White" Data="M0,0 L4,4 L8,0 Z" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter x:Name="ContentSite"
                                IsHitTestVisible="False"
                                Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"
                                Margin="8,3,25,3"
                                VerticalAlignment="Center"
                                HorizontalAlignment="Left"/>
                            <Popup x:Name="Popup"
                                Placement="Bottom"
                                IsOpen="{TemplateBinding IsDropDownOpen}"
                                AllowsTransparency="True"
                                Focusable="False"
                                PopupAnimation="Slide">
                                <Border x:Name="DropDownBorder"
                                    Background="#1A1A1A"
                                    BorderBrush="#333333"
                                    BorderThickness="1"
                                    MinWidth="{TemplateBinding ActualWidth}"
                                    MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <ScrollViewer>
                                        <ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- ComboBoxItem Style for dropdown -->
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="#1A1A1A"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="Border" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#0066CC"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="#007ACC"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- CheckBox Style -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Margin" Value="5"/>
        </Style>
        <!-- RadioButton Style -->
        <Style TargetType="RadioButton">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Margin" Value="5"/>
        </Style>
    </Window.Resources>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Main Tab Control -->
        <TabControl Grid.Row="0" Background="#000000" BorderThickness="0" Margin="10">
            <TabControl.Resources>
                <Style TargetType="TabItem">
                    <Setter Property="Background" Value="#111111"/>
                    <Setter Property="Foreground" Value="#CCCCCC"/>
                    <Setter Property="Padding" Value="15,8"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="TabItem">
                                <Border x:Name="Border" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" Margin="0,0,2,0">
                                    <ContentPresenter ContentSource="Header"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsSelected" Value="True">
                                        <Setter TargetName="Border" Property="Background" Value="#007ACC"/>
                                        <Setter Property="Foreground" Value="White"/>
                                    </Trigger>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="Border" Property="Background" Value="#222222"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Style>
            </TabControl.Resources>
            
            <!-- TAB 1: Install Tools -->
            <TabItem Header="Install Tools">
                <Grid Background="#000000">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="350"/>
                    </Grid.ColumnDefinitions>
                    
                    <!-- Search Bar -->
                    <StackPanel Grid.Row="0" Grid.ColumnSpan="2" Orientation="Horizontal" Margin="5">
                        <TextBox x:Name="SearchTextBox" Width="250" ToolTip="Search tools..."/>
                        <ComboBox x:Name="CategoryComboBox" Width="150">
                            <ComboBoxItem Content="All Categories" IsSelected="True"/>
                        </ComboBox>
                        <Button x:Name="RefreshButton" Content="Refresh" Width="80"/>
                        <Button x:Name="InstallSelectedButton" Content="Install Selected" Width="120" Background="#00AA00"/>
                    </StackPanel>
                    
                    <!-- Tools List with Multi-Select -->
                    <ListBox x:Name="ToolsListBox" Grid.Row="1" Grid.Column="0" Margin="5" SelectionMode="Extended" ScrollViewer.VerticalScrollBarVisibility="Auto"/>
                    
                    <!-- Tool Details Panel -->
                    <Border Grid.Row="1" Grid.Column="1" Background="#0A0A0A" Margin="5" CornerRadius="5" Padding="15">
                        <ScrollViewer VerticalScrollBarVisibility="Auto">
                            <StackPanel x:Name="DetailPanel">
                                <TextBlock x:Name="DetailToolName" FontSize="18" FontWeight="Bold" Foreground="White" TextWrapping="Wrap" Margin="0,0,0,10"/>
                                <TextBlock x:Name="DetailDescription" Foreground="#CCCCCC" TextWrapping="Wrap" Margin="0,0,0,15"/>
                                
                                <StackPanel Orientation="Horizontal" Margin="0,5">
                                    <TextBlock Text="Category: " Foreground="#888888"/>
                                    <TextBlock x:Name="DetailCategory" Foreground="#007ACC"/>
                                </StackPanel>
                                <StackPanel Orientation="Horizontal" Margin="0,5">
                                    <TextBlock Text="Version: " Foreground="#888888"/>
                                    <TextBlock x:Name="DetailVersion" Foreground="White"/>
                                </StackPanel>
                                <StackPanel Orientation="Horizontal" Margin="0,5">
                                    <TextBlock Text="Size: " Foreground="#888888"/>
                                    <TextBlock x:Name="DetailSize" Foreground="White"/>
                                </StackPanel>
                                <StackPanel Orientation="Horizontal" Margin="0,5">
                                    <TextBlock Text="Status: " Foreground="#888888"/>
                                    <TextBlock x:Name="DetailStatus" Foreground="#4EC9B0"/>
                                </StackPanel>
                                
                                <StackPanel Orientation="Horizontal" Margin="0,20,0,0">
                                    <Button x:Name="InstallButton" Content="Install" Width="100"/>
                                    <Button x:Name="UpdateButton" Content="Update" Width="100" Visibility="Collapsed"/>
                                    <Button x:Name="UninstallButton" Content="Uninstall" Width="100" Visibility="Collapsed" Background="#C42B1C"/>
                                </StackPanel>
                                <Button x:Name="OpenFolderButton" Content="Open Folder" Width="210" Visibility="Collapsed" Margin="5,5,5,0"/>
                            </StackPanel>
                        </ScrollViewer>
                    </Border>
                    
                    <!-- Selection Info -->
                    <Border Grid.Row="2" Grid.ColumnSpan="2" Background="#0A0A0A" Padding="10,5">
                        <TextBlock x:Name="SelectionInfoText" Foreground="#AAAAAA" Text="Hold Ctrl to select multiple tools, then click 'Install Selected'"/>
                    </Border>
                </Grid>
            </TabItem>
            
            <!-- TAB 2: Updates -->
            <TabItem x:Name="UpdatesTab" Header="Updates">
                <Grid Background="#000000">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10">
                        <TextBlock Text="Available Updates" FontSize="16" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
                        <Button x:Name="CheckUpdatesButton" Content="Check for Updates" Margin="20,0,0,0"/>
                        <TextBlock x:Name="LastCheckText" Foreground="#888888" VerticalAlignment="Center" Margin="20,0,0,0"/>
                    </StackPanel>
                    
                    <ListBox x:Name="UpdatesListBox" Grid.Row="1" Margin="10"/>
                    
                    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="10">
                        <Button x:Name="UpdateAllButton" Content="Update All"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- TAB 3: Installed Tools -->
            <TabItem Header="Installed">
                <Grid Background="#000000">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <TextBlock Grid.Row="0" Text="Installed Tools" FontSize="16" FontWeight="Bold" Foreground="White" Margin="10"/>
                    <ListBox x:Name="InstalledListBox" Grid.Row="1" Margin="10"/>
                    
                    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="10">
                        <TextBlock x:Name="InstalledStatsText" Foreground="#888888" VerticalAlignment="Center"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- TAB 4: Settings -->
            <TabItem Header="Settings">
                <ScrollViewer Background="#000000" VerticalScrollBarVisibility="Auto">
                    <StackPanel Margin="20">
                        <TextBlock Text="Settings" FontSize="18" FontWeight="Bold" Foreground="White" Margin="0,0,0,20"/>
                        
                        <!-- Installation Settings -->
                        <TextBlock Text="Installation Directory:" Foreground="#CCCCCC" Margin="0,10,0,5"/>
                        <TextBox x:Name="InstallDirTextBox" Width="500" HorizontalAlignment="Left"/>
                        
                        <!-- PATH Settings -->
                        <TextBlock Text="PATH Configuration:" Foreground="#CCCCCC" Margin="0,20,0,10"/>
                        <RadioButton x:Name="UserPathRadio" Content="Add to User PATH (recommended)" IsChecked="True" GroupName="PathScope"/>
                        <RadioButton x:Name="SystemPathRadio" Content="Add to System PATH (requires admin)" GroupName="PathScope"/>
                        
                        <!-- Update Settings -->
                        <TextBlock Text="Update Settings:" Foreground="#CCCCCC" Margin="0,20,0,10"/>
                        <CheckBox x:Name="CheckUpdatesStartupCheckBox" Content="Check for updates on startup" IsChecked="True"/>
                        <CheckBox x:Name="KeepDownloadsCheckBox" Content="Keep downloaded files after installation"/>
                        
                        <!-- Logging -->
                        <TextBlock Text="Advanced:" Foreground="#CCCCCC" Margin="0,20,0,10"/>
                        <CheckBox x:Name="EnableLoggingCheckBox" Content="Enable logging" IsChecked="True"/>
                        <CheckBox x:Name="VerifyChecksumsCheckBox" Content="Verify file checksums (SHA256)" IsChecked="True"/>
                        
                        <!-- Manifest URL -->
                        <TextBlock Text="Manifest URL:" Foreground="#CCCCCC" Margin="0,20,0,5"/>
                        <TextBox x:Name="ManifestUrlTextBox" Width="600" HorizontalAlignment="Left"/>
                        
                        <!-- Action Buttons -->
                        <StackPanel Orientation="Horizontal" Margin="0,30,0,0">
                            <Button x:Name="SaveSettingsButton" Content="Save Settings"/>
                            <Button x:Name="ResetSettingsButton" Content="Reset to Defaults" Background="#222222"/>
                            <Button x:Name="ClearCacheButton" Content="Clear Cache" Background="#222222"/>
                        </StackPanel>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
            
            <!-- TAB 5: Operations Log -->
            <TabItem Header="Operations Log">
                <Grid Background="#000000">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    
                    <!-- Header -->
                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="10">
                        <TextBlock Text="Live Operations Log" FontSize="16" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
                        <TextBlock x:Name="LogCountText" Foreground="#888888" VerticalAlignment="Center" Margin="20,0,0,0"/>
                    </StackPanel>
                    
                    <!-- Log List -->
                    <ListBox x:Name="OperationsLogListBox" Grid.Row="1" Margin="10" 
                             ScrollViewer.VerticalScrollBarVisibility="Auto"
                             ScrollViewer.CanContentScroll="True"
                             Background="#0A0A0A" BorderBrush="#222222">
                        <ListBox.ItemTemplate>
                            <DataTemplate>
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="{Binding Timestamp}" Foreground="#666666" Width="90" FontFamily="Consolas" FontSize="11"/>
                                    <TextBlock Text="{Binding Level}" Foreground="{Binding LevelColor}" Width="70" FontWeight="SemiBold" FontSize="11"/>
                                    <TextBlock Text="{Binding Message}" Foreground="White" TextWrapping="Wrap" FontSize="11" MaxWidth="600"/>
                                </StackPanel>
                            </DataTemplate>
                        </ListBox.ItemTemplate>
                    </ListBox>
                    
                    <!-- Controls -->
                    <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="10">
                        <Button x:Name="ClearLogButton" Content="Clear Log" Background="#333333"/>
                        <Button x:Name="ExportLogButton" Content="Export Log" Background="#333333"/>
                        <CheckBox x:Name="AutoScrollCheckBox" Content="Auto-scroll" Foreground="White" IsChecked="True" VerticalAlignment="Center" Margin="20,0,0,0"/>
                    </StackPanel>
                </Grid>
            </TabItem>
            
            <!-- TAB 6: About -->
            <TabItem Header="About">
                <Grid Background="#000000">
                    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
                        <TextBlock Text="ANDROID TOOLS" FontSize="32" FontWeight="Bold" Foreground="#007ACC" HorizontalAlignment="Center"/>
                        <TextBlock Text="Android Pentesting Toolkit Manager" FontSize="24" FontWeight="Bold" Foreground="White" HorizontalAlignment="Center" Margin="0,10,0,5"/>
                        <TextBlock x:Name="AboutVersionText" FontSize="14" Foreground="#888888" HorizontalAlignment="Center"/>
                        <TextBlock Text="Automated installer for Android pentesting tools" Foreground="#CCCCCC" HorizontalAlignment="Center" Margin="0,20,0,0"/>
                        
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,30,0,0">
                            <TextBlock Text="PowerShell: " Foreground="#888888"/>
                            <TextBlock x:Name="AboutPSVersion" Foreground="White"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,5,0,0">
                            <TextBlock Text="Windows: " Foreground="#888888"/>
                            <TextBlock x:Name="AboutWinVersion" Foreground="White"/>
                        </StackPanel>
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,5,0,0">
                            <TextBlock Text="Install Path: " Foreground="#888888"/>
                            <TextBlock x:Name="AboutInstallPath" Foreground="White"/>
                        </StackPanel>
                    </StackPanel>
                </Grid>
            </TabItem>
        </TabControl>
        
        <!-- Status Bar -->
        <Border Grid.Row="1" Background="#007ACC" Padding="10,5">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="200"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="StatusText" Grid.Column="0" Text="Ready" Foreground="White" VerticalAlignment="Center"/>
                <ProgressBar x:Name="ProgressBar" Grid.Column="1" Height="15" Minimum="0" Maximum="100" Value="0" Visibility="Collapsed"/>
            </Grid>
        </Border>
    </Grid>
</Window>
'@

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Initialize application
Initialize-Application

# Parse XAML and create window
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($script:XAML))
$script:Window = [Windows.Markup.XamlReader]::Load($reader)

# Get UI element references
$script:SearchTextBox = $script:Window.FindName("SearchTextBox")
$script:CategoryComboBox = $script:Window.FindName("CategoryComboBox")
$script:RefreshButton = $script:Window.FindName("RefreshButton")
$script:InstallSelectedButton = $script:Window.FindName("InstallSelectedButton")
$script:SelectionInfoText = $script:Window.FindName("SelectionInfoText")
$script:ToolsListBox = $script:Window.FindName("ToolsListBox")
$script:DetailToolName = $script:Window.FindName("DetailToolName")
$script:DetailDescription = $script:Window.FindName("DetailDescription")
$script:DetailCategory = $script:Window.FindName("DetailCategory")
$script:DetailVersion = $script:Window.FindName("DetailVersion")
$script:DetailSize = $script:Window.FindName("DetailSize")
$script:DetailStatus = $script:Window.FindName("DetailStatus")
$script:InstallButton = $script:Window.FindName("InstallButton")
$script:UpdateButton = $script:Window.FindName("UpdateButton")
$script:UninstallButton = $script:Window.FindName("UninstallButton")
$script:OpenFolderButton = $script:Window.FindName("OpenFolderButton")
$script:UpdatesTab = $script:Window.FindName("UpdatesTab")
$script:CheckUpdatesButton = $script:Window.FindName("CheckUpdatesButton")
$script:LastCheckText = $script:Window.FindName("LastCheckText")
$script:UpdatesListBox = $script:Window.FindName("UpdatesListBox")
$script:UpdateAllButton = $script:Window.FindName("UpdateAllButton")
$script:InstalledListBox = $script:Window.FindName("InstalledListBox")
$script:InstalledStatsText = $script:Window.FindName("InstalledStatsText")
$script:InstallDirTextBox = $script:Window.FindName("InstallDirTextBox")
$script:UserPathRadio = $script:Window.FindName("UserPathRadio")
$script:SystemPathRadio = $script:Window.FindName("SystemPathRadio")
$script:CheckUpdatesStartupCheckBox = $script:Window.FindName("CheckUpdatesStartupCheckBox")
$script:KeepDownloadsCheckBox = $script:Window.FindName("KeepDownloadsCheckBox")
$script:EnableLoggingCheckBox = $script:Window.FindName("EnableLoggingCheckBox")
$script:VerifyChecksumsCheckBox = $script:Window.FindName("VerifyChecksumsCheckBox")
$script:ManifestUrlTextBox = $script:Window.FindName("ManifestUrlTextBox")
$script:SaveSettingsButton = $script:Window.FindName("SaveSettingsButton")
$script:ResetSettingsButton = $script:Window.FindName("ResetSettingsButton")
$script:ClearCacheButton = $script:Window.FindName("ClearCacheButton")
$script:StatusText = $script:Window.FindName("StatusText")
$script:ProgressBar = $script:Window.FindName("ProgressBar")
$script:AboutVersionText = $script:Window.FindName("AboutVersionText")
$script:AboutPSVersion = $script:Window.FindName("AboutPSVersion")
$script:AboutWinVersion = $script:Window.FindName("AboutWinVersion")
$script:AboutInstallPath = $script:Window.FindName("AboutInstallPath")

# Track selected tool
$script:SelectedToolId = $null

# Operations Log controls
$script:OperationsLogListBox = $script:Window.FindName("OperationsLogListBox")
$script:LogCountText = $script:Window.FindName("LogCountText")
$script:ClearLogButton = $script:Window.FindName("ClearLogButton")
$script:ExportLogButton = $script:Window.FindName("ExportLogButton")
$script:AutoScrollCheckBox = $script:Window.FindName("AutoScrollCheckBox")

# Operations log entries collection
$script:LogEntries = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
$script:OperationsLogListBox.ItemsSource = $script:LogEntries

# ============================================================================
# UI HELPER FUNCTIONS
# ============================================================================

# Function to write to operations log UI
Function Write-OperationLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "PROGRESS")][string]$Level = "INFO"
    )
    
    # Color mapping for levels
    $levelColor = switch ($Level) {
        "INFO" { "#AAAAAA" }
        "SUCCESS" { "#4EC9B0" }
        "WARNING" { "#FFA500" }
        "ERROR" { "#E74C3C" }
        "PROGRESS" { "#007ACC" }
        default { "#FFFFFF" }
    }
    
    $logEntry = [PSCustomObject]@{
        Timestamp  = Get-Date -Format "HH:mm:ss"
        Level      = "[$Level]"
        LevelColor = $levelColor
        Message    = $Message
    }
    
    # Add to UI log (thread-safe)
    $script:Window.Dispatcher.Invoke([action] {
            $script:LogEntries.Add($logEntry)
            $script:LogCountText.Text = "$($script:LogEntries.Count) entries"
        
            # Auto-scroll to bottom if enabled
            if ($script:AutoScrollCheckBox.IsChecked -and $script:LogEntries.Count -gt 0) {
                $script:OperationsLogListBox.ScrollIntoView($script:LogEntries[$script:LogEntries.Count - 1])
            }
        }, [System.Windows.Threading.DispatcherPriority]::Background)
    
    # Also write to file log
    Write-Log -Message $Message -Level $(if ($Level -eq "SUCCESS") { "Info" } elseif ($Level -eq "PROGRESS") { "Info" } else { $Level })
}
Function Refresh-ToolsList {
    $manifest = Get-OnlineManifest
    $installedData = Get-InstalledTools
    $searchText = $script:SearchTextBox.Text.ToLower()
    $category = $script:CategoryComboBox.SelectedItem.Content
    
    # Populate categories if empty
    if ($script:CategoryComboBox.Items.Count -eq 1) {
        foreach ($cat in $manifest.categories) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = $cat
            $script:CategoryComboBox.Items.Add($item) | Out-Null
        }
    }
    
    $script:ToolsListBox.Items.Clear()
    
    foreach ($tool in $manifest.tools) {
        # Apply filters
        if ($searchText -and -not (($tool.name -like "*$searchText*") -or ($tool.display_name -like "*$searchText*") -or ($tool.description -like "*$searchText*"))) { continue }
        if ($category -and $category -ne "All Categories" -and $tool.category -ne $category) { continue }
        
        $installed = $installedData.tools | Where-Object { $_.id -eq $tool.id }
        $status = if ($installed) { "Installed v$($installed.installed_version)" } else { "Not Installed" }
        
        $item = New-Object System.Windows.Controls.ListBoxItem
        $item.Tag = $tool.id
        
        $stack = New-Object System.Windows.Controls.StackPanel
        $name = New-Object System.Windows.Controls.TextBlock
        $name.Text = $tool.display_name
        $name.FontWeight = "Bold"
        $name.FontSize = 14
        $name.Foreground = [System.Windows.Media.Brushes]::White
        
        $desc = New-Object System.Windows.Controls.TextBlock
        $desc.Text = $tool.description
        $desc.FontSize = 11
        $desc.Foreground = [System.Windows.Media.Brushes]::Gray
        $desc.TextTrimming = "CharacterEllipsis"
        $desc.MaxWidth = 400
        
        $statusText = New-Object System.Windows.Controls.TextBlock
        $statusText.Text = "[$($tool.category)] - $status"
        $statusText.FontSize = 10
        $statusText.Foreground = if ($installed) { [System.Windows.Media.Brushes]::LightGreen } else { [System.Windows.Media.Brushes]::Orange }
        $statusText.Margin = "0,5,0,0"
        
        $stack.Children.Add($name) | Out-Null
        $stack.Children.Add($desc) | Out-Null
        $stack.Children.Add($statusText) | Out-Null
        $item.Content = $stack
        
        $script:ToolsListBox.Items.Add($item) | Out-Null
    }
    
    $script:StatusText.Text = "Ready - $($manifest.tools.Count) tools available"
}

Function Show-ToolDetails {
    param([string]$ToolId)
    if (-not $ToolId) { return }
    
    $manifest = Get-OnlineManifest
    $tool = $manifest.tools | Where-Object { $_.id -eq $ToolId }
    if (-not $tool) { return }
    
    $installedData = Get-InstalledTools
    $installed = $installedData.tools | Where-Object { $_.id -eq $ToolId }
    
    $script:DetailToolName.Text = $tool.display_name
    $script:DetailDescription.Text = $tool.description
    $script:DetailCategory.Text = $tool.category
    $script:DetailVersion.Text = $tool.current_version
    $script:DetailSize.Text = "$($tool.download_size_mb) MB"
    
    if ($installed) {
        $script:DetailStatus.Text = "Installed v$($installed.installed_version)"
        $script:DetailStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen
        $script:InstallButton.Visibility = "Collapsed"
        $script:UninstallButton.Visibility = "Visible"
        $script:OpenFolderButton.Visibility = "Visible"
        
        # Check for updates
        if ((Compare-Version $installed.installed_version $tool.current_version) -lt 0) {
            $script:UpdateButton.Visibility = "Visible"
            $script:DetailStatus.Text = "Update Available ($($installed.installed_version) → $($tool.current_version))"
            $script:DetailStatus.Foreground = [System.Windows.Media.Brushes]::Orange
        }
        else {
            $script:UpdateButton.Visibility = "Collapsed"
        }
    }
    else {
        $script:DetailStatus.Text = "Not Installed"
        $script:DetailStatus.Foreground = [System.Windows.Media.Brushes]::Gray
        $script:InstallButton.Visibility = "Visible"
        $script:UpdateButton.Visibility = "Collapsed"
        $script:UninstallButton.Visibility = "Collapsed"
        $script:OpenFolderButton.Visibility = "Collapsed"
    }
}

Function Refresh-InstalledList {
    $installedData = Get-InstalledTools
    $script:InstalledListBox.Items.Clear()
    $totalSize = 0
    
    foreach ($tool in $installedData.tools) {
        $item = New-Object System.Windows.Controls.ListBoxItem
        $item.Tag = $tool.id
        
        $stack = New-Object System.Windows.Controls.StackPanel
        $stack.Orientation = "Horizontal"
        
        $name = New-Object System.Windows.Controls.TextBlock
        $name.Text = "$($tool.id) v$($tool.installed_version)"
        $name.Width = 250
        $name.Foreground = [System.Windows.Media.Brushes]::White
        
        $size = New-Object System.Windows.Controls.TextBlock
        $size.Text = "$($tool.size_mb) MB"
        $size.Width = 100
        $size.Foreground = [System.Windows.Media.Brushes]::Gray
        
        $date = New-Object System.Windows.Controls.TextBlock
        $date.Text = $tool.install_date.Substring(0, 10)
        $date.Foreground = [System.Windows.Media.Brushes]::Gray
        
        $stack.Children.Add($name) | Out-Null
        $stack.Children.Add($size) | Out-Null
        $stack.Children.Add($date) | Out-Null
        $item.Content = $stack
        
        $script:InstalledListBox.Items.Add($item) | Out-Null
        $totalSize += $tool.size_mb
    }
    
    $script:InstalledStatsText.Text = "$($installedData.tools.Count) tools installed, $([Math]::Round($totalSize, 1)) MB total"
}

Function Load-SettingsUI {
    $script:InstallDirTextBox.Text = $script:Settings.InstallDirectory
    $script:ManifestUrlTextBox.Text = $script:Settings.ManifestUrl
    $script:UserPathRadio.IsChecked = ($script:Settings.PathScope -eq "User")
    $script:SystemPathRadio.IsChecked = ($script:Settings.PathScope -eq "Machine")
    $script:CheckUpdatesStartupCheckBox.IsChecked = $script:Settings.CheckUpdatesOnStartup
    $script:KeepDownloadsCheckBox.IsChecked = $script:Settings.KeepDownloads
    $script:EnableLoggingCheckBox.IsChecked = $script:Settings.EnableLogging
    $script:VerifyChecksumsCheckBox.IsChecked = $script:Settings.VerifyChecksums
}

# ============================================================================
# EVENT HANDLERS
# ============================================================================

# Search text changed
$script:SearchTextBox.Add_TextChanged({ Refresh-ToolsList })

# Category changed
$script:CategoryComboBox.Add_SelectionChanged({ Refresh-ToolsList })

# Refresh button
$script:RefreshButton.Add_Click({
        $script:StatusText.Text = "Refreshing..."
        Get-OnlineManifest -ForceRefresh | Out-Null
        Refresh-ToolsList
        Refresh-InstalledList
    })

# Install Selected button - batch install multiple selected tools
$script:InstallSelectedButton.Add_Click({
        $selectedItems = $script:ToolsListBox.SelectedItems
        if ($selectedItems.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Please select at least one tool to install.`n`nTip: Hold Ctrl and click to select multiple tools.", "No Selection", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            return
        }
        
        $toolIds = @()
        foreach ($item in $selectedItems) {
            $toolIds += $item.Tag
        }
        
        $confirm = [System.Windows.MessageBox]::Show("Install $($toolIds.Count) selected tool(s)?`n`n$($toolIds -join ', ')", "Confirm Batch Install", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
        
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            Write-OperationLog "Starting batch installation of $($toolIds.Count) tools..." -Level "PROGRESS"
            $script:ProgressBar.Visibility = "Visible"
            $script:ProgressBar.IsIndeterminate = $true
            
            $successCount = 0
            $failCount = 0
            
            foreach ($toolId in $toolIds) {
                Write-OperationLog "Installing $toolId ($($successCount + $failCount + 1)/$($toolIds.Count))..." -Level "PROGRESS"
                $script:StatusText.Text = "Installing $toolId... ($($successCount + $failCount + 1)/$($toolIds.Count))"
                $script:Window.Dispatcher.Invoke([action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
                
                $result = Install-Tool -ToolId $toolId
                if ($result) { 
                    $successCount++
                    Write-OperationLog "$toolId installed successfully" -Level "SUCCESS"
                }
                else { 
                    $failCount++
                    Write-OperationLog "$toolId installation failed" -Level "ERROR"
                }
            }
            
            $script:ProgressBar.Visibility = "Collapsed"
            $script:ProgressBar.IsIndeterminate = $false
            
            $script:StatusText.Text = "Batch install complete: $successCount succeeded, $failCount failed"
            Write-OperationLog "Batch installation complete: $successCount succeeded, $failCount failed" -Level $(if ($failCount -eq 0) { "SUCCESS" } else { "WARNING" })
            [System.Windows.MessageBox]::Show("Batch installation complete!`n`nSuccessful: $successCount`nFailed: $failCount", "Installation Complete", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            
            Refresh-ToolsList
            Refresh-InstalledList
        }
    })

# Tool selection - update info when selection changes
$script:ToolsListBox.Add_SelectionChanged({
        $count = $script:ToolsListBox.SelectedItems.Count
        if ($count -gt 1) {
            $script:SelectionInfoText.Text = "$count tools selected - click 'Install Selected' to batch install"
        }
        elseif ($count -eq 1) {
            $script:SelectedToolId = $script:ToolsListBox.SelectedItem.Tag
            Show-ToolDetails -ToolId $script:SelectedToolId
            $script:SelectionInfoText.Text = "1 tool selected - Hold Ctrl to select more"
        }
        else {
            $script:SelectionInfoText.Text = "Hold Ctrl to select multiple tools, then click 'Install Selected'"
        }
    })

$script:InstallButton.Add_Click({
        if ($script:SelectedToolId) {
            Write-OperationLog "Starting installation of $($script:SelectedToolId)..." -Level "PROGRESS"
            $script:StatusText.Text = "Installing $($script:SelectedToolId)..."
            $script:ProgressBar.Visibility = "Visible"
            $script:ProgressBar.IsIndeterminate = $true
        
            $result = Install-Tool -ToolId $script:SelectedToolId
        
            $script:ProgressBar.Visibility = "Collapsed"
            $script:ProgressBar.IsIndeterminate = $false
        
            if ($result) {
                $script:StatusText.Text = "$($script:SelectedToolId) installed successfully"
                Write-OperationLog "$($script:SelectedToolId) installed successfully" -Level "SUCCESS"
            }
            else {
                $script:StatusText.Text = "Installation failed"
                Write-OperationLog "Installation of $($script:SelectedToolId) failed" -Level "ERROR"
            }
        
            Refresh-ToolsList
            Refresh-InstalledList
            Show-ToolDetails -ToolId $script:SelectedToolId
        }
    })

# Update button
$script:UpdateButton.Add_Click({
        if ($script:SelectedToolId) {
            Write-OperationLog "Starting update of $($script:SelectedToolId)..." -Level "PROGRESS"
            $script:StatusText.Text = "Updating $($script:SelectedToolId)..."
            $script:ProgressBar.Visibility = "Visible"
            $script:ProgressBar.IsIndeterminate = $true
        
            $result = Update-Tool -ToolId $script:SelectedToolId
        
            $script:ProgressBar.Visibility = "Collapsed"
            $script:ProgressBar.IsIndeterminate = $false
        
            if ($result) {
                Write-OperationLog "$($script:SelectedToolId) updated successfully" -Level "SUCCESS"
            }
            else {
                Write-OperationLog "Update of $($script:SelectedToolId) failed" -Level "ERROR"
            }
        
            Refresh-ToolsList
            Refresh-InstalledList
            Show-ToolDetails -ToolId $script:SelectedToolId
        }
    })

# Uninstall button
$script:UninstallButton.Add_Click({
        if ($script:SelectedToolId) {
            Write-OperationLog "Uninstalling $($script:SelectedToolId)..." -Level "PROGRESS"
            $result = Uninstall-Tool -ToolId $script:SelectedToolId
            if ($result) {
                $script:StatusText.Text = "$($script:SelectedToolId) uninstalled"
                Write-OperationLog "$($script:SelectedToolId) uninstalled successfully" -Level "SUCCESS"
                Refresh-ToolsList
                Refresh-InstalledList
                Show-ToolDetails -ToolId $script:SelectedToolId
            }
            else {
                Write-OperationLog "Uninstallation cancelled or failed" -Level "WARNING"
            }
        }
    })

# Open folder button
$script:OpenFolderButton.Add_Click({
        if ($script:SelectedToolId) {
            $installedData = Get-InstalledTools
            $tool = $installedData.tools | Where-Object { $_.id -eq $script:SelectedToolId }
            if ($tool -and (Test-Path $tool.install_path)) {
                Start-Process explorer.exe $tool.install_path
            }
        }
    })

# Check updates button
$script:CheckUpdatesButton.Add_Click({
        $script:StatusText.Text = "Checking for updates..."
        $updates = Check-ToolUpdates
        $script:UpdatesListBox.Items.Clear()
    
        foreach ($update in $updates) {
            $item = New-Object System.Windows.Controls.ListBoxItem
            $item.Tag = $update.ToolId
            $item.Content = "$($update.ToolName): $($update.CurrentVersion) → $($update.LatestVersion)"
            $item.Foreground = [System.Windows.Media.Brushes]::White
            $script:UpdatesListBox.Items.Add($item) | Out-Null
        }
    
        $script:LastCheckText.Text = "Last checked: $(Get-Date -Format 'HH:mm')"
        $script:StatusText.Text = "Found $($updates.Count) updates"
        $script:UpdatesTab.Header = if ($updates.Count -gt 0) { "Updates ($($updates.Count))" } else { "Updates" }
    })

# Update all button
$script:UpdateAllButton.Add_Click({
        $updates = Check-ToolUpdates
        foreach ($update in $updates) {
            $script:StatusText.Text = "Updating $($update.ToolName)..."
            Update-Tool -ToolId $update.ToolId
        }
        $script:StatusText.Text = "All updates complete"
        Refresh-ToolsList
        Refresh-InstalledList
        $script:UpdatesListBox.Items.Clear()
        $script:UpdatesTab.Header = "Updates"
    })

# Save settings
$script:SaveSettingsButton.Add_Click({
        $script:Settings.InstallDirectory = $script:InstallDirTextBox.Text
        $script:Settings.ManifestUrl = $script:ManifestUrlTextBox.Text
        $script:Settings.PathScope = if ($script:UserPathRadio.IsChecked) { "User" } else { "Machine" }
        $script:Settings.CheckUpdatesOnStartup = $script:CheckUpdatesStartupCheckBox.IsChecked
        $script:Settings.KeepDownloads = $script:KeepDownloadsCheckBox.IsChecked
        $script:Settings.EnableLogging = $script:EnableLoggingCheckBox.IsChecked
        $script:Settings.VerifyChecksums = $script:VerifyChecksumsCheckBox.IsChecked
    
        if (Save-Settings) {
            [System.Windows.MessageBox]::Show("Settings saved successfully!", "Settings", "OK", "Information")
        }
    })

# Reset settings
$script:ResetSettingsButton.Add_Click({
        $script:Settings = $script:DefaultSettings.Clone()
        Save-Settings
        Load-SettingsUI
        [System.Windows.MessageBox]::Show("Settings reset to defaults", "Settings", "OK", "Information")
    })

# Clear cache
$script:ClearCacheButton.Add_Click({
        Remove-Item "$script:CacheDir\*" -Force -ErrorAction SilentlyContinue
        Remove-Item "$script:DownloadDir\*" -Force -ErrorAction SilentlyContinue
        Write-OperationLog "Cache and downloads cleared" -Level "SUCCESS"
        [System.Windows.MessageBox]::Show("Cache cleared", "Cache", "OK", "Information")
    })

# Clear log button
$script:ClearLogButton.Add_Click({
        $script:LogEntries.Clear()
        $script:LogCountText.Text = "0 entries"
    })

# Export log button
$script:ExportLogButton.Add_Click({
        $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
        $saveDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
        $saveDialog.FileName = "operations-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        $saveDialog.Title = "Export Operations Log"
        
        if ($saveDialog.ShowDialog() -eq $true) {
            $logContent = $script:LogEntries | ForEach-Object {
                "$($_.Timestamp) $($_.Level) $($_.Message)"
            }
            $logContent | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
            Write-OperationLog "Log exported to: $($saveDialog.FileName)" -Level "SUCCESS"
            [System.Windows.MessageBox]::Show("Log exported successfully!", "Export", "OK", "Information")
        }
    })

# ============================================================================
# INITIAL LOAD
# ============================================================================

# Load settings into UI
Load-SettingsUI

# Populate About tab
$script:AboutVersionText.Text = "Version $script:AppVersion"
$script:AboutPSVersion.Text = $PSVersionTable.PSVersion.ToString()
$script:AboutWinVersion.Text = [Environment]::OSVersion.VersionString
$script:AboutInstallPath.Text = $script:BaseDir

# Add startup log message
Write-OperationLog "Android Pentesting Toolkit Manager v$script:AppVersion started" -Level "INFO"
Write-OperationLog "Install directory: $script:BaseDir" -Level "INFO"

# Load tools list
Refresh-ToolsList
Refresh-InstalledList

# Check updates on startup if enabled
if ($script:Settings.CheckUpdatesOnStartup) {
    $updates = Check-ToolUpdates
    if ($updates.Count -gt 0) {
        $script:UpdatesTab.Header = "Updates ($($updates.Count))"
    }
}

# Show window
$script:Window.ShowDialog() | Out-Null
