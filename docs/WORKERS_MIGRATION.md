# MiSub Worker / 上游同步架构

本仓库是 `imzyb/MiSub` 的 fork。为了降低长期维护量：

- 不修改 `src/`、`functions/` 中的上游业务源码。
- `main` 每日镜像 `imzyb/MiSub/main`。
- Worker 适配层存放在 `workers-overlay` 分支。
- 镜像完成后自动把 overlay 重新叠加到 `main`。
- Worker 部署在同步成功后自动执行。

## 路由

MiSub 只占：

- `nua.qzz.io/misub`
- `nua.qzz.io/misub/*`

未来根项目可以占：

- `nua.qzz.io/*`

CF-Workers-SUB 独立占：

- `nua.qzz.io/dy`
- `nua.qzz.io/dy/*`

不再需要 Gateway Worker。

## Cloudflare 资源

Worker 必须复用原 Pages 项目的：

- `MISUB_KV`
- `MISUB_DB`（实际使用 D1 时才需要）

不要新建资源，否则原业务数据不会自动出现。

MiSub 当前代码已经支持把管理员密码和 Cookie Secret 持久化在 KV，因此不需要为了这两项额外新增 Worker Secret。

## GitHub 配置

Repository Secrets：

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `SYNC_PAT`（已有则继续使用；没有时使用 GitHub Actions 自带 token）

不再需要 `CF_ACCOUNT_ID`、`MISUB_ROUTE_HOST`、`MISUB_ZONE_NAME`、`MISUB_KV_NAMESPACE_ID`、`MISUB_D1_DATABASE_ID` 这些 GitHub Variables/Secrets；域名、Route、KV、D1 ID 已固定在 `worker-runtime/wrangler.toml` 中。

## 回滚

原 Pages 项目先不要删除。

正式切换前验证：

- `/misub/`
- 登录/退出
- API
- 订阅生成
- profile 公开链接
- Cookie
- 自定义登录路径
- 备份/恢复

确认稳定后再停用旧 Pages 项目。
