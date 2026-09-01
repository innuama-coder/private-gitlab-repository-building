---
id: gitlab-home-deployment-six-elements
title: 家庭 GitLab 部署任务六要素
document_kind: machine-readable-task-brief
language: zh-CN
version: 1.4
status: frozen
frozen_at: 2026-09-01
freeze_note: "迁移完成后重新冻结：GitLab 主服务运行在家庭网络 Proxmox VM 9002，Mac Studio 承担 Runner；后续变更需要显式解冻。"
human_review_sample: ../artifacts/gitlab-home-deployment-human-review-sample.zip
architecture:
  primary_node: Proxmox VM 9002
  runner_node: Mac Studio
  public_entry: ECS4
  private_network: Tailscale
  reverse_proxy: Caddy-or-Nginx
  external_traffic_path: public-through-ECS4-to-vm; ecs1-ecs6-direct-through-Tailscale-to-vm
  direct_server_nodes: ECS1-ECS6
  gitlab_tailscale_ip: 100.83.178.99
  legacy_node: Mac Studio
  legacy_node_role: rollback-only
  backup_node: roymacbook-pro
  acceptance_model: single-direct-route-standard
---

# 家庭 GitLab 部署任务六要素

## 01. 目标

### 目标陈述

在家庭网络内建立一套可长期使用的 GitLab，提供代码托管、协作评审和基础 CI/CD 能力。GitLab 主服务运行在 Proxmox VM `9002`（`192.168.101.202`，Tailscale 地址 `100.83.178.99`），Mac Studio 承担主要 Runner。公网用户继续通过 ECS4 公网入口访问；ECS1 至 ECS6 遇到 `git.whale-smart.com` 时，直接解析到 VM 的 Tailscale 地址，不经过 ECS4。家庭网络不配置 GitLab 公网端口映射。

### 能力范围

- 代码托管：私有仓库、用户登录、权限管理。
- 协作能力：Issue、Merge Request、代码评审。
- 自动化：GitLab CI/CD 与 Runner 执行任务。

## 02. 工作方法

### 实施顺序

1. 在 Proxmox VM `9002` 准备 Linux 容器运行环境和持久化数据盘。
2. 在 VM 上部署 GitLab，并在 Mac Studio 保留主要 Runner。
3. 在 GitLab VM、Mac Studio 与 ECS1 至 ECS6 之间建立 Tailscale 连接。
4. 在 GitLab VM 提供 Tailscale 地址上的 HTTPS `443/tcp` 和 Git SSH `2222/tcp`。
5. 在 ECS1 至 ECS6 配置 `git.whale-smart.com -> 100.83.178.99`，让服务器 Git 流量直接走 Tailscale。
6. 保留 ECS4 公网入口，将外部 HTTPS 和 SSH Git 请求经 Tailscale 转发到 GitLab VM。
7. 配置 HTTPS、Git over HTTPS，以及标准 SSH 克隆和推送。
8. 创建示例仓库，验证测试、构建、制品保存、备份和恢复。

### 工作原则

- 每一步都留下可复查的配置和结果。
- 先验证运行基础和私网，再部署核心服务，最后开放公网并验证流水线。
- 首期优先使用简单、低运维的单节点方案。

## 03. 边界

### 包含

- 单节点 GitLab，运行在 Proxmox VM `9002`。
- 一个主要 GitLab Runner，运行在 Mac Studio。
- ECS4 公网入口。
- ECS1 至 ECS6 通过 Tailscale 直连 GitLab VM 的 Web、HTTPS Git 和 Git SSH 访问。
- 外部用户通过 ECS4 公网入口访问 GitLab，ECS4 只做转发。
- HTTPS、SSH 和 HTTPS Git 访问。
- 基础备份与恢复验证。
- 个人或小团队使用所需的仓库、权限、Issue 和 Merge Request。

### 不包含

- 高可用集群。
- Kubernetes。
- 独立数据库集群。
- 对象存储和多地域容灾。
- 复杂发布编排。

## 04. 约束

- GitLab VM 必须保持运行、接入家庭局域网，并由 Proxmox 配置开机启动；Mac Studio 需保持接电、联网并关闭自动睡眠以运行 Runner。
- 网络中断或 VM 重启后，GitLab 容器应能自动恢复。
- 公网访问依赖 ECS4 公网 IP、域名解析和 Tailscale；ECS4 停机会导致公网入口不可用，但不阻断 ECS1 至 ECS6 已配置的 Tailscale 直连。
- ECS4 只做公网流量转发，不保存或缓存 GitLab 仓库、制品和备份数据；经 ECS4 的大流量 Git 操作必须验证流式转发能力。
- GitLab VM 使用 x86_64；Runner 运行在 Apple Silicon Mac Studio，CI 镜像架构必须按 Job 实际环境验证。
- GitLab 仓库数据保存在 VM 的 `/srv/gitlab`；备份必须复制到另一处，不能只保存在同一故障域。
- ECS1 至 ECS6 只作为 GitLab 私网访问节点，不运行 GitLab 核心服务、不作为备份目标；ECS4 额外承担公网入口职责。

### 已确认条件

- Proxmox VM `9002`：`8 vCPU`、`16GB RAM`，数据盘约 `1TB`，挂载 `/srv/gitlab`。
- GitLab VM：Tailscale 地址 `100.83.178.99`，GitLab CE `19.3.1`，容器状态 `healthy`。
- Mac Studio：24 核 CPU、64GB 内存，运行主要 ARM64 Runner，Tailscale 地址 `100.65.102.93`。
- ECS5：Tailscale 地址为 `100.68.48.115`，已能 direct 连接 GitLab VM 的 `2222/tcp`。
- ECS1 至 ECS6：`git.whale-smart.com` 必须解析为 `100.83.178.99`，并通过各自的 `tailscale0` 访问 GitLab VM 的 `443/2222`。

## 05. 交付物

- `artifacts/gitlab-home-deployment-human-review-sample.zip`
  - 解压后可直接打开 `index.html` 阅读。
  - 包含内网机械鲸鱼 Logo 与 `KUNORA.internal` 文字 Logo 资产。
- Proxmox VM `9002` 上运行的 GitLab 服务及 `/srv/gitlab` 持久化目录。
- Mac Studio 上的 GitLab Runner 与示例流水线。
- ECS4 上的公网反向代理配置。
- GitLab VM Tailscale HTTPS `443/tcp` 与 Git SSH `2222/tcp` 配置。
- ECS1 至 ECS6 的 GitLab 域名直连解析配置和逐台验收记录。
- 域名、HTTPS 与访问策略。
- Git SSH / HTTPS 访问说明。
- 备份、恢复和日常维护说明。

## 06. 验收标准与方法

### 本次网络改动的唯一验收标准

ECS1 至 ECS6 访问 `git.whale-smart.com` 时，无论使用 HTTP、HTTPS 还是 Git SSH，都必须直接连接 GitLab VM，不经过 ECS4 公网 IP；各节点访问互联网的默认路由仍保持不变。

验收方法：在 ECS1 至 ECS6 分别检查域名解析、`80/443/2222` 连接和实际路由。HTTP 应返回 GitLab 到 HTTPS 的 `301`，HTTPS 应返回 GitLab 响应，SSH `2222/tcp` 应返回 GitLab SSH banner；到 `100.83.178.99` 的路由必须使用 `tailscale0`，到互联网的默认路由必须使用各自 `eth0`。以上六台全部通过，才算本次网络改动合格。

### 访问与身份

- 从外部网络打开 GitLab 域名。
- HTTPS 证书有效。
- 管理员账号可以登录。
- Mac Studio 不需要直接暴露公网端口。

### Git 操作

- 创建私有项目。
- 通过 SSH 完成 `clone`、`push`、`pull`。
- ECS1 至 ECS6 通过 Tailscale 直连完成 GitLab HTTPS/SSH `clone`、`push`、`pull`，且不经过 ECS4。
- 通过 HTTPS 完成 `clone`、`push`、`pull`。
- 测试账号只能访问被授权的项目。

### CI/CD

- 提交示例代码后，Runner 自动执行 GitLab CI 流水线。
- 流水线能返回成功，并保留构建日志。
- 人为制造一次失败，能看到失败日志。
- 修复后重新运行，流水线能成功。
- 能保存并读取示例制品。

### 可靠性与恢复

- 手动执行一次备份。
- 确认备份文件可读取，并能恢复到测试位置。
- 重启 GitLab 容器和 VM，服务能自动恢复；Mac Studio Runner 能重新连接。
- 暂时断开 Tailscale，公网入口明确不可用；恢复连接后能自动恢复。

### 验收证据

- 保留外部访问截图或命令输出。
- 保留 SSH 与 HTTPS Git 操作记录。
- 保留流水线编号、日志和制品记录。
- 保留备份文件位置与恢复结果。
- 保留 ECS4 转发链路、大流量 Git 操作记录，以及 ECS1 至 ECS6 的直接 Tailscale 路径记录。
