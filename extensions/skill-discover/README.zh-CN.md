# Skill Discover 扩展

[English](README.md) | [中文](README.zh-CN.md)

Pi 扩展，用于 skill 发现和 `@skill:` 内联自动补全。

## 功能特性

1. **`@skill:` 内联自动补全** — 在编辑器中任意位置输入 `@skill:` 即可发现 skill 名称，支持模糊匹配。

2. **中英文冒号支持** — 支持英文冒号（`:`）和中文冒号（`：`），补全时统一转为英文冒号。

3. **自动路径注入** — 输入时 `@skill:name` 会被转换为 `@skill:name("filePath")`，直接提供文件路径给模型。

4. **`discoverSkill` 工具** — 默认启用。帮助 LLM 快速查找已安装 skill 的名称和路径，特别是被 `disable-model-invocation: true` 隐藏在 system prompt 之外的 skill。

## 使用方法

### 发现 skills

在提示词中任意位置输入 `@skill:`（或 `@skill：`）：

```
参考 @skill:pdf-tools 的思路，帮我处理这个文档
```

编辑器会显示匹配的 skill 名称。按 Tab 或 Enter 选择。

### 工作原理

```
1. 输入: @skill:pdf-tools
2. 编辑器显示自动补全建议
3. 选择 pdf-tools
4. 提交时，输入被转换:
   @skill:pdf-tools → @skill:pdf-tools("C:\path\to\pdf-tools\SKILL.md")
5. 模型看到带引号的文件路径，可以直接读取 SKILL.md
```

**路径安全**：引号确保路径边界清晰，即使包含空格或特殊字符也不会出错。

## 配置

### 禁用 discoverSkill 工具（可选）

`discoverSkill` 工具**默认启用**。当提示词中通过名称引用 skill（`@skillName`、`$skillName` 或 `@skill:skillName`）时，帮助 LLM 定位该 skill —— 特别是标记了 `disable-model-invocation: true` 的 skill，它们在 system prompt 中不可见，只能通过此工具按名称查找。

如需禁用该工具（例如你只使用 `@skill:` 语法，希望减少 system prompt）：

```bash
# Windows PowerShell
$env:PI_SKILL_DISCOVER_TOOL = "false"
pi

# Linux/Mac
export PI_SKILL_DISCOVER_TOOL=false
pi
```

保持启用时，LLM 可以调用 `discoverSkill` 来：
- 列出所有已加载 skills（名称、描述、文件路径）
- 按名称或关键词搜索 skills
- 查找被 `disable-model-invocation: true` 隐藏的 skills

### 何时保持工具启用

建议保持启用（默认）如果：
- 希望提示词中出现 `@skillName` 或 `$skillName` 时 LLM 能找到该 skill
- 希望查找被 `disable-model-invocation` 隐藏的 skills
- 询问"有哪些可用 skills？"并获取带路径的列表

## 安装

此扩展通过项目的安装脚本安装：

```bash
# 从项目根目录
./install.sh skill-discover

# 或与其他扩展一起安装
./install.sh skill-discover another-extension
```

或手动安装：

```bash
cp extensions/skill-discover/skill-discover.ts ~/.pi/agent/extensions/
```

## 注意事项

- Skills 在会话开始时缓存。添加新 skills 后请运行 `/reload`。
- `@skill:` 自动补全不受 `enableSkillCommands` 设置影响。
- 模型完全自主决定是否加载引用的 skill。
- `discoverSkill` 工具默认启用，使 LLM 能按名称定位 skill，包括被 `disable-model-invocation` 隐藏的 skill。
