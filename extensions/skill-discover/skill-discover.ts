/**
 * skill-discover extension for Pi
 * 
 * Provides:
 * 1. `@skill:` inline autocomplete trigger in the TUI editor
 * 2. Input transformation to append filepath: @skill:name → @skill:name("filePath")
 * 3. Optional `discoverSkill` tool (disabled by default to reduce system prompt)
 * 
 * Design philosophy:
 * - @skill:name is a hint marker, not a command
 * - The model decides whether to load a skill
 * - Input handler appends filepath so model can read SKILL.md directly
 * - Supports both English (: and Chinese (：) colons, normalizes to English
 * - Path is wrapped in quotes for safe parsing with special characters
 * 
 * Configuration:
 * - Set environment variable PI_SKILL_DISCOVER_TOOL=true to enable the discoverSkill tool
 * - Default: tool is NOT registered (path injection provides filepath directly)
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteProvider, AutocompleteItem, AutocompleteSuggestions } from "@earendil-works/pi-tui";
import { Type } from "typebox";

// --- Configuration ---
// Set environment variable PI_SKILL_DISCOVER_TOOL=true to enable the discoverSkill tool.
// Default: false (tool is not registered; path injection provides filepath directly)
const ENABLE_DISCOVER_TOOL = process.env.PI_SKILL_DISCOVER_TOOL === "true";

// --- Skill cache (populated at session_start) ---

interface SkillInfo {
  name: string;
  description?: string;
  filePath?: string;
  baseDir?: string;
}

let skills: SkillInfo[] = [];

function refreshSkills(commands: { name: string; description?: string; source?: string; sourceInfo?: { path?: string; baseDir?: string } }[]): void {
  skills = commands
    .filter((c) => c.source === "skill" && c.name.startsWith("skill:"))
    .map((c) => ({
      name: c.name.slice(6),
      description: c.description,
      filePath: c.sourceInfo?.path,
      baseDir: c.sourceInfo?.baseDir,
    }));
}

// --- Fuzzy matching helper ---

function fuzzyMatch(query: string, target: string): number {
  const q = query.toLowerCase();
  const t = target.toLowerCase();
  if (t.includes(q)) return 0; // exact substring match, best score
  let qi = 0;
  let score = 0;
  for (let ti = 0; ti < t.length && qi < q.length; ti++) {
    if (t[ti] === q[qi]) {
      qi++;
      score += ti; // gap penalty
    }
  }
  return qi === q.length ? score : -1;
}

function filterSkills(prefix: string): SkillInfo[] {
  if (!prefix) return skills;
  return skills
    .map((s) => ({ s, score: fuzzyMatch(prefix, s.name) }))
    .filter((x) => x.score >= 0)
    .sort((a, b) => a.score - b.score)
    .map((x) => x.s);
}

// --- Detect @skill prefix near cursor (supports : and ：) ---

const SKILL_PREFIX_LENGTH = 7; // "@skill:" or "@skill：" is 7 chars

function extractSkillPrefix(lines: string[], cursorLine: number, cursorCol: number): string | null {
  const line = lines[cursorLine] ?? "";
  if (cursorCol < line.length) return null; // cursor must be at end of what's typed
  const before = line.slice(0, cursorCol);
  
  // Find last @skill: or @skill： in the current line before cursor
  const regex = /@skill[:：]/g;
  let match: RegExpExecArray | null;
  let lastIdx = -1;
  while ((match = regex.exec(before)) !== null) {
    lastIdx = match.index;
  }
  
  if (lastIdx === -1) return null;
  
  // Ensure @ is at start or preceded by whitespace
  if (lastIdx > 0 && !/\s/.test(before[lastIdx - 1])) return null;
  
  return before.slice(lastIdx + SKILL_PREFIX_LENGTH); // text after "@skill:" or "@skill："
}

// --- Replacement for applyCompletion (normalizes to English colon) ---

function applySkillCompletion(
  lines: string[],
  cursorLine: number,
  cursorCol: number,
  skillName: string,
): { lines: string[]; cursorLine: number; cursorCol: number } {
  const updated = [...lines];
  const line = updated[cursorLine] ?? "";
  const before = line.slice(0, cursorCol);
  const after = line.slice(cursorCol);
  
  // Find last @skill: or @skill： in the text before cursor
  const regex = /@skill[:：]/g;
  let match: RegExpExecArray | null;
  let lastIdx = -1;
  while ((match = regex.exec(before)) !== null) {
    lastIdx = match.index;
  }
  
  if (lastIdx === -1) {
    // Fallback: delegate to original provider
    return { lines, cursorLine, cursorCol };
  }
  
  const replacement = `@skill:${skillName}`; // always normalize to English colon
  updated[cursorLine] = before.slice(0, lastIdx) + replacement + after;
  return { lines: updated, cursorLine, cursorCol: lastIdx + replacement.length };
}

// --- Input transformation: append filepath (with quotes for path safety) ---

function transformSkillReferences(text: string): string {
  // Match @skill:name patterns (English or Chinese colon)
  // Replace with @skill:name("filePath") if the skill exists and has a filePath
  // Quotes ensure path boundaries are clear even with spaces or special characters
  // Negative lookahead (?!["(]) skips references that already have a path injected
  // e.g. @skill:name("path") won't be matched again, preventing double injection
  return text.replace(/@skill[:：]([\w.-]+)(?!["(])/g, (match, skillName) => {
    const skill = skills.find((s) => s.name === skillName);
    if (skill && skill.filePath) {
      // Escape any double quotes in the path (rare but safe)
      const escapedPath = skill.filePath.replace(/"/g, '\\"');
      return `@skill:${skillName}("${escapedPath}")`;
    }
    // Unknown skill or no filepath, keep original
    return match;
  });
}

// --- Main extension factory ---

export default function (pi: ExtensionAPI): void {
  // 1. Register the discoverSkill tool (optional, disabled by default)
  if (ENABLE_DISCOVER_TOOL) {
    pi.registerTool({
      name: "discoverSkill",
      label: "Discover Skill",
      description:
        "Search loaded skills by name or description. Returns skill names, descriptions, and file paths. " +
        "Use this to discover available skills. To load a skill, use the read tool to open the returned SKILL.md path.",
      parameters: Type.Object({
        query: Type.String({ description: "Search term to filter skill names. Empty string returns all skills." }),
      }),
      execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
        const q = (params.query ?? "").trim().toLowerCase();
        if (!q) {
          const items = skills.map((s) => {
            const path = s.filePath ? ` [${s.filePath}]` : "";
            return `- ${s.name}${s.description ? ": " + s.description : ""}${path}`;
          });
          return {
            content: [{ type: "text", text: `Available skills (${skills.length}):\n${items.join("\n")}\n\n提示: 使用 read 工具读取对应的 SKILL.md 文件来加载完整 skill 内容。` }],
          };
        }
        const matches = skills.filter(
          (s) => s.name.toLowerCase().includes(q) || (s.description ?? "").toLowerCase().includes(q),
        );
        if (matches.length === 0) {
          return { content: [{ type: "text", text: `No skills matching "${q}".` }] };
        }
        const items = matches.map((s) => {
          const path = s.filePath ? ` [${s.filePath}]` : "";
          return `- ${s.name}${s.description ? ": " + s.description : ""}${path}`;
        });
        return {
          content: [{ type: "text", text: `Found ${matches.length} skill(s):\n${items.join("\n")}\n\n提示: 使用 read 工具读取对应的 SKILL.md 文件来加载完整 skill 内容。` }],
        };
      },
    });
  }

  // 2. Refresh skill list on session start
  pi.on("session_start", () => {
    refreshSkills(pi.getCommands());
  });

  // 3. Add @skill: autocomplete provider
  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;

    ctx.ui.addAutocompleteProvider((current: AutocompleteProvider) => {
      // Merge trigger characters
      const triggerChars = new Set([...(current.triggerCharacters ?? []), "@"]);

      return {
        triggerCharacters: [...triggerChars],

        async getSuggestions(
          lines: string[],
          cursorLine: number,
          cursorCol: number,
          options,
        ): Promise<AutocompleteSuggestions | null> {
          // Check for @skill: or @skill： prefix
          const prefix = extractSkillPrefix(lines, cursorLine, cursorCol);
          if (prefix !== null) {
            const matches = filterSkills(prefix);
            if (matches.length === 0) return null;
            const items: AutocompleteItem[] = matches.map((s) => ({
              value: s.name,
              label: s.name,
              description: s.description,
            }));
            return { items, prefix };
          }
          // Delegate to original provider
          return current.getSuggestions(lines, cursorLine, cursorCol, options);
        },

        applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
          // If this is a skill completion, use custom logic
          const skillPrefix = extractSkillPrefix(lines, cursorLine, cursorCol);
          if (skillPrefix !== null) {
            return applySkillCompletion(lines, cursorLine, cursorCol, item.value);
          }
          // Delegate to original provider
          return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
        },

        shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
          // Don't trigger file completion for @skill: context
          const skillPrefix = extractSkillPrefix(lines, cursorLine, cursorCol);
          if (skillPrefix !== null) return false;
          return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? false;
        },
      };
    });
  });

  // 4. Input transformation: @skill:name → @skill:name(filePath)
  // This gives the model the filepath directly, reducing one tool call
  pi.on("input", (event, _ctx) => {
    const transformed = transformSkillReferences(event.text);
    
    if (transformed === event.text) {
      return { action: "continue" };
    }
    return { action: "transform", text: transformed };
  });
}
