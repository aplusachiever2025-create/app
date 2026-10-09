# SG Tutor Match — Namecheap Shared Hosting 迁移执行计划

> 状态：规划 / staging only。此文件不代表已部署、已导入数据或已切换生产系统。
> 目标：用 Namecheap cPanel 上的 PHP + PDO + MySQL/MariaDB 完全替代 Supabase Auth、Postgres、Storage、RPC/Edge Functions。

## 0. 不可违反的安全边界
- 不修改 GitHub `main`；迁移代码只放在 `migration/namecheap-php-mysql-staging` 分支。
- 不在现有正式目录上测试。建议另建随机难猜的 staging 目录，例如 `public_html/tm-staging-<随机后缀>/`，并用独立的 MySQL 数据库；不要与正式库共用。
- 迁移期间 Supabase 仍是当前生产系统的唯一数据源。禁止双写，除非未来另行设计并测试一致性方案。
- 不把数据库密码、管理员密码、API secret、真实家长/老师资料或履历提交到 GitHub。
- 切换前备份代码、MySQL dump 和 Supabase 数据；保留回滚路径。任何阶段失败都可以继续使用当前生产系统。
- Namecheap 共享主机是否允许特定 PHP 版本、cron、上传限制和目录权限，必须在 cPanel 实测；不能假设已启用。

## 1. 目标架构
- 静态页面：HTML/CSS/JavaScript，可继续由同一主机提供。
- API：PHP 8.x（以 cPanel 实际版本为准）+ PDO prepared statements + JSON responses。
- 数据库：Namecheap MySQL/MariaDB；表统一使用 `tm_` 前缀，先隔离测试。
- 管理员身份：自建账号表、`password_hash()` / `password_verify()`、随机 session ID、服务端 session、登录限速、CSRF 防护和安全 cookie。不能只靠前端隐藏按钮。
- 文件：老师履历放在 web root 外的私有目录（如主机权限允许）；下载由 PHP 验证管理员权限后输出。若无法安全存放在 web root 外，必须用拒绝直接访问的服务器规则并验证后再启用。
- 配置：数据库连接和 secret 放在 web root 外的配置文件或主机环境变量；`config.example.php` 只放占位符。
- 通信：全程 HTTPS；API 对写操作校验方法、输入、身份与权限；错误响应不泄露 SQL、路径、secret 或个人资料。

## 2. 数据与功能迁移清单
### A. 数据模型
核对正式 Supabase schema、触发器、RLS policies、views、RPC、Edge Functions 和实际前端查询；逐列映射至 MySQL。尤其核实 JSONB 字段（老师科目、地区、时间段）、时间/时区、唯一约束、删除/停用标记、佣金和跟进字段。不要只按草稿 SQL 推断生产结构。

### B. 家长端
- 新建家长需求、验证必填项、预算/地区/教学方式/时间段、状态与撤回/关闭。
- 联系方式只用于 SG Tutor Match 平台撮合，不公开给其他家长或老师。
- 家长 request 在确认成交后关闭。

### C. 老师端
- 创建和更新老师资料、科目/年级/课程体系、费率、地区、授课方式和可用时间。
- 老师资料默认不向普通访客公开敏感联系信息。
- 老师履历为可选项；上传要限制文件类型、大小、随机文件名并防止执行脚本；后台审核和授权下载。
- 老师确认不再接单/不教对应科目时，可由后台停用；成交后老师档案仍可继续参与其他家长配对。

### D. 科目与配对
- 建立单一的规范化科目/年级字典，并让家长表单、老师表单、数据库与匹配算法共用它。
- 覆盖 Primary、Secondary、IP1–IP4、JC1–JC2 / A-Level，以及 E-Math、A-Math、Combined Science、Social Studies、H2 Chemistry 等规范名称与别名。
- 匹配不仅看科目，还需核对年级、预算、教学方式、地区/邮区、时间段和老师状态。
- 对 parent_id + tutor_id 建立唯一约束；在事务中创建/更新案件，避免重复配对。
- 将原有 SmartMatch Edge Function 和触发器行为迁移至 PHP 服务层/事务，并用旧逻辑做对照测试。

### E. 运营后台
- 管理员登录/退出/会话过期、权限检查和审计记录。
- 案件状态：待处理、双方有兴趣、沟通中、试听中、已确认、未成交、取消等。
- 跟进记录、下次跟进时间、逾期提醒、每位管理员的跟进量、转化漏斗、待处理家长/老师数量。
- 成交确认后计算平台佣金：两次课时费；佣金金额/状态及其计算依据需可审计。
- 内部家长/老师质量等级仅限后台查看，不暴露给家长或老师。

## 3. 分阶段执行与验收
### Phase 1 — 主机与隔离测试环境
- 确认 PHP 版本、PDO MySQL、HTTPS、上传上限、私有目录能力和 MySQL 字符集（建议 utf8mb4）。
- 在 cPanel 创建独立 staging 数据库与独立测试目录。
- 验收：测试 PHP health endpoint 可用；能用 PDO 连接 staging DB；正式网站和 Supabase 无变化。

### Phase 2 — Schema 对照
- 导出正式 schema（不把 secret 放进导出文件），逐一核对表、列、索引、外键、触发器、RPC、RLS 和 Edge Functions。
- 对 `tm_*` 测试 schema 执行建表并检查约束。
- 验收：每个生产字段/业务行为都有映射记录；没有静默丢弃的字段。

### Phase 3 — 管理员身份与 API 基础
- 实现 health、login、logout、session/me、统一 JSON 错误格式、权限中间件。
- 加入登录限速、CSRF 防护、cookie 安全属性、会话轮换和审计日志。
- 验收：未登录不能读取后台数据；非管理员不能访问管理 API；密码不以明文保存。

### Phase 4 — 家长/老师数据 API
- 完成创建、列表、详情、更新、停用和输入验证；普通前台只拿到必要字段。
- 验收：联系人信息不会出现在公开列表或错误日志；重复提交和非法输入得到明确错误。

### Phase 5 — SmartMatch 与案件生命周期
- 完成科目规范化、筛选、兴趣记录、案件状态机、跟进记录、成交确认与佣金计算。
- 验收：用 H2 Chemistry / JC2-A-Level 别名等回归样例验证家长与老师能正确匹配；同一对家长/老师不会生成重复案件；确认成交会关闭家长 request 但不自动关闭老师档案。

### Phase 6 — 履历文件与运营驾驶舱
- 完成私有上传、管理员授权下载、文件校验、待跟进中心和运营指标。
- 验收：未登录或无权限不能下载履历；上传失败有可理解错误；统计值可与原系统抽样对账。

### Phase 7 — 数据迁移与对账
- 先导入脱敏测试数据，再做一次只读的正式数据导出/映射演练。
- 对每张表核对总数、关键 ID、状态、时间戳、关联关系和抽样内容；检查孤儿记录、重复案件和缺失文件。
- 验收：对账报告签字确认前不切换生产；不在测试中写入正式库。

### Phase 8 — 切换与回滚
- 选低流量时间；冻结短暂写入窗口并做最终备份/增量对账。
- 更新正式页面 API 地址并部署到正式目录；先做 smoke tests，再开放用户写入。
- 监控错误日志、提交成功率、登录、配对和文件下载。
- 回滚条件：登录/提交/配对/后台任一关键路径失败、数据计数不一致或权限泄露。回滚到已备份的旧代码与 Supabase 生产路径；不要删除旧数据。
- 只有稳定运行并完成备份验证后，才考虑撤销旧 Supabase 资源；先保留一段观察期。

## 4. 当前状态与限制
- 本计划和现有 migration 分支只是 GitHub 中的 staging 资料。
- 尚未访问 Namecheap cPanel，也没有在真实主机执行 SQL、部署 PHP、迁移真实数据或验证上传。
- `api/index.php` 中未实现的业务 endpoint 不得视为已迁移。
- 下一步需要在 cPanel 手动确认 staging 目录/数据库已创建，并由用户在主机内安全设置 secret；不要在聊天中发送密码。
