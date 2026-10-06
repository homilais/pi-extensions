# Issue tracker: GitHub

本仓库的 issue 和 spec 存放在 GitHub Issues 中。所有操作使用 `gh` CLI。

## 约定

- **创建 issue**：`gh issue create --title "..." --body "..."`。多行正文使用 heredoc。
- **读取 issue**：`gh issue view <number> --comments`，用 `jq` 过滤评论并同时获取标签。
- **列出 issue**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，配合 `--label` 和 `--state` 过滤。
- **将 issue 设为父 issue 的子 issue**：`gh issue create --parent <parent> ...`，或事后 `gh issue edit <parent> --add-sub-issue <child>`（`gh` 2.94+）。旧版 `gh`：`gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>`（database id，见下方 **Blocking**）。不支持 sub-issues 时，在子 issue 正文顶部写 `Part of #<parent>`。
- **评论 issue**：`gh issue comment <number> --body "..."`
- **添加/移除标签**：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **关闭**：`gh issue close <number> --comment "..."`

从 `git remote -v` 推断仓库；在 clone 内运行时 `gh` 会自动完成。

## 将 Pull Request 作为 triage 对象

**PRs as a request surface: no。** _（如果本仓库将外部 PR 视为 feature request，设为 `yes`；`/triage` 会读取此标志。）_

设为 `yes` 时，PR 与 issue 使用相同的标签和状态，使用 `gh pr` 对应命令：

- **读取 PR**：`gh pr view <number> --comments` 和 `gh pr diff <number>` 获取 diff。
- **列出外部 PR**：`gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`。
- **评论/标记/关闭**：`gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub 中 issue 和 PR 共享同一编号空间，因此裸 `#42` 可能是两者之一：先用 `gh pr view 42` 尝试，再回退到 `gh issue view 42`。

## 当 skill 说"发布到 issue tracker"时

创建 GitHub issue。

## 当 skill 说"获取相关 ticket"时

运行 `gh issue view <number> --comments`。

## Wayfinding 操作

供 `/wayfinder` 使用。**Map** 是一个 issue，子 issue 作为 ticket。

- **Map**：一个标记为 `wayfinder:map` 的 issue，正文包含 Notes / Decisions-so-far / Fog。`gh issue create --label wayfinder:map`。
- **Child ticket**：与 map 关联的子 issue（见 **将 issue 设为父 issue 的子 issue**）。不支持 sub-issues 时，在 map 正文的任务列表中加上子 issue，并在子 issue 正文顶部写 `Part of #<map>`。标签：`wayfinder:<type>`（`research`/`prototype`/`grilling`/`task`）。认领后，ticket 分配给驱动开发的开发者。
- **Blocking**：GitHub 的**原生 issue 依赖关系**，是规范的、UI 可见的表示。用 `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>` 添加依赖边，其中 `<blocker-db-id>` 是阻塞方的数字 **database id**（`gh api repos/<owner>/<repo>/issues/<n> --jq .id`，_不是_ `#number` 或 `node_id`）。GitHub 报告 `issue_dependencies_summary.blocked_by`（仅显示开放阻塞方，即实时门禁）。依赖关系不可用时，回退到子 issue 正文顶部的 `Blocked by: #<n>, #<n>` 行。所有阻塞方关闭后 ticket 解除阻塞。
- **Frontier query**：列出 map 的开放子 issue（`gh issue list --state open`，限定在 map 的 sub-issues / 任务列表中），排除有开放阻塞方（`issue_dependencies_summary.blocked_by > 0`，或 `Blocked by` 行中有开放 issue）或已分配人的；按 map 顺序，第一个为前。
- **Claim**：`gh issue edit <n> --add-assignee @me`，本次会话的首次写入。
- **Resolve**：`gh issue comment <n> --body "<answer>"`，然后 `gh issue close <n>`，最后在 map 的 Decisions-so-far 中追加上下文指针（gist + 链接）。
