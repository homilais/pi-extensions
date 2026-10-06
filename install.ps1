<#
.SYNOPSIS
    Pi Extensions Installer - Install selected extensions to Pi agent directory
    
.DESCRIPTION
    This script installs Pi coding agent extensions to ~/.pi/agent/extensions/
    Supports listing, installing, and removing extensions with interactive selection.

.EXAMPLE
    .\install.ps1 -List
    Lists all available extensions

.EXAMPLE
    .\install.ps1 -Install skill-search
    Installs the skill-search extension

.EXAMPLE
    .\install.ps1 -InstallAll
    Installs all available extensions

.EXAMPLE
    .\install.ps1 -Remove skill-search
    Removes the skill-search extension

.EXAMPLE
    .\install.ps1 -Interactive
    Launches interactive selection mode
#>

param(
    [switch]$List,
    [switch]$InstallAll,
    [switch]$Interactive,
    [string[]]$Install,
    [string[]]$Remove,
    [string]$PiExtensionsDir = "$HOME\.pi\agent\extensions"
)

$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot
$ExtensionsDir = Join-Path $ProjectDir "extensions"

# Color output functions
function Write-Colored {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::White)
    # Simple approach without changing foreground color
    Write-Host $Message
}

function Write-Info { param([string]$Message) Write-Host $Message }
function Write-Success { param([string]$Message) Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Host $Message }
function Write-Error2 { param([string]$Message) Write-Host $Message }

# Get available extensions
function Get-AvailableExtensions {
    $extensions = @()
    if (Test-Path $ExtensionsDir) {
        $extensionFolders = Get-ChildItem -Path $ExtensionsDir -Directory
        foreach ($folder in $extensionFolders) {
            if (Test-Path (Join-Path $folder.FullName "package.json")) {
                $extensions += $folder.Name
            }
        }
    }
    # Ensure we always return an array, even with single element
    return @($extensions)
}

# Get extension description from package.json
function Get-ExtensionDescription {
    param([string]$ExtensionName)
    $packageJson = Join-Path (Join-Path $ExtensionsDir $ExtensionName) "package.json"
    if (Test-Path $packageJson) {
        try {
            $package = Get-Content $packageJson -Raw | ConvertFrom-Json
            return $package.description
        }
        catch {
            return $null
        }
    }
    return $null
}

# Install a single extension
function Install-Extension {
    param([string]$ExtensionName)
    
    $extPath = Join-Path $ExtensionsDir $ExtensionName
    if (-not (Test-Path $extPath)) {
        Write-Error2 "Error: Extension '$ExtensionName' not found"
        return $false
    }
    
    # Find all .ts and .js files
    $files = Get-ChildItem -Path $extPath -Include "*.ts", "*.js" -Recurse -File
    
    if ($files.Count -eq 0) {
        Write-Error2 "Error: No extension files found in '$ExtensionName'"
        return $false
    }
    
    # Create Pi extensions directory if not exists
    if (-not (Test-Path $PiExtensionsDir)) {
        New-Item -ItemType Directory -Path $PiExtensionsDir -Force | Out-Null
    }
    
    # Copy files
    $installed = 0
    foreach ($file in $files) {
        $destPath = Join-Path $PiExtensionsDir $file.Name
        Copy-Item -Path $file.FullName -Destination $destPath -Force
        Write-Success "  [OK] Installed $($file.Name)"
        $installed++
    }
    
    Write-Success "[OK] Extension '$ExtensionName' installed ($installed files)"
    return $true
}

# Remove a single extension
function Remove-Extension {
    param([string]$ExtensionName)
    
    $extPath = Join-Path $ExtensionsDir $ExtensionName
    if (-not (Test-Path $extPath)) {
        Write-Error2 "Error: Extension '$ExtensionName' not found"
        return $false
    }
    
    # Find all .ts and .js files and remove from Pi extensions directory
    $files = Get-ChildItem -Path $extPath -Include "*.ts", "*.js" -Recurse -File
    $removed = 0
    
    foreach ($file in $files) {
        $destPath = Join-Path $PiExtensionsDir $file.Name
        if (Test-Path $destPath) {
            Remove-Item -Path $destPath -Force
            Write-Warn "  [REMOVED] $($file.Name)"
            $removed++
        }
    }
    
    if ($removed -eq 0) {
        Write-Warn "No installed files found for '$ExtensionName'"
    }
    else {
        Write-Success "[OK] Extension '$ExtensionName' removed ($removed files)"
    }
    
    return $true
}

# List extensions with interactive selection
function Show-InteractiveMenu {
    $extensions = @(Get-AvailableExtensions)
    
    if ($extensions.Count -eq 0) {
        Write-Warn "No extensions found in '$ExtensionsDir'"
        return
    }
    
    Write-Info "`nAvailable Extensions:"
    Write-Host ("-" * 50)
    
    $num = 1
    foreach ($extName in $extensions) {
        $desc = Get-ExtensionDescription $extName
        
        if ($desc) {
            Write-Host "  [$num] $extName - $desc"
        }
        else {
            Write-Host "  [$num] $extName"
        }
        $num++
    }
    
    Write-Host ("-" * 50)
    Write-Host "  [A] Install All"
    Write-Host "  [R] Remove Mode"
    Write-Host "  [Q] Quit"
    Write-Host ""
    
    $choice = Read-Host "Select extension (number), A for all, R for remove, or Q to quit"
    
    switch ($choice.ToUpper()) {
        "Q" {
            Write-Info "Exiting..."
            return
        }
        "A" {
            Write-Info "Installing all extensions..."
            Install-AllExtensions
            return
        }
        "R" {
            Write-Info "Remove Mode"
            $removeChoice = Read-Host "Enter extension number to remove (or Q to cancel)"
            if ($removeChoice -eq "Q") { return }
            if ($removeChoice -match "^[0-9]+$") {
                $extNum = [int]$removeChoice - 1
                if ($extNum -ge 0 -and $extNum -lt $extensions.Count) {
                    Remove-Extension $extensions[$extNum]
                }
            }
            return
        }
        Default {
            if ($choice -match "^[0-9]+$") {
                $extNum = [int]$choice - 1
                if ($extNum -ge 0 -and $extNum -lt $extensions.Count) {
                    Install-Extension $extensions[$extNum]
                }
                else {
                    Write-Error2 "Invalid selection"
                }
            }
            else {
                Write-Error2 "Invalid selection"
            }
        }
    }
}

# Install all extensions
function Install-AllExtensions {
    $extensions = @(Get-AvailableExtensions)
    
    if ($extensions.Count -eq 0) {
        Write-Warn "No extensions available to install"
        return
    }
    
    Write-Info "Installing all $($extensions.Count) extensions..."
    Write-Host ""
    
    $success = 0
    $failed = 0
    
    foreach ($ext in $extensions) {
        if (Install-Extension $ext) {
            $success++
        }
        else {
            $failed++
        }
        Write-Host ""
    }
    
    Write-Info "Installation complete: $success succeeded"
    if ($failed -gt 0) {
        Write-Error2 ", $failed failed"
    }
    Write-Info "Extensions installed to: $PiExtensionsDir"
}

# Main execution
function Main {
    # Show list
    if ($List) {
        $extensions = @(Get-AvailableExtensions)
        if ($extensions.Count -eq 0) {
            Write-Warn "No extensions found"
            return
        }
        
        Write-Info "`nAvailable Extensions:"
        Write-Host ("-" * 50)
        foreach ($ext in $extensions) {
            $desc = Get-ExtensionDescription $ext
            if ($desc) {
                Write-Host "  * $ext - $desc"
            }
            else {
                Write-Host "  * $ext"
            }
        }
        Write-Host ("-" * 50)
        return
    }
    
    # Install all
    if ($InstallAll) {
        Install-AllExtensions
        return
    }
    
    # Interactive mode
    if ($Interactive) {
        Show-InteractiveMenu
        return
    }
    
    # Install specific extensions
    if ($Install.Count -gt 0) {
        Write-Info "Installing extensions: $($Install -join ', ')"
        Write-Host ""
        
        $success = 0
        $failed = 0
        foreach ($ext in $Install) {
            if (Install-Extension $ext) {
                $success++
            }
            else {
                $failed++
            }
            Write-Host ""
        }
        
        Write-Info "Installation complete: $success succeeded"
        if ($failed -gt 0) {
            Write-Error2 ", $failed failed"
        }
        return
    }
    
    # Remove specific extensions
    if ($Remove.Count -gt 0) {
        Write-Info "Removing extensions: $($Remove -join ', ')"
        Write-Host ""
        
        $success = 0
        $failed = 0
        foreach ($ext in $Remove) {
            if (Remove-Extension $ext) {
                $success++
            }
            else {
                $failed++
            }
            Write-Host ""
        }
        
        Write-Info "Removal complete: $success succeeded"
        if ($failed -gt 0) {
            Write-Error2 ", $failed failed"
        }
        return
    }
    
    # Show help
    Write-Info "Pi Extensions Installer"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\install.ps1 -List                    List available extensions"
    Write-Host "  .\install.ps1 -Install <name>          Install specific extension"
    Write-Host "  .\install.ps1 -Install <name1> <name2> Install multiple extensions"
    Write-Host "  .\install.ps1 -InstallAll              Install all extensions"
    Write-Host "  .\install.ps1 -Remove <name>           Remove specific extension"
    Write-Host "  .\install.ps1 -Interactive             Interactive selection mode"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\install.ps1 -List"
    Write-Host "  .\install.ps1 -Install skill-discover"
    Write-Host "  .\install.ps1 -InstallAll"
    Write-Host "  .\install.ps1 -Interactive"
}

Main
