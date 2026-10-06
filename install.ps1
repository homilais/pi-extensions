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
    
    # Clean up old renamed files listed in package.json ("oldNames" field)
    # e.g. skill-discover was previously named skill-search
    $pkgPath = Join-Path $extPath "package.json"
    if (Test-Path $pkgPath) {
        $pkg = Get-Content $pkgPath -Raw | ConvertFrom-Json
        $oldNames = $pkg.oldNames
        if ($oldNames) {
            foreach ($oldName in $oldNames) {
                $oldFile = Join-Path $PiExtensionsDir "$oldName.ts"
                if (Test-Path $oldFile) {
                    Remove-Item -Path $oldFile -Force
                    Write-Info "  [CLEANUP] Removed old file: $oldName.ts"
                }
            }
        }
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

# Keyboard navigation helper
# Uses $host.UI.RawUI.CursorPosition for reliable cursor repositioning
function Select-FromMenu {
    param(
        [string[]]$Items,
        [string]$Prompt = "Use Up/Down arrows to navigate, Enter to confirm, Esc to cancel"
    )
    
    if ($Items.Count -eq 0) {
        return -1
    }
    
    $selectedIndex = 0
    $bufferWidth = $host.UI.RawUI.BufferSize.Width
    
    # Hide cursor
    [System.Console]::CursorVisible = $false
    
    # Record the top position of the menu (before any items are written)
    $menuTop = $host.UI.RawUI.CursorPosition.Y
    
    # Render menu items at the saved position
    # On re-render, repositions cursor to menuTop and overwrites all lines
    function script:Render-MenuItems {
        param($idx)
        $pos = $host.UI.RawUI.CursorPosition
        $pos.X = 0
        $pos.Y = $script:menuTop
        $host.UI.RawUI.CursorPosition = $pos
        
        for ($i = 0; $i -lt $script:menuItems.Count; $i++) {
            $prefix = if ($i -eq $idx) { "  >>> " } else { "      " }
            $line = "$prefix$($script:menuItems[$i])"
            # PadRight overwrites leftover characters from previous render
            Write-Host $line.PadRight($script:bufferWidth - 1)
        }
    }
    
    # Store variables in script scope so Render-MenuItems can access them
    $script:menuItems = $Items
    $script:menuTop = $menuTop
    $script:bufferWidth = $bufferWidth
    
    # Initial render
    Render-MenuItems $selectedIndex
    
    # Print prompt below the menu
    Write-Host ""
    Write-Host $Prompt
    
    do {
        # Use [System.Console]::ReadKey which returns ConsoleKeyInfo with .Key property
        # $host.UI.RawUI.ReadKey returns KeyInfo which only has VirtualKeyCode (no .Key)
        $key = [System.Console]::ReadKey($true)
        
        switch ($key.Key) {
            "UpArrow" {
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                    Render-MenuItems $selectedIndex
                }
            }
            "DownArrow" {
                if ($selectedIndex -lt $Items.Count - 1) {
                    $selectedIndex++
                    Render-MenuItems $selectedIndex
                }
            }
            "Enter" {
                [System.Console]::CursorVisible = $true
                Write-Host ""
                return $selectedIndex
            }
            "Escape" {
                [System.Console]::CursorVisible = $true
                Write-Host ""
                return -1
            }
            "A" {
                [System.Console]::CursorVisible = $true
                Write-Host ""
                return 999
            }
            "R" {
                [System.Console]::CursorVisible = $true
                Write-Host ""
                return 998
            }
            "Q" {
                [System.Console]::CursorVisible = $true
                Write-Host ""
                return -2
            }
        }
    } while ($true)
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
    
    # Build menu items: extensions + action items (all navigable)
    $extCount = $extensions.Count
    $menuItems = @()
    foreach ($extName in $extensions) {
        $desc = Get-ExtensionDescription $extName
        if ($desc) {
            $menuItems += "$extName - $desc"
        }
        else {
            $menuItems += $extName
        }
    }
    # Add action items to the navigable menu
    $menuItems += "[A] Install All"
    $menuItems += "[R] Remove Mode"
    $menuItems += "[Q] Quit"
    
    Write-Host "  Use Up/Down arrows to navigate, Enter to select"
    Write-Host ""
    
    # Select-FromMenu handles display + keyboard navigation
    $choice = Select-FromMenu -Items $menuItems -Prompt "Press Enter to select, or A/R/Q as shortcut"
    
    Write-Host ("-" * 50)
    
    # Handle choice: index-based (from Enter) or special codes (from A/R/Q/Esc keys)
    $installAllIdx = $extCount        # [A] Install All
    $removeModeIdx = $extCount + 1    # [R] Remove Mode
    $quitIdx = $extCount + 2          # [Q] Quit
    
    if ($choice -eq -1) {
        Write-Info "Cancelled"
        return
    }
    elseif ($choice -eq -2 -or $choice -eq $quitIdx) {
        Write-Info "Exiting..."
        return
    }
    elseif ($choice -eq 999 -or $choice -eq $installAllIdx) {
        Write-Info "Installing all extensions..."
        Install-AllExtensions
        return
    }
    elseif ($choice -eq 998 -or $choice -eq $removeModeIdx) {
        # Remove mode: show extensions only for selection
        $removeMenuItems = @()
        foreach ($extName in $extensions) {
            $desc = Get-ExtensionDescription $extName
            if ($desc) {
                $removeMenuItems += "$extName - $desc"
            }
            else {
                $removeMenuItems += $extName
            }
        }
        Write-Info "Remove Mode - select extension to remove:"
        Write-Host ""
        $removeChoice = Select-FromMenu -Items $removeMenuItems -Prompt "Press Enter to remove, or Esc to cancel"
        Write-Host ("-" * 50)
        if ($removeChoice -ge 0 -and $removeChoice -lt $extCount) {
            Remove-Extension $extensions[$removeChoice]
        }
        else {
            Write-Info "No extension selected for removal"
        }
        return
    }
    elseif ($choice -ge 0 -and $choice -lt $extCount) {
        # Install selected extension
        Install-Extension $extensions[$choice]
    }
    else {
        Write-Error2 "Invalid selection"
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
