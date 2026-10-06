# Skill Discover Extension

[English](README.md) | [中文](README.zh-CN.md)

A Pi extension for skill discovery and `@skill:` inline autocomplete.

## Features

1. **`@skill:` inline autocomplete** — Type `@skill:` anywhere in the editor to discover skill names with fuzzy matching.

2. **Bilingual colon support** — Supports both English (`:`) and Chinese (`：`) colons. Normalizes to English on completion.

3. **Auto filepath injection** — On input, `@skill:name` is transformed to `@skill:name("filePath")`, giving the model the path directly.

4. **Optional `discoverSkill` tool** — Available on request (disabled by default to reduce system prompt).

## Usage

### Discover skills

Type `@skill:` (or `@skill：`) anywhere in your prompt:

```
参考 @skill:pdf-tools 的思路，帮我处理这个文档
```

The editor shows matching skill names. Press Tab or Enter to select.

### How it works

```
1. You type: @skill:pdf-tools
2. Editor shows autocomplete suggestions
3. You select pdf-tools
4. On submit, input is transformed:
   @skill:pdf-tools → @skill:pdf-tools("C:\path\to\pdf-tools\SKILL.md")
5. Model sees the quoted filepath and can read SKILL.md directly
```

**Path safety**: Quotes ensure path boundaries are clear even with spaces or special characters.

## Configuration

### Enable discoverSkill tool (optional)

The `discoverSkill` tool is **disabled by default** since filepath is auto-injected via `@skill:` syntax.

To enable the tool (e.g., for discovering skills without `@skill:` references):

```bash
# Windows PowerShell
$env:PI_SKILL_DISCOVER_TOOL = "true"
pi

# Linux/Mac
export PI_SKILL_DISCOVER_TOOL=true
pi
```

When enabled, the LLM can call `discoverSkill` to:
- List all available skills
- Search skills by name or query

### When to enable the tool

Enable the tool if you want:
- LLM to discover skills without explicit `@skill:` references
- To ask "What skills are available?" and get a list
- To search for skills by keyword

## Installation

This extension is installed via the project's install script:

```bash
# From project root
./install.sh skill-discover

# Or with other extensions
./install.sh skill-discover another-extension
```

Or manually:

```bash
cp extensions/skill-discover/skill-discover.ts ~/.pi/agent/extensions/
```

## Notes

- Skills are cached at session start. Run `/reload` after adding new skills.
- `@skill:` autocomplete works regardless of `enableSkillCommands` setting.
- The model has full autonomy to decide whether to load a referenced skill.
- Default mode (tool disabled) is optimal for most use cases since filepath is auto-injected.
