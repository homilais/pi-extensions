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

# Keyboard navigation helper
function Select-FromMenu {
    param(
        [string[]]$Items,
        [string]$Prompt = "Select (use arrow keys, Enter to confirm, Esc to cancel)"
    )
    
    if ($Items.Count -eq 0) {
        return -1
    }
    
    $selectedIndex = 0
    
    # Hide cursor using Console property
    $originalCursorVisible = [System.Console]::CursorVisible
    [System.Console]::CursorVisible = $false
    
    # ESC character (ASCII 27) - required for ANSI escape sequences
    $ESC = [char]27
    
    # ANSI escape codes for terminal control
    $ansiHideCursor = "$ESC[?25l"
    $ansiShowCursor = "$ESC[?25h"
    $ansiClearLine = "$ESC[2K"
    $ansiMoveUp = { param($n) "$ESC[${n}A" }
    $ansiMoveDown = { param($n) "$ESC[${n}B" }
    
    # Render menu function
    $renderMenu = {
        param($idx)
        # Move cursor up to render position
        $moveUpLines = $Items.Count + 2
        if ($moveUpLines -gt 1) {
            Write-Host -NoNewline (& $ansiMoveUp $moveUpLines)
        }
        
        # Clear and redraw each line
        for ($i = 0; $i -lt $Items.Count; $i++) {
            Write-Host -NoNewline $ansiClearLine
            if ($i -eq $idx) {
                Write-Host "  >>> $($Items[$i])"
            }
            else {
                Write-Host "      $($Items[$i])"
            }
        }
        
        # Move cursor back to input line
        $moveDownLines = $Items.Count + 1
        if ($moveDownLines -gt 0) {
            Write-Host -NoNewline (& $ansiMoveDown $moveDownLines)
        }
    }
    
    # Initial render
    & $renderMenu $selectedIndex
    
    Write-Host ""
    Write-Host $Prompt -NoNewline
    Write-Host ""
    
    do {
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.Key) {
            "UpArrow" {
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                    & $renderMenu $selectedIndex
                }
            }
            "DownArrow" {
                if ($selectedIndex -lt $Items.Count - 1) {
                    $selectedIndex++
                    & $renderMenu $selectedIndex
                }
            }
            "Enter" {
                # Confirm selection
                # Clear prompt line
                Write-Host -NoNewline $ansiClearLine
                Write-Host ""
                return $selectedIndex
            }
            "Escape" {
                # Cancel
                Write-Host -NoNewline $ansiClearLine
                Write-Host ""
                return -1
            }
            "A" {
                # Install All
                Write-Host -NoNewline $ansiClearLine
                Write-Host ""
                return 999
            }
            "R" {
                # Remove Mode
                Write-Host -NoNewline $ansiClearLine
                Write-Host ""
                return 998
            }
            "Q" {
                # Quit
                Write-Host -NoNewline $ansiClearLine
                Write-Host ""
                return -2
            }
        }
    } while ($true)
    
    return -1
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
    
    # Build menu items with descriptions
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
    $menuItems += "---"
    $menuItems += "[A] Install All"
    $menuItems += "[R] Remove Mode"
    $menuItems += "[Q] Quit"
    
    Write-Host ""
    Write-Host "  Use arrow keys to navigate, Enter to select"
    Write-Host "  Press A for Install All, R for Remove, Q to Quit"
    Write-Host ""
    
    # Show numbered menu
    $num = 1
    foreach ($item in $menuItems) {
        if ($item -eq "---") {
            Write-Host ("-" * 50)
        }
        else {
            Write-Host "  [$num] $item"
            $num++
        }
    }
    Write-Host ("-" * 50)
    Write-Host ""
    
    # Use keyboard navigation
    $choice = Select-FromMenu -Items $menuItems -Prompt "Select an option"
    
    # Restore cursor
    [System.Console]::CursorVisible = $true
    Write-Host ""
    
    # Handle choice
    if ($choice -eq -1) {
        Write-Info "Cancelled"
        return
    }
    elseif ($choice -eq -2) {
        Write-Info "Exiting..."
        return
    }
    elseif ($choice -eq 999) {
        Write-Info "Installing all extensions..."
        Install-AllExtensions
        return
    }
    elseif ($choice -eq 998) {
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
    elseif ($choice -ge 0 -and $choice -lt $extensions.Count) {
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
