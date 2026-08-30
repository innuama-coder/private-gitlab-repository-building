---
id: overall-solution
title: 总体方案
document_kind: machine-readable-solution-brief
language: zh-CN
version: 3.4
status: feasibility-reviewed
source_of_truth: six-elements.md
environment_reference: related-environment.md
frozen_dependency: true
feasibility: feasible-with-gates
feasibility_gate: M1
feasibility_gates:
  - M1
  - M3
  - M5
primary_node: Mac Studio
public_entry_node: ECS4
backup_node: roymacbook-pro
deferred_node: ECS5
private_network: Tailscale
---

# 总体方案

## 01. 可行性结论

方案对个人或小团队使用可行，但不是无条件可行。Mac Studio 的 CPU、内存和磁盘明显足够；真正的前置风险有四项：macOS 不是 GitLab 的运行系统，需要 Linux 容器运行时；Mac Studio 使用 Apple Silicon，GitLab 核心镜像的实际架构必须验证；ECS4 的管理 SSH 与 Git SSH 必须采用不冲突的入口规则；ECS4 公网带宽和家庭上行带宽必须能承载 Web、Git 和制品传输。

M1 是硬门槛。只有在 Mac Studio 上完成 Linux 运行时、GitLab 镜像、持久化目录、重启恢复和健康检查验证后，才允许进入正式部署。若原生 ARM64 镜像不可用，可以在小规模试用条件下验证 `linux/amd64` 兼容运行；验证不通过时，不能把方案标记为可交付。

M3 也是公网访问门槛。只有在 ECS4 的带宽、端口、HTTPS、Web、HTTPS Git、SSH Git 和大流量 Git 转发均通过实测后，才允许把公网入口标记为可交付。

## 02. 目标到实现的对应关系

| 冻结目标 | 实现方式 | 合格证据 |
| --- | --- | --- |
| 代码托管 | Mac Studio 运行单节点 GitLab，数据保存到独立持久化目录 | 私有项目、仓库和重启后数据 |
| 协作评审 | GitLab 项目权限、Issue 和 Merge Request | 测试账号权限记录、评审记录 |
| CI/CD | GitLab Runner 执行 ARM64 优先的示例流水线 | 成功/失败/重跑日志、制品 |
| 外部访问 | 所有外部 Web、HTTPS Git 和 SSH Git 流量经 ECS4 公网反向代理，再经 Tailscale 转发到 Mac Studio | 域名、证书、SSH/HTTPS Git 记录和转发验证 |
| 可恢复运行 | GitLab 备份复制到 M5 内确定的独立备份目标，执行恢复和重启演练 | 备份文件、校验、恢复结果 |

## 03. 部署拓扑

```text
外部用户
  |  HTTPS / Git SSH
  v
ECS4 公网入口
  |  Tailscale 私网
  v
Mac Studio
  |-- GitLab Web / Git HTTPS / Git SSH
  |-- GitLab Runner
  |-- GitLab 持久化数据
```

## 04. 节点职责

### Mac Studio：核心服务节点

- 运行 Docker Desktop、Colima 或等效 Linux 容器运行时；不把 macOS 当作 GitLab 运行系统。
- 运行 GitLab 单节点服务和主要 Runner。
- 将配置、日志、仓库、数据库、制品和上传文件放进稳定的持久化目录。
- 配置容器自动启动、健康检查、主机不自动睡眠和重启恢复。
- 只允许本机和 Tailscale 私网访问 GitLab 管理端口。

Mac Studio 已确认具备 24 核 CPU、64GB 内存和约 736GB 可用磁盘，资源满足首期条件。Apple Silicon 只保证主机资源充足，不自动保证每个 GitLab 或 CI 镜像原生支持 ARM64，因此架构验证属于 M1 和 M4 的必验项。

### ECS4：公网入口节点

- 保留固定公网 IP，开放 80、443，以及 Git SSH 所需入口。
- 运行 Caddy 或 Nginx，负责域名、HTTPS 证书和反向代理。
- 通过 Tailscale 将所有外部 Web 和 Git HTTPS 请求转发到 Mac Studio。
- 将所有外部 Git SSH 请求转发到 GitLab SSH 服务。
- 对 Git 大流量使用流式转发，不启用会把请求体或响应体落盘的缓存。
- 不保存 GitLab 仓库和核心业务数据。

ECS4 的管理员 SSH 和 Git SSH 必须分离：优先保留 22 端口用于管理，Git 使用独立端口并在域名或 Git 配置中声明；若使用同一端口，必须使用已经验证的 SSH 转发方案，不得靠未验证的端口复用假设交付。

### 备份目标：roymacbook-pro

- ECS5 暂不引入，不作为首期备份节点。
- `roymacbook-pro` 作为正式远端备份目标，Tailscale 地址为 `100.126.98.93`，接收目录为 `/Users/royzuo/gitlab-backups`。
- Mac Studio 使用专用 Ed25519 密钥，通过 Tailscale SSH 复制；接收目录仅允许目标用户访问。
- Mac Studio 的 4TB LaCie 外置磁盘可保留为人工复制作业的本地第二副本，不承担唯一备份职责，也不阻断正式定时链路。
- 备份目标支持校验、保留和恢复测试；ECS5 不参与。

备份目标的地址、访问链路、容量和恢复记录已补充到相关环境记录，满足“备份必须离开主节点保存”的冻结约束。

## 05. 网络与访问实现

### 私网连接

1. Mac Studio 和 ECS4 加入同一个 Tailscale 网络。
2. 使用稳定的 Tailscale 地址或 MagicDNS 名称作为上游地址。
3. ECS4 将所有外部 Web、HTTPS Git 和 Git SSH 请求转发到 Mac Studio，不使用家庭路由器端口映射。
4. 备份链路不经过公网入口代理。
5. Tailscale ACL 只允许节点之间访问所需端口。

### Web 与 Git

- 域名 A 记录指向 ECS4 公网 IP。
- ECS4 完成 HTTPS 证书申请、续期和反向代理。
- GitLab 外部 URL 固定使用正式域名，不使用公网 IP 作为长期地址。
- HTTPS Git 使用 GitLab 标准 HTTPS 入口。
- SSH Git 使用独立端口，例如 `git clone ssh://git@domain:2222/group/project.git`；最终端口以 M3 的实际验证结果为准。
- 用户端不需要安装 Tailscale；Tailscale 只运行在 ECS4 与 Mac Studio 之间。
- 正式域名、Let's Encrypt HTTPS、HTTPS Git 和 Git SSH 已通过公网验收；Git SSH 使用 ECS4 `2222/tcp`。

### 安全边界

- Mac Studio 不开放公网端口。
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
