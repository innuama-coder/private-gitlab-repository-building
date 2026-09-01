---
id: overall-solution
title: 总体方案
document_kind: machine-readable-solution-brief
language: zh-CN
version: 3.5
status: delivered
source_of_truth: six-elements.md
environment_reference: related-environment.md
frozen_dependency: true
feasibility: feasible-with-gates
feasibility_gate: M1
feasibility_gates:
  - M1
  - M3
  - M5
primary_node: Proxmox VM 9002
runner_node: Mac Studio
public_entry_node: ECS4
backup_node: roymacbook-pro
access_only_node: ECS5
private_network: Tailscale
gitlab_tailscale_ip: 100.83.178.99
legacy_node: Mac Studio
---

# 总体方案

## 01. 可行性结论

方案对个人或小团队使用可行。GitLab 已迁移到 Proxmox VM `9002`，VM 的 CPU、内存和独立数据盘满足首期规模；Mac Studio 继续承担 Runner。当前风险集中在 VM 存储、家庭网络可用性、ECS4 公网入口和备份恢复链路。

M1 是硬门槛。只有在 GitLab VM 上完成 Linux 运行时、镜像、持久化目录、重启恢复和健康检查验证，并确认 Mac Studio Runner 可回连后，才允许把迁移标记为正式部署。

M3 也是公网访问门槛。只有在 ECS4 的带宽、端口、HTTPS、Web、HTTPS Git、SSH Git 和大流量 Git 转发均通过实测后，才允许把公网入口标记为可交付。

## 02. 目标到实现的对应关系

| 冻结目标 | 实现方式 | 合格证据 |
| --- | --- | --- |
| 代码托管 | Proxmox VM `9002` 运行单节点 GitLab，数据保存到 `/srv/gitlab` | 私有项目、仓库和重启后数据 |
| 协作评审 | GitLab 项目权限、Issue 和 Merge Request | 测试账号权限记录、评审记录 |
| CI/CD | Mac Studio GitLab Runner 执行示例流水线 | 成功/失败/重跑日志、制品 |
| 外部访问 | 公网用户经 ECS4 公网反向代理；ECS1 至 ECS6 通过 Tailscale 直连 GitLab VM | 域名、证书、SSH/HTTPS Git 记录和两条链路验证 |
| 可恢复运行 | GitLab 备份复制到 M5 内确定的独立备份目标，执行恢复和重启演练 | 备份文件、校验、恢复结果 |

## 03. 部署拓扑

```text
外部用户
  |  HTTPS / Git SSH
  v
ECS4 公网入口
  |  Tailscale 私网
  v
GitLab VM 9002
  |-- GitLab Web / Git HTTPS / Git SSH
  |-- /srv/gitlab 持久化数据

Mac Studio
  |-- GitLab Runner

ECS1 至 ECS6 上的 Git
  |  Tailscale 点对点
  v
GitLab VM HTTPS / SSH
```

## 04. 节点职责

### GitLab VM 9002：核心服务节点

- 运行 GitLab CE `19.3.1` 单节点 Docker 容器。
- 使用 `192.168.101.202` 作为家庭局域网地址，`100.83.178.99` 作为 Tailscale 服务地址。
- 将配置、日志、仓库、数据库、制品和上传文件放进稳定的持久化目录。
- 配置容器自动启动、健康检查和 VM 重启恢复。
- 只允许本机和 Tailscale 私网访问 GitLab 管理端口。

VM 已调整为 `8 vCPU / 16GB RAM`，数据盘约 `1TB` 并挂载到 `/srv/gitlab`。旧 Mac Studio GitLab 保留为回退节点，不承担当前正式流量。

### Mac Studio：Runner 节点

- 运行 Docker Desktop 和 GitLab Runner `mac-studio-arm64`。
- Runner URL 使用正式域名并连接当前 GitLab VM。
- 保持接电、联网并关闭自动睡眠；不再作为当前 GitLab 数据主节点。

### ECS4：公网入口节点

- 保留固定公网 IP，开放 80、443，以及 Git SSH 所需入口。
- 运行 Caddy 或 Nginx，负责域名、HTTPS 证书和反向代理。
- 通过 Tailscale 将所有外部 Web 和 Git HTTPS 请求转发到 GitLab VM。
- 将所有外部 Git SSH 请求转发到 GitLab VM 的 `2222/tcp`。
- 对 Git 大流量使用流式转发，不启用会把请求体或响应体落盘的缓存。
- 不保存 GitLab 仓库和核心业务数据。

ECS4 的管理员 SSH 和 Git SSH 必须分离：优先保留 22 端口用于管理，Git 使用独立端口并在域名或 Git 配置中声明；若使用同一端口，必须使用已经验证的 SSH 转发方案，不得靠未验证的端口复用假设交付。

### ECS1 至 ECS6：访问专用节点

- ECS1 至 ECS6 均安装 Tailscale，并加入与 GitLab VM、Mac Studio、ECS4 相同的 tailnet。
- 各节点将 `git.whale-smart.com` 解析到 `100.83.178.99`，直接访问 GitLab VM 的 HTTPS `443` 和 SSH `2222`。
- 每个环境使用自己的 GitLab 账号和 Ed25519 密钥，不与其他环境共用身份；ECS5 的 Agent 账号继续单独保留。
- 不运行 GitLab 核心服务、Runner 或备份服务。
- 不替代 ECS4 的公网入口；公网用户仍由 ECS4 转发。

### 备份目标：roymacbook-pro

- ECS5 不作为备份节点；它只提供自身 Agent 的 GitLab 私网直连。
- `roymacbook-pro` 作为正式远端备份目标，Tailscale 地址为 `100.126.98.93`，接收目录为 `/Users/royzuo/gitlab-backups`。
- GitLab VM 使用专用 Ed25519 密钥，通过 Tailscale SSH 复制；接收目录仅允许目标用户访问。
- Mac Studio 的 4TB LaCie 外置磁盘可保留为人工复制作业的本地第二副本，不承担唯一备份职责，也不阻断正式定时链路。
- 备份目标支持校验、保留和恢复测试；ECS5 不参与。

备份目标的地址、访问链路、容量和恢复记录已补充到相关环境记录，满足“备份必须离开主节点保存”的冻结约束。

## 05. 网络与访问实现

### 私网连接

1. Mac Studio、ECS1 至 ECS6 加入同一个 Tailscale 网络。
2. 使用稳定的 Tailscale 地址或 MagicDNS 名称作为上游地址。
3. ECS4 将公网 Web、HTTPS Git 和 Git SSH 请求转发到 GitLab VM，不使用家庭路由器端口映射。
4. ECS1 至 ECS6 将自身 Git HTTPS/SSH 请求直接发送到 GitLab VM，不经过 ECS4。
5. 备份链路不经过公网入口代理。
6. Tailscale ACL 只允许节点之间访问所需端口。

### Web 与 Git

- 域名 A 记录指向 ECS4 公网 IP。
- ECS4 完成 HTTPS 证书申请、续期和反向代理。
- ECS1 至 ECS6 的本机解析统一为 `100.83.178.99 git.whale-smart.com`，因此它们访问 GitLab 时直接通过各自的 `tailscale0` 到 GitLab VM，不经过 ECS4。
- GitLab VM 在 Tailscale 地址提供 `443/tcp` HTTPS，并反代到 GitLab 容器；Git SSH 继续使用 `2222/tcp`。当前内部路径为 `ECS:443 -> 100.83.178.99:443`、`ECS:2222 -> 100.83.178.99:2222`。
- 公网 DNS 仍指向 ECS4。外部用户继续走 `ECS4:443 -> 100.83.178.99:443`，ECS4 的上游连接通过 Tailscale；ECS4 的默认互联网流量不改变。
- ECS4 的本机解析也统一为 `100.83.178.99`，不再绕行自己的公网地址。正式域名、TLS SNI、Host header 和 GitLab 生成的克隆地址保持一致。
- GitLab 外部 URL 固定使用正式域名，不使用公网 IP 作为长期地址。
- HTTPS Git 使用 GitLab 标准 HTTPS 入口。
- SSH Git 使用独立端口，例如 `git clone ssh://git@domain:2222/group/project.git`；最终端口以 M3 的实际验证结果为准。
- 公网用户端不需要安装 Tailscale；ECS5 作为访问专用节点运行 Tailscale。
- 正式域名、Let's Encrypt HTTPS、HTTPS Git 和 Git SSH 已通过公网验收；Git SSH 使用 ECS4 `2222/tcp`。

### 安全边界

- GitLab VM 不开放公网端口。
- ECS4 管理 SSH 限制可信来源，Git SSH 只转发到 GitLab。
- GitLab 首次登录后修改管理员密码并启用双因素认证。
- Token、密码、私钥和家庭网络凭据不进入仓库。

## 06. 服务与数据实现

### GitLab

- 使用官方 GitLab CE 容器镜像。
- M1 先验证目标镜像在 Linux 容器运行时中的架构和启动行为。
- 为配置、日志和数据设置持久化目录，并验证容器重建后数据仍在。
- 保留 GitLab 版本、镜像摘要、运行时版本和部署配置。
- 使用健康端点、容器状态和登录操作共同判断服务可用。

### Runner 与流水线

- Runner 使用 Docker executor。
- 默认构建架构为 `linux/arm64`；CI 镜像必须明确架构。
- 首个流水线包含测试、构建和制品保存。
- 另做一次失败和修复重跑，确保结果能诊断和追溯。

### 备份与恢复

- 每日执行 GitLab 备份，保留多个历史版本。
- 每日先生成 GitLab 标准备份，再通过 Tailscale 复制到 roymacbook-pro；LaCie 仅作为可选的人工第二副本。
- 每份备份记录时间、版本、大小和校验结果。
- 定期恢复测试项目，确认备份能被读取和实际使用。
- 单独保存入口配置和恢复步骤，避免只备份 GitLab 数据而无法重建访问入口。

## 07. 验收闭环

总体交付必须按以下顺序成立：

1. M1 证明主机、运行时、架构和私网基础可行。
2. M2 证明 GitLab 能登录、保存项目、控制权限并在重启后保留数据。
3. M3 证明外部用户能通过正式域名访问 Web、HTTPS Git 和 SSH Git。
4. M4 证明 Runner 能完成成功、失败、修复重跑、日志和制品保存。
5. M5 证明备份能生成、复制、校验、读取和恢复。
6. M6 按冻结六要素完成全链路复核，并验证 ECS4 转发下的大流量 Git 操作和整理交付证据。

任何一段没有证据，都只能算“已配置”，不能算“交付合格”。

## 08. 方案边界与升级条件

首期交付单节点、低运维、可访问、可构建、可备份的最小闭环。高可用集群、Kubernetes、对象存储、多地域容灾和复杂发布编排不在首期范围内。

只有在资源持续接近上限、家庭网络明显影响工作、Runner 并发不足、公网入口需要切换，或恢复演练不达标时，才启动下一轮方案设计。
