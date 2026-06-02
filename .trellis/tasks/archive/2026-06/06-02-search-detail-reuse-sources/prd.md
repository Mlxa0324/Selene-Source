# 搜索页进入详情页复用搜索结果来源，跳过 SSE 二次搜索

## Goal

当用户在 TV 搜索页完成搜索后，从聚合影视卡片进入详情页时，详情页不再额外发起按标题补源的 SSE 二次搜索，而是直接复用搜索页当前结果中同片名对应的来源集合，减少重复请求与等待时间。

## Requirements

- TV 搜索页聚合卡片打开详情页时，需要把该卡片对应的同片名搜索结果集合一并带入详情页。
- TV 详情页收到来自搜索页的候选来源集合后，仍可保留对入口主源详情的精确加载，但不能再发起按标题的 SSE 补源搜索。
- 详情页展示的可切换资源数量，应与搜索页该片名聚合出的资源集合一致，按现有去重规则去重后展示。
- 非搜索页进入详情页的链路保持原行为，不受本次改动影响。
- 标题匹配规则沿用搜索页当前的归一化片名规则，避免搜索页与详情页各自匹配出不同集合。

## Acceptance Criteria

- [ ] 从 TV 搜索页进入详情页时，不再调用按标题补源的 SSE 搜索逻辑。
- [ ] 从 TV 搜索页进入详情页时，详情页资源列表与搜索页当前聚合出的同片名资源集合一致。
- [ ] 从首页、历史、收藏等非搜索页进入详情页时，详情页仍保持原有补源能力。
- [ ] 补充或更新测试，覆盖“搜索页进入详情页复用搜索来源”和“非搜索页保持原逻辑”这两类行为。

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
