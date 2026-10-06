# 客户端补丁说明

客户端代码（`@-mention` 弹窗）在浏览器中运行，无法通过 Node.js monkey-patch。

## 当前 `@-mention` 弹窗架构

```
textarea onChange
  ↓ nu(text) 检测 @ 和 query
  ↓ 获取 mentions 数据（当前：本地硬编码）
  ↓ 渲染弹窗（下拉列表 + 键盘导航）
  ↓ 用户选中 → 替换 @query → 插入值
```

## 需要修改的内容

### 修改 1：数据源从本地改为 RPC 查询

**文件：** `.next/static/chunks/app/page-*.js`（版本哈希会变化）

**当前代码模式（搜索关键词）：**
```javascript
// 找到类似这样的代码：
// 1. 调用 nu() 检测 @
// 2. 获取 mentions 数据（从 session state 或本地数据）
// 3. 设置弹窗状态

// 修改为：
// 1. 调用 nu() 检测 @（不变）
// 2. 发送 extension_ui_request({method:"autocomplete",prefix:query,trigger:"@"})
// 3. 接收 extension_ui_response → 设置弹窗状态
```

### 修改 2：发送 autocomplete 请求

在现有的 `extension_ui_request` 发送逻辑中，添加 `autocomplete` 方法支持。

**请求格式：**
```json
{
  "type": "extension_ui_request",
  "method": "autocomplete",
  "prefix": "sk",
  "trigger": "@"
}
```

**响应格式：**
```json
{
  "type": "extension_ui_response",
  "items": [
    {"value": "skill", "label": "skill", "description": "..."},
    {"value": "search", "label": "search", "description": "..."}
  ],
  "prefix": "@"
}
```

### 修改 3：键盘导航（已有，无需修改）

现有的 `@-mention` 弹窗已经支持：
- ↑↓ 导航
- Tab/Enter 选中
- Escape 关闭

只需确保 `items` 数据格式兼容即可。

## 实现步骤

### 步骤 1：找到 `@-mention` 数据源

```bash
# 搜索 mentions 数据获取逻辑
grep -n "mention\|@-\|getMention\|fetchMention" .next/static/chunks/app/page-*.js
```

### 步骤 2：替换数据源为 RPC 调用

将获取 mentions 的本地函数替换为发送 `extension_ui_request`。

```javascript
// 替换前（伪代码）:
const mentions = getMentions(query);

// 替换后（伪代码）:
const mentions = await sendAutocompleteRequest(query);
```

### 步骤 3：添加 RPC 调用函数

```javascript
async function sendAutocompleteRequest(prefix, trigger = "@") {
  // 使用现有的 SSE/WebSocket 连接发送 extension_ui_request
  const response = await sendExtensionUiRequest({
    method: "autocomplete",
    prefix,
    trigger
  });
  return response?.items || [];
}
```

## 注意事项

1. **请求去抖**：用户快速输入时，需要 debounce（建议 200-300ms）
2. **超时处理**：如果服务端无响应，3 秒后关闭弹窗
3. **空结果**：如果没有匹配项，隐藏弹窗
4. **取消请求**：用户输入新内容时，取消之前的请求

## 备选方案：不修改客户端

如果不想修改客户端代码，可以使用以下变通方案：

### 方案 A：服务端推送

扩展在 `session_start` 时通过 `setWidget` 推送 skill 数据：

```typescript
pi.on("session_start", (_event, ctx) => {
  const skills = ctx.sessionManager.skills || [];
  ctx.ui.setWidget("skills", skills.map(s => `${s.name} ${s.description || ''}`).join("\n"));
});
```

客户端读取 widget 数据，在 `@-mention` 弹窗中解析。

### 方案 B：HTTP API

创建简单的 HTTP API 端点返回 skill 数据，客户端轮询。

```
GET /api/skills → { items: [...] }
```

### 方案 C：纯扩展方案（无弹窗）

不修改 pi-web，改用 `discoverSkill` 工具：
- 用户输入 `@skill:name` → 服务端自动注入路径
- 无弹窗，但功能可用
