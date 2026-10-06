# pi-web-autocomplete

为 pi-web 添加扩展自动补全支持的补丁。

## 问题

pi-web 的 `ExtensionUIContext.addAutocompleteProvider()` 是空操作 (`()=>{}`)，导致扩展注册的自动补全 provider 在 pi-web 中不生效。

## 解决方案

**不是引入新协议**，而是给已有的 `extension_ui_request`/`extension_ui_response` 通道新增一个 `autocomplete` 方法。

### 架构

```
客户端 textarea
  ↓ onChange 检测 @
  ↓ 发送 extension_ui_request({ method: "autocomplete" })
  ↓
服务端 ExtensionUIContext
  ↓ addAutocompleteProvider → 存 provider（不再 no-op）
  ↓ 处理 autocomplete 请求 → 遍历 provider.getSuggestions()
  ↓ 返回 extension_ui_response({ items })
  ↓
客户端弹窗 UI
  ↓ 渲染 suggestions → 键盘导航 → 插入值
```

## 文件结构

```
pi-web-autocomplete/
├── README.md              ← 本文件
├── UPSTREAM.md            ← 上游贡献指南（完整 diff）
├── patch/
│   ├── server-patch.js    ← 服务端 monkey-patch（可直接使用）
│   └── client-patch.js    ← 客户端补丁代码（参考）
└── scripts/
    ├── apply-patch.ps1    ← 应用补丁（带备份）
    └── revert-patch.ps1   ← 还原补丁
```

## 安装

### 方式一：使用补丁脚本（推荐）

```powershell
# 应用补丁
.\scripts\apply-patch.ps1

# 还原补丁
.\scripts\revert-patch.ps1
```

### 方式二：手动应用

见 [UPSTREAM.md](UPSTREAM.md) 中的详细步骤。

## 修改点

| # | 文件 | 修改 | 复杂度 |
|---|------|------|--------|
| 1 | `.next/server/chunks/6429.js` | `addAutocompleteProvider:()=>{}` → 存 provider | 低 |
| 2 | `.next/server/chunks/6429.js` | 新增 `autocomplete` 请求处理 | 中 |
| 3 | `.next/static/chunks/app/page-*.js` | `@-mention` 弹窗数据源改为 RPC 查询 | 中 |

## 兼容性

- ✅ 不修改 pi-web 源码，使用 monkey-patch
- ✅ 补丁可一键还原
- ✅ 不影响其他扩展功能
- ⚠️ pi-web 版本更新后需重新应用

## 给上游的 PR

建议提交到 [agegr/pi-web](https://github.com/agegr/pi-web)，核心改动：
1. 实现 `addAutocompleteProvider`（存储 provider）
2. 新增 `autocomplete` 请求方法
3. 客户端弹窗支持扩展数据源

详见 [UPSTREAM.md](UPSTREAM.md)。
