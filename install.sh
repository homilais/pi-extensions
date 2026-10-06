#!/bin/bash
# Pi Extensions Installer
# Install selected extensions to ~/.pi/agent/extensions/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Pi extensions directory
PI_EXTENSIONS_DIR="$HOME/.pi/agent/extensions"

# Project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSIONS_DIR="$PROJECT_DIR/extensions"

# Get list of available extensions
get_available_extensions() {
    find "$EXTENSIONS_DIR" -name "package.json" -not -path "*/node_modules/*" 2>/dev/null | \
    xargs -I {} dirname {} | \
    xargs -I {} basename {} | \
    sort
}

# Install a single extension
install_extension() {
    local ext_name="$1"
    local ext_path="$EXTENSIONS_DIR/$ext_name"
    
    if [ ! -d "$ext_path" ]; then
        echo -e "${RED}Error: Extension '$ext_name' not found${NC}"
        return 1
    fi
    
    # Find all .ts and .js files in the extension directory
    local files=()
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$ext_path" -name "*.ts" -o -name "*.js" -print0)
    
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${RED}Error: No extension files found in '$ext_name'${NC}"
        return 1
    fi
    
    # Create Pi extensions directory if not exists
    mkdir -p "$PI_EXTENSIONS_DIR"
    
    # Copy files to Pi extensions directory
    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        cp "$file" "$PI_EXTENSIONS_DIR/$filename"
        echo -e "  ${GREEN}✓${NC} Installed $filename"
    done
    
    # Clean up old renamed files listed in package.json ("oldNames" field)
    local pkg_json="$ext_path/package.json"
    if [ -f "$pkg_json" ]; then
        # Extract oldNames array from package.json using grep+sed
        local old_names_str=$(grep -o '"oldNames"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$pkg_json" 2>/dev/null | \
            sed 's/.*\[//;s/\]//;s/"//g' 2>/dev/null)
        if [ -n "$old_names_str" ]; then
            IFS=',' read -ra old_names <<< "$old_names_str"
            for old_name in "${old_names[@]}"; do
                old_name=$(echo "$old_name" | xargs)  # trim whitespace
                local old_file="$PI_EXTENSIONS_DIR/$old_name.ts"
                if [ -f "$old_file" ]; then
                    rm "$old_file"
                    echo -e "  ${YELLOW}[CLEANUP] Removed old file: $old_name.ts${NC}"
                fi
            done
        fi
    fi
    
    echo -e "${GREEN}✓ Extension '$ext_name' installed successfully${NC}"
}

# Show usage
show_usage() {
    echo "Usage: $0 [options] [extension...]"
    echo ""
    echo "Install Pi extensions to ~/.pi/agent/extensions/"
    echo ""
    echo "Options:"
    echo "  -l, --list          List available extensions"
    echo "  -a, --all           Install all extensions"
    echo "  -r, --remove        Remove installed extensions"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --list                    # List available extensions"
    echo "  $0 --all                     # Install all extensions"
    echo "  $0 skill-discover              # Install specific extension"
    echo "  $0 -r skill-discover           # Remove specific extension"
    echo "  $0 skill-discover pdf-tools    # Install multiple extensions"
}

# Show available extensions
list_extensions() {
    echo -e "${BLUE}Available extensions:${NC}"
    echo ""
    
    local extensions=($(get_available_extensions))
    if [ ${#extensions[@]} -eq 0 ]; then
        echo -e "${YELLOW}No extensions found in '$EXTENSIONS_DIR'${NC}"
        return
    fi
    
    for ext in "${extensions[@]}"; do
        local ext_path="$EXTENSIONS_DIR/$ext"
        local package_json="$ext_path/package.json"
        local description=""
        
        # Try to get description from package.json
        if [ -f "$package_json" ]; then
            description=$(grep -o '"description"[[:space:]]*:[[:space:]]*"[^"]*"' "$package_json" | \
                        sed 's/.*:[[:space:]]*"//;s/"$//' | head -1)
        fi
        
        if [ -n "$description" ]; then
            echo -e "  ${GREEN}•${NC} $ext - $description"
        else
            echo -e "  ${GREEN}•${NC} $ext"
        fi
    done
}

# Remove an extension
remove_extension() {
    local ext_name="$1"
    local ext_path="$EXTENSIONS_DIR/$ext_name"
    
    if [ ! -d "$ext_path" ]; then
        echo -e "${RED}Error: Extension '$ext_name' not found${NC}"
        return 1
    fi
    
    # Find all .ts and .js files and remove them from Pi extensions directory
    local removed=0
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        if [ -f "$PI_EXTENSIONS_DIR/$filename" ]; then
            rm "$PI_EXTENSIONS_DIR/$filename"
            echo -e "  ${YELLOW}✗${NC} Removed $filename"
            ((removed++))
        fi
    done < <(find "$ext_path" -name "*.ts" -o -name "*.js" -print0)
    
    if [ $removed -eq 0 ]; then
        echo -e "${YELLOW}No installed files found for '$ext_name'${NC}"
    else
        echo -e "${GREEN}✓ Extension '$ext_name' removed successfully${NC}"
    fi
}

# Main script logic
main() {
    local install_all=false
    local remove_mode=false
    local extensions=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list)
                list_extensions
                exit 0
                ;;
            -a|--all)
                install_all=true
                shift
                ;;
            -r|--remove)
                remove_mode=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                show_usage
                exit 1
                ;;
            *)
                extensions+=("$1")
                shift
                ;;
        esac
    done
    
    # Handle list mode
    if [ ${#extensions[@]} -eq 0 ] && [ "$install_all" = false ]; then
        echo ""
        list_extensions
        echo ""
        echo -e "Run '${GREEN}$0 --help${NC}' for usage information"
        exit 0
    fi
    
    # Install mode
    if [ "$remove_mode" = false ]; then
        echo -e "${BLUE}Installing Pi extensions...${NC}"
        echo ""
        
        # Collect extensions to install
        local to_install=()
        if [ "$install_all" = true ]; then
            to_install=($(get_available_extensions))
            echo -e "${YELLOW}Installing all ${#to_install[@]} extensions...${NC}"
            echo ""
        elif [ ${#extensions[@]} -gt 0 ]; then
            to_install=("${extensions[@]}")
        fi
        
        if [ ${#to_install[@]} -eq 0 ]; then
            echo -e "${RED}Error: No extensions specified${NC}"
            exit 1
        fi
        
        # Install each extension
        local success=0
        local failed=0
        for ext in "${to_install[@]}"; do
            if install_extension "$ext"; then
                ((success++))
            else
                ((failed++))
            fi
            echo ""
        done
        
        echo -e "${BLUE}Installation complete: ${GREEN}$success succeeded${NC}"
        if [ $failed -gt 0 ]; then
            echo -e ", ${RED}$failed failed${NC}"
        fi
        echo ""
        echo -e "Extensions installed to: ${YELLOW}$PI_EXTENSIONS_DIR${NC}"
    # Remove mode
    else
        echo -e "${BLUE}Removing Pi extensions...${NC}"
        echo ""
        
        if [ ${#extensions[@]} -eq 0 ]; then
            echo -e "${RED}Error: No extensions specified for removal${NC}"
            exit 1
        fi
        
        local success=0
        local failed=0
        for ext in "${extensions[@]}"; do
            if remove_extension "$ext"; then
                ((success++))
            else
                ((failed++))
            fi
            echo ""
        done
        
        echo -e "${BLUE}Removal complete: ${GREEN}$success succeeded${NC}"
        if [ $failed -gt 0 ]; then
            echo -e ", ${RED}$failed failed${NC}"
        fi
    fi
}

main "$@"
