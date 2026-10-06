# Pi 扩展合集

[English](README.md) | [中文](README.zh-CN.md)

Pi coding agent 扩展合集。每个扩展独立存放于自己的子目录中。

## 项目结构

```
pi-skills/
├── extensions/
│   ├── skill-discover/
│   │   ├── skill-discover.ts      # 扩展源码
│   │   ├── package.json          # 扩展元数据
│   │   └── README.md             # 扩展文档
│   └── ... (更多扩展)
├── install.ps1                   # Windows 安装脚本
├── install.sh                    # Linux/Mac 安装脚本
├── package.json                  # 项目元数据
└── README.md                     # 项目文档
```

## 可用扩展

| 扩展 | 说明 |
|------|------|
| `skill-discover` | Skill 发现，支持 `@skill:` 内联自动补全和文件路径自动注入（可选 `discoverSkill` 工具） |

## 安装

### 交互式模式（推荐）

```powershell
# 启动交互式菜单选择扩展
.\install.ps1 -Interactive
```

### 安装指定扩展

```powershell
# 安装 skill-discover
.\install.ps1 -Install skill-discover

# 安装多个扩展
.\install.ps1 -Install skill-discover another-extension
```

### 安装所有扩展

```powershell
.\install.ps1 -InstallAll
```

### 使用 npm 脚本

```bash
npm run list                # 列出可用扩展
npm run install             # 安装所有扩展
npm run install:skill-discover  # 安装指定扩展
npm run interactive         # 交互式模式
```

### Linux/Mac (Bash)

```bash
chmod +x install.sh
./install.sh --list              # 列出可用扩展
./install.sh --install-all       # 安装所有扩展
./install.sh skill-discover      # 安装指定扩展
```

## 移除扩展

```powershell
.\install.ps1 -Remove skill-discover
```

扩展安装目录：`~/.pi/agent/extensions/`

## 添加新扩展

1. 在 `extensions/` 下创建新目录：
   ```bash
   mkdir extensions/my-extension
   ```

2. 添加扩展源码文件（`.ts` 或 `.js`）：
   ```bash
   nano extensions/my-extension/my-extension.ts
   ```

3. 添加包含元数据的 package.json：
   ```json
   {
     "name": "pi-my-extension",
     "version": "1.0.0",
     "description": "扩展描述",
     "type": "module",
     "main": "my-extension.ts",
     "keywords": ["pi", "extension"],
     "license": "MIT"
   }
   ```

4. 添加包含文档的 README.md。

5. 更新此 README 的"可用扩展"表格。

## 扩展开发

每个扩展应该：
- 导出默认的工厂函数
- 使用 `pi.registerTool()` 注册 LLM 工具
- 使用 `pi.registerCommand()` 注册命令
- 使用 `pi.on("session_start")` 进行初始化
- 在目录内自包含

示例结构：

```typescript
// my-extension.ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
  pi.registerTool({
    name: "myTool",
    description: "工具功能描述",
    parameters: { ... },
    execute: async () => { ... }
  });
}
```

## 系统要求

- Pi coding agent v0.99.x+
- Node.js v22+
- PowerShell (Windows) 或 Bash (Linux/Mac)

## License

MIT
