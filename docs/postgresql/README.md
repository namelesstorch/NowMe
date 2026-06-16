# PostgreSQL 交付物总览

这组文件是“我在”项目数据库设计的最终交付包，目标是让后续开发者在不改当前快应用本地原型的前提下，直接进入 PostgreSQL 与后端实现阶段。

## 阅读顺序

1. [../postgresql-database-architecture.md](../postgresql-database-architecture.md)
2. [data-dictionary.md](./data-dictionary.md)
3. [local-storage-migration.md](./local-storage-migration.md)
4. `sql/001_extensions_and_types.sql`
5. `sql/002_core_tables.sql`
6. `sql/003_ai_and_context_tables.sql`
7. `sql/004_indexes.sql`
8. `sql/005_seed_demo_user.sql`
9. `sql/006_migrate_local_events.sql`

## 文件说明

- [../postgresql-database-architecture.md](../postgresql-database-architecture.md)
  数据库总设计、边界、业务规则、未来 API 契约与验收口径。
- [data-dictionary.md](./data-dictionary.md)
  最终数据字典，覆盖全部表、关键字段与约束设计。
- [local-storage-migration.md](./local-storage-migration.md)
  当前快应用 `@system.storage` 中 `events` 数据迁移到 PostgreSQL 的映射规则。
- `sql/001_extensions_and_types.sql`
  PostgreSQL 扩展与统一枚举类型。
- `sql/002_core_tables.sql`
  用户、认证、日程、记账、标签、预算、统计缓存主表。
- `sql/003_ai_and_context_tables.sql`
  AI 输入、结构化解析、上下文、习惯信号与审计表。
- `sql/004_indexes.sql`
  查询索引、部分唯一索引与常用检索优化。
- `sql/005_seed_demo_user.sql`
  演示用户与基础分类种子数据。
- `sql/006_migrate_local_events.sql`
  从旧版本地 `events` 结构导入 PostgreSQL 的参考迁移脚本。

## 执行顺序

```sql
\i sql/001_extensions_and_types.sql
\i sql/002_core_tables.sql
\i sql/003_ai_and_context_tables.sql
\i sql/004_indexes.sql
\i sql/005_seed_demo_user.sql
```

`006_migrate_local_events.sql` 只在需要导入旧版本地数据时执行。

## 当前版本边界

- 保留单用户生活管理的一体化能力：日程、记账、AI 输入、习惯建议。
- 支持手机号登录设计，但不包含短信服务商接入代码。
- 不做多账户钱包、转账、多人分账、日程参与者、共享权限。
- 云端 Agent 不直接访问数据库；数据库只为未来后端提供数据中心与审计能力。
