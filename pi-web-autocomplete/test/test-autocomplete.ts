/**
 * test-autocomplete extension for pi-web
 * 
 * 测试扩展：演示如何在 pi-web 中注册自动补全 provider
 * 
 * 使用：
 * 1. 先应用补丁：bash scripts/apply-patch.sh
 * 2. 安装此扩展：cp test-autocomplete.ts ~/.pi/agent/extensions/
 * 3. 启动 pi-web
 * 4. 在输入框输入 @ → 应看到 skills 弹窗
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteProvider, AutocompleteItem, AutocompleteSuggestions } from "@earendil-works/pi-tui";

// 模拟的 skill 列表（实际会从 pi.getCommands() 获取）
const DEMO_SKILLS: AutocompleteItem[] = [
  { value: "code-review", label: "code-review", description: "Review code changes" },
  { value: "tdd", label: "tdd", description: "Test-driven development" },
  { value: "research", label: "research", description: "Investigate a topic" },
  { value: "grilling", label: "grilling", description: "Stress-test ideas" },
  { value: "diagnosing-bugs", label: "diagnosing-bugs", description: "Diagnose bugs" },
  { value: "domain-modeling", label: "domain-modeling", description: "Build domain model" },
  { value: "prototype", label: "prototype", description: "Build prototypes" },
  { value: "wizard", label: "wizard", description: "Generate wizards" },
];

export default function (pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) {
      console.log("[test-autocomplete] No UI context, skipping autocomplete registration");
      return;
    }

    console.log("[test-autocomplete] Registering autocomplete provider...");

    ctx.ui.addAutocompleteProvider((current: AutocompleteProvider) => {
      // 合并触发字符
      const triggerChars = new Set([...(current.triggerCharacters ?? []), "@"]);

      return {
        triggerCharacters: [...triggerChars],

        async getSuggestions(
          lines: string[],
          cursorLine: number,
          cursorCol: number,
          options,
        ): Promise<AutocompleteSuggestions | null> {
          // 检测 @query 模式
          const line = lines[cursorLine] ?? "";
          const before = line.slice(0, cursorCol);
          const match = /@(\w*)$/.exec(before);
          
          if (!match) {
            // 不是 @ 补全，委托给原始 provider
            return current.getSuggestions(lines, cursorLine, cursorCol, options);
          }

          const query = match[1].toLowerCase();
          
          // 过滤 skills
          const filtered = DEMO_SKILLS.filter(s =>
            s.value.toLowerCase().includes(query)
          );

          if (filtered.length === 0) return null;

          return {
            items: filtered,
            prefix: "@" + query,
          };
        },

        applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
          // 替换 @query 为 @selected_value
          const updated = [...lines];
          const line = updated[cursorLine] ?? "";
          const before = line.slice(0, cursorCol);
          const after = line.slice(cursorCol);
          
          const replacement = "@" + item.value;
          const newLine = before.replace(/@\w*$/, replacement) + after;
          updated[cursorLine] = newLine;
          
          return {
            lines: updated,
            cursorLine,
            cursorCol: cursorCol - (before.length - line.length) + replacement.length,
          };
        },

        shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
          // 在 @ 上下文中不触发文件补全
          const line = lines[cursorLine] ?? "";
          const before = line.slice(0, cursorCol);
          if (/@\w*$/.test(before)) return false;
          return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
        },
      };
    });

    console.log("[test-autocomplete] Autocomplete provider registered!");
  });
}
