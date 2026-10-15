# Skill Discover Extension

[English](README.md) | [中文](README.zh-CN.md)

A Pi extension for skill discovery and `@skill:` inline autocomplete.

## Features

1. **`@skill:` inline autocomplete** — Type `@skill:` anywhere in the editor to discover skill names with fuzzy matching.

2. **Bilingual colon support** — Supports both English (`:`) and Chinese (`：`) colons. Normalizes to English on completion.

3. **Auto filepath injection** — On input, `@skill:name` is transformed to `@skill:name("filePath")`, giving the model the path directly.

4. **`discoverSkill` tool** — Enabled by default. Helps the LLM quickly look up installed skills by name/path, especially skills hidden from the system prompt by `disable-model-invocation: true`.

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

### Disable discoverSkill tool (optional)

The `discoverSkill` tool is **enabled by default**. It helps the LLM locate skills when a prompt references them by name (`@skillName`, `$skillName`, or `@skill:skillName`) — especially skills marked `disable-model-invocation: true`, which are hidden from the system prompt and can only be found via this tool.

To disable the tool (e.g., you only ever use `@skill:` syntax and want a smaller system prompt):

```bash
# Windows PowerShell
$env:PI_SKILL_DISCOVER_TOOL = "false"
pi

# Linux/Mac
export PI_SKILL_DISCOVER_TOOL=false
pi
```

When kept enabled, the LLM can call `discoverSkill` to:
- List all loaded skills (name, description, file path)
- Search skills by name or keyword
- Find skills hidden by `disable-model-invocation: true`

### When to keep the tool enabled

Keep it enabled (the default) if you want:
- The LLM to find skills when `@skillName` or `$skillName` appears in a prompt without a path
- The LLM to locate skills hidden from the system prompt by `disable-model-invocation`
- To ask "What skills are available?" and get a list with paths

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
- The `discoverSkill` tool is enabled by default so the LLM can locate skills by name, including those hidden by `disable-model-invocation`.
