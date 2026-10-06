# pi-web 客户端自动补全修改指南

## 当前状态

已应用的补丁：
- ✓ `sendAutocompleteRequest` 函数（发送请求到服务端）
- ✓ `autocomplete_result` 消息监听（接收服务端响应）
- ✓ `nu` 函数检测 `@skill:` 模式

**剩余工作：** 弹窗渲染，显示扩展建议

---

## 需要修改的代码位置

### 1. 存储 autocomplete 结果

在 `nu` 函数调用处附近，添加状态变量：

```javascript
// 找到类似这样的代码：
// let ew = ... (nu 函数的返回值)
// 添加：
let [extensionSuggestions, setExtensionSuggestions] = useState([]);
```

### 2. 在 `nu` 函数中调用 `sendAutocompleteRequest`

修改 `nu` 函数，在检测到 `@skill:` 时发送请求：

```javascript
function nu(e){
  // 检测 @skill: 模式
  let skillMatch = /(?:^|\s)@skill:(\w*)$/.exec(e);
  if(skillMatch){
    // 发送请求并存储结果
    sendAutocompleteRequest(skillMatch[1], '@skill:')
      .then(data => setExtensionSuggestions(data.items || []));
    return {
      start: e.length - (skillMatch[1].length + 8),
      query: skillMatch[1],
      quoted: false,
      trigger: '@skill:'  // 标记是扩展补全
    };
  }
  // ... 原有逻辑
}
```

### 3. 修改弹窗数据源

找到计算 mentions 列表的代码（变量 `tb`），修改为：

```javascript
// 原始代码（伪代码）：
// let tb = useMemo(() => {
//   if (ty === null || !eB) return [];
//   return filterMentions(eB, ty, 20);
// }, [ty, eB]);

// 修改为：
let tb = useMemo(() => {
  // 如果是 @skill: 补全，使用扩展建议
  if (ew?.trigger === '@skill:') {
    return extensionSuggestions.map(item => ({
      value: item.value,
      label: item.label,
      description: item.description,
      isExtension: true  // 标记是扩展建议
    }));
  }
  // 原有文件 mention 逻辑
  if (ty === null || !eB) return [];
  return filterMentions(eB, ty, 20);
}, [ty, eB, ew, extensionSuggestions]);
```

### 4. 修改弹窗渲染

找到弹窗渲染代码，添加扩展标记显示：

```javascript
// 找到类似这样的代码：
// <li key={item.value}>
//   <span>{item.label}</span>
//   <small>{item.description}</small>
// </li>

// 修改为：
<li key={item.value} style={item.isExtension ? {background: 'var(--bg-alt)'} : {}} >
  <span>{item.isExtension ? '⚡ ' : ''}{item.label}</span>
  <small>{item.description}</small>
</li>
```

### 5. 修改键盘导航

确保键盘导航支持扩展建议：

```javascript
// 找到 handleKeyDown 或类似函数
// 确保 Tab/Enter 能选中扩展建议
// Escape 能关闭弹窗
```

---

## 简化方案：只支持 @skill: 补全

如果不想修改现有弹窗逻辑，可以创建一个独立的弹窗：

```javascript
// 新增组件：ExtensionAutocompletePopup
function ExtensionAutocompletePopup({visible, suggestions, onSelect}) {
  const [selected, setSelected] = useState(0);
  
  // 键盘导航
  useEffect(() => {
    function handleKey(e) {
      if (!visible) return;
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setSelected(s => Math.min(s + 1, suggestions.length - 1));
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setSelected(s => Math.max(s - 1, 0));
      } else if (e.key === 'Enter' || e.key === 'Tab') {
        e.preventDefault();
        if (suggestions[selected]) {
          onSelect(suggestions[selected]);
        }
      } else if (e.key === 'Escape') {
        e.preventDefault();
        // 关闭弹窗
      }
    }
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [visible, selected, suggestions]);
  
  if (!visible || suggestions.length === 0) return null;
  
  return (
    <div className="autocomplete-popup" style={{position: 'absolute', bottom: '100%', ...}}>
      {suggestions.map((item, i) => (
        <div 
          key={i}
          style={{backgroundColor: i === selected ? 'var(--bg-selected)' : 'transparent'}}
          onMouseDown={() => onSelect(item)}
        >
          <span>{item.label}</span>
          {item.description && <small>{item.description}</small>}
        </div>
      ))}
    </div>
  );
}
```

---

## 测试方法

1. 启动 pi-web
2. 在输入框输入 `@skill:`
3. 应看到扩展建议弹窗
4. 输入 `@skill:co` 应过滤到包含 "co" 的建议
5. Tab/Enter 选中应插入选中的值
6. Escape 应关闭弹窗

---

## 注意事项

1. **请求去抖**：用户快速输入时，需要 debounce（建议 200-300ms）
2. **超时处理**：如果服务端无响应，3 秒后关闭弹窗
3. **空结果**：如果没有匹配项，隐藏弹窗
4. **取消请求**：用户输入新内容时，取消之前的请求
5. **样式兼容**：确保弹窗样式与 pi-web 主题一致

---

## 备选方案：不修改客户端

如果不想修改客户端代码，可以使用以下变通方案：

### 方案 A：使用 discoverSkill 工具

扩展在 `session_start` 时注册 `discoverSkill` 工具，LLM 可以主动查询 skills：

```typescript
pi.registerTool({
  name: 'discoverSkill',
  description: 'Search available skills by name',
  parameters: { query: { type: 'string' } },
  execute: async (params) => {
    // 返回匹配的 skills
  }
});
```

### 方案 B：服务端推送 skills 列表

扩展通过 `setWidget` 推送 skills 数据到客户端，客户端读取并显示。

### 方案 C：向 pi-web 上游提 PR

最彻底的方案，但需要等待上游合并。
