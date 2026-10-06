# 上游贡献指南

本文件描述如何向 [agegr/pi-web](https://github.com/agegr/pi-web) 提交 PR，正式支持扩展自动补全。

## 背景

pi-web 的 `ExtensionUIContext.addAutocompleteProvider()` 是空操作，导致扩展注册的自动补全 provider 在 pi-web 中不生效。

当前 pi-web 已有完整的 `extension_ui_request`/`extension_ui_response` 协议（用于对话框、通知等），只需新增一个 `autocomplete` 方法即可支持补全。

## 改动概览

| # | 文件 | 改动 | 行数 |
|---|------|------|------|
| 1 | 服务端 `ExtensionUIContext` | 实现 `addAutocompleteProvider` | ~15 |
| 2 | 服务端 `extension_ui_request` | 新增 `autocomplete` 方法 | ~25 |
| 3 | 客户端 `@-mention` 弹窗 | 数据源改为 RPC 查询 | ~30 |

**总计约 70 行改动**

## 改动 1：服务端 - 存储 Autocomplete Provider

**文件：** `PiWebSession` 类（或等效的 session 管理类）

### 添加 provider 存储

```typescript
// 在 PiWebSession 类中添加
private autocompleteProviders: AutocompleteProvider[] = [];
```

### 实现 `addAutocompleteProvider`

```typescript
// 在 createExtensionUiContext() 方法中
// 
// 当前（no-op）:
addAutocompleteProvider: () => {}

// 改为:
addAutocompleteProvider: (factory) => {
  try {
    const current = this.autocompleteProviders.length > 0
      ? this.autocompleteProviders[this.autocompleteProviders.length - 1]
      : null;
    const next = current ? factory(current) : factory();
    this.autocompleteProviders.push(next);
    return next;
  } catch (e) {
    console.error('[pi-web] addAutocompleteProvider error:', e.message);
  }
}
```

## 改动 2：服务端 - 处理 `autocomplete` 请求

在 `extension_ui_request` 处理逻辑中，添加 `autocomplete` 方法。

### 请求格式

```typescript
// 客户端发送
{
  type: "extension_ui_request",
  method: "autocomplete",
  prefix: "sk",        // 用户输入的查询文本
  trigger: "@"         // 触发字符
}
```

### 响应格式

```typescript
// 服务端返回
{
  type: "extension_ui_response",
  items: [             // 建议列表
    { value: "skill", label: "skill", description: "..." },
    { value: "search", label: "search", description: "..." }
  ],
  prefix: "@"
}
```

### 实现代码

```typescript
// 在 extension_ui_request 处理逻辑中
case "autocomplete": {
  const prefix = request.prefix || "";
  const trigger = request.trigger || "@";
  
  const provider = this.autocompleteProviders[
    this.autocompleteProviders.length - 1
  ];
  
  if (!provider) {
    resolve({ items: [], prefix: trigger });
    return;
  }
  
  // 调用 provider.getSuggestions()
  // 注意：web 模式没有多行编辑器的 lines/cursorLine/cursorCol
  // 传入空数组和 0，让 provider 自行处理
  provider.getSuggestions([], 0, 0, {
    signal: new AbortController().signal,
    force: true
  })
  .then(suggestions => {
    if (suggestions) {
      resolve({
        items: suggestions.items,
        prefix: suggestions.prefix
      });
    } else {
      resolve({ items: [], prefix: trigger });
    }
  })
  .catch(() => {
    resolve({ items: [], prefix: trigger });
  });
  return;
}
```

## 改动 3：客户端 - 弹窗数据源

**文件：** `app/page` 组件（或输入框组件）

### 当前流程

```
textarea onChange → nu(text) 检测 @ → 获取本地 mentions → 渲染弹窗
```

### 目标流程

```
textarea onChange → nu(text) 检测 @ → 发送 RPC 请求 → 接收响应 → 渲染弹窗
```

### 添加 RPC 调用函数

```typescript
async function sendAutocompleteRequest(
  prefix: string,
  trigger: string = "@"
): Promise<AutocompleteItem[]> {
  // 使用现有的 extension_ui_request 通道发送
  const response = await sendExtensionUiRequest({
    method: "autocomplete",
    prefix,
    trigger
  });
  
  return response?.items || [];
}
```

### 修改 `@-mention` 数据源

```typescript
// 当前（伪代码）:
const mentions = getMentions(query);

// 改为:
const items = await sendAutocompleteRequest(query, "@");
```

### 添加请求去抖

```typescript
const [autocompleteItems, setAutocompleteItems] = useState([]);
const debounceTimer = useRef<NodeJS.Timeout>();

function handleMentionQuery(query: string) {
  if (debounceTimer.current) clearTimeout(debounceTimer.current);
  
  debounceTimer.current = setTimeout(async () => {
    try {
      const items = await sendAutocompleteRequest(query, "@");
      setAutocompleteItems(items);
    } catch {
      setAutocompleteItems([]);
    }
  }, 250);
}
```

## 测试

### 测试扩展

创建一个测试扩展：

```typescript
// test-autocomplete.ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;
    
    ctx.ui.addAutocompleteProvider((current) => {
      return {
        ...current,
        triggerCharacters: ["@"],
        
        async getSuggestions(lines, cursorLine, cursorCol, options) {
          const text = lines[cursorLine]?.slice(0, cursorCol) || "";
          const match = /@(\w*)$/.exec(text);
          if (!match) return null;
          
          const query = match[1].toLowerCase();
          const allSkills = [
            { value: "code-review", label: "code-review", description: "Review code" },
            { value: "tdd", label: "tdd", description: "Test-driven development" },
            { value: "research", label: "research", description: "Investigate a topic" },
          ];
          
          const filtered = allSkills.filter(s =>
            s.value.toLowerCase().includes(query)
          );
          
          return {
            items: filtered,
            prefix: "@" + query
          };
        },
        
        applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
          return {
            lines,
            cursorLine,
            cursorCol: cursorCol + item.value.length
          };
        }
      };
    });
  });
}
```

### 验证

1. 启动 pi-web
2. 安装测试扩展
3. 在输入框输入 `@`
4. 应看到下拉弹窗显示 skills
5. 输入 `@co` → 过滤到 `code-review`
6. Tab/Enter 选中 → 插入 `code-review`

## 向后兼容

- ✅ 不影响已有扩展
- ✅ 不影响已有 `@-mention` 功能（无 provider 时返回空数组）
- ✅ 无 provider 时不发送 RPC 请求
- ✅ 请求失败时静默降级
