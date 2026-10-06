# Pi Extensions

[English](README.md) | [中文](README.zh-CN.md)

A collection of Pi coding agent extensions. Each extension is isolated in its own subdirectory.

## Project Structure

```
pi-skills/
├── extensions/
│   ├── skill-discover/
│   │   ├── skill-discover.ts      # Extension source code
│   │   ├── package.json          # Extension metadata
│   │   └── README.md             # Extension documentation
│   └── ... (more extensions)
├── install.ps1                   # Windows installer script
├── install.sh                    # Linux/Mac installer script
├── package.json                  # Project metadata
└── README.md                     # This file
```

## Available Extensions

| Extension | Description |
|-----------|-------------|
| `skill-discover` | Skill discovery with `@skill:` inline autocomplete and auto filepath injection (optional `discoverSkill` tool) |

## Installation

### Interactive Mode (Recommended)

```powershell
# Launch interactive menu to select extensions
.\install.ps1 -Interactive
```

### Install Specific Extensions

```powershell
# Install skill-discover
.\install.ps1 -Install skill-discover

# Install multiple extensions
.\install.ps1 -Install skill-discover another-extension
```

### Install All Extensions

```powershell
.\install.ps1 -InstallAll
```

### Using npm Scripts

```bash
npm run list                # List available extensions
npm run install             # Install all extensions
npm run install:skill-discover  # Install specific extension
npm run interactive         # Interactive mode
```

### Linux/Mac (Bash)

```bash
chmod +x install.sh
./install.sh --list              # List available extensions
./install.sh --install-all       # Install all extensions
./install.sh skill-discover      # Install specific extension
```

## Removing Extensions

```powershell
.\install.ps1 -Remove skill-discover
```

Extensions are installed to: `~/.pi/agent/extensions/`

## Adding New Extensions

1. Create a new directory under `extensions/`:
   ```bash
   mkdir extensions/my-extension
   ```

2. Add extension source file (`.ts` or `.js`):
   ```bash
   nano extensions/my-extension/my-extension.ts
   ```

3. Add package.json with metadata:
   ```json
   {
     "name": "pi-my-extension",
     "version": "1.0.0",
     "description": "Description of your extension",
     "type": "module",
     "main": "my-extension.ts",
     "keywords": ["pi", "extension"],
     "license": "MIT"
   }
   ```

4. Add README.md with documentation.

5. Update this README's "Available Extensions" table.

## Extension Development

Each extension should:
- Export a default factory function
- Use `pi.registerTool()` for LLM tools
- Use `pi.registerCommand()` for commands
- Use `pi.on("session_start")` for initialization
- Be self-contained in its directory

Example structure:

```typescript
// my-extension.ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
  pi.registerTool({
    name: "myTool",
    description: "What this tool does",
    parameters: { ... },
    execute: async () => { ... }
  });
}
```

## Requirements

- Pi coding agent v0.99.x+
- Node.js v22+
- PowerShell (Windows) or Bash (Linux/Mac)

## License

MIT
