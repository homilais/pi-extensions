# Skill Discover 扩展

[English](README.md) | [中文](README.zh-CN.md)

Pi 扩展，用于 skill 发现和 `@skill:` 内联自动补全。

## 功能特性

1. **`@skill:` 内联自动补全** — 在编辑器中任意位置输入 `@skill:` 即可发现 skill 名称，支持模糊匹配。

2. **中英文冒号支持** — 支持英文冒号（`:`）和中文冒号（`：`），补全时统一转为英文冒号。

3. **自动路径注入** — 输入时 `@skill:name` 会被转换为 `@skill:name("filePath")`，直接提供文件路径给模型。

4. **可选 `discoverSkill` 工具** — 按需启用（默认禁用以减少 system prompt）。

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

### 启用 discoverSkill 工具（可选）

`discoverSkill` 工具**默认禁用**，因为 `@skill:` 语法已自动注入文件路径。

如需启用该工具（例如不使用 `@skill:` 引用时发现 skills）：

```bash
# Windows PowerShell
$env:PI_SKILL_DISCOVER_TOOL = "true"
pi

# Linux/Mac
export PI_SKILL_DISCOVER_TOOL=true
pi
```

启用后，LLM 可以调用 `discoverSkill` 来：
- 列出所有可用 skills
- 按名称或关键词搜索 skills

### 何时启用工具

在以下场景建议启用：
- 希望 LLM 在不使用 `@skill:` 引用的情况下发现 skills
- 询问"有哪些可用 skills？"并获取列表
- 按关键词搜索 skills

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
- 默认模式（工具禁用）适用于大多数场景，因为文件路径已自动注入。
