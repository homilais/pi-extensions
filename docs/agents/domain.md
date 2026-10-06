# Domain Docs

Engineering skills 在探索代码库时应如何消费本仓库的领域文档。

## 探索前先读取以下文件

- 根目录的 **`GLOSSARY.md`**，或
- 根目录的 **`GLOSSARY-MAP.md`**（如果存在）：它指向每个 context 各自的 `GLOSSARY.md`。读取与当前主题相关的每一个。
- **`docs/adr/`**：读取与即将工作的领域相关的 ADR。在多 context 仓库中，还需检查 `src/<context>/docs/adr/` 中的 context 级决策。

如果这些文件不存在，**静默继续**。不要标记其缺失；不要提前建议创建它们。`/domain-modeling` skill（通过 `/grill-with-docs` 和 `/improve-codebase-architecture` 到达）会在术语或决策真正被解决时惰性创建它们。

## 文件结构

Single-context 仓库（大多数仓库）：

```
/
├── GLOSSARY.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

Multi-context 仓库（根目录存在 `GLOSSARY-MAP.md`）：

```
/
├── GLOSSARY-MAP.md
├── docs/adr/                          ← 系统级决策
└── src/
    ├── ordering/
    │   ├── GLOSSARY.md
    │   └── docs/adr/                  ← context 特定决策
    └── billing/
        ├── GLOSSARY.md
        └── docs/adr/
```

## 使用 glossary 的词汇

当输出中提及领域概念时（issue 标题、重构提案、假设、测试名称），使用 `GLOSSARY.md` 中定义的术语。不要漂移到 glossary 明确避免的同义词。

如果你需要的概念尚未在 glossary 中，这是一个信号：要么你在发明项目不使用的语言（重新考虑），要么存在真正的缺口（记录下来，交给 `/domain-modeling`）。

## 标记 ADR 冲突

如果输出与现有 ADR 矛盾，明确标记出来而不是静默覆盖：

> _与 ADR-0007（event-sourced orders）矛盾，但值得重新讨论，因为……_
