---
id: gitlab-home-deployment-six-elements
title: 家庭 GitLab 部署任务六要素
document_kind: machine-readable-task-brief
language: zh-CN
version: 1.2
status: frozen
frozen_at: 2026-08-30
freeze_note: "补充 ECS5 仅供自身使用的 Tailscale 直连路径后重新冻结，后续变更需要显式解冻。"
human_review_sample: ../artifacts/gitlab-home-deployment-human-review-sample.zip
architecture:
  primary_node: Mac Studio
  public_entry: ECS4
  private_network: Tailscale
  reverse_proxy: Caddy-or-Nginx
  external_traffic_path: public-through-ECS4; ecs5-direct-through-Tailscale
  secondary_node: ECS5
  secondary_node_role: access-only-direct-agent
---

# 家庭 GitLab 部署任务六要素

## 01. 目标

### 目标陈述

在家里的 Mac Studio 上建立一套可长期使用的 GitLab，提供代码托管、协作评审和基础 CI/CD 能力；公网用户的 Web、HTTPS Git 和 SSH Git 流量统一经过 ECS4 公网入口，再通过 Tailscale 连接到 Mac Studio，Mac Studio 不直接暴露在公网。已授权的 ECS5 只为自身 Git 操作增加 Tailscale 点对点直连，不改变公网访问路径。

### 能力范围

- 代码托管：私有仓库、用户登录、权限管理。
- 协作能力：Issue、Merge Request、代码评审。
- 自动化：GitLab CI/CD 与 Runner 执行任务。

## 02. 工作方法

### 实施顺序

1. 在 Mac Studio 上准备 Linux 容器运行环境。
2. 在 Mac Studio 上部署 GitLab 和 Runner。
3. 在 Mac Studio 与 ECS4 之间建立 Tailscale 私网连接。
4. 在 ECS4 上配置 Caddy 或 Nginx，将所有外部 Web、HTTPS Git 和 SSH Git 请求转发到 Mac Studio。
5. 在 ECS5 上配置 Tailscale 直连 Mac Studio，并让 ECS5 使用自己的 GitLab 账号和密钥访问 GitLab。
6. 配置 HTTPS、Git over HTTPS，以及标准 SSH 克隆和推送。
7. 创建示例仓库，验证测试、构建、制品保存、备份和恢复。

### 工作原则

- 每一步都留下可复查的配置和结果。
- 先验证运行基础和私网，再部署核心服务，最后开放公网并验证流水线。
- 首期优先使用简单、低运维的单节点方案。

## 03. 边界

### 包含

- 单节点 GitLab。
- 一个主要 GitLab Runner。
- ECS4 公网入口。
- 所有外部 Web、HTTPS Git 和 SSH Git 流量经 ECS4 转发。
- ECS5 自身通过 Tailscale 直连 Mac Studio 的 Git SSH 访问。
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

- Mac Studio 必须保持接电、联网，并关闭系统自动睡眠。
- 网络中断后，相关容器和服务应能自动恢复。
- 公网访问依赖 ECS4 公网 IP、域名解析和 Tailscale；ECS4 停机会导致公网入口不可用，但不阻断已授权 ECS5 的 Tailscale 直连。
- ECS4 只做公网流量转发，不保存或缓存 GitLab 仓库、制品和备份数据；经 ECS4 的大流量 Git 操作必须验证流式转发能力。
- Mac Studio 使用 Apple Silicon；CI 镜像优先使用 ARM64，使用 amd64 时必须显式验证兼容性。
- GitLab 仓库数据保存在 Mac Studio；备份必须复制到另一处，不能只保存在同一块硬盘。
- ECS5 只作为已授权的 GitLab 私网访问节点，不运行 GitLab 核心服务、不作为备份目标、不承担公网入口，也不改变 ECS4 的职责。

### 已确认条件

- Mac Studio：24 核 CPU。
- Mac Studio：64GB 内存。
- Mac Studio：约 736GB 可用磁盘。
- Mac Studio：已能通过 Tailscale SSH 访问，Tailscale 地址为 `100.65.102.93`。
- ECS5：Tailscale 地址为 `100.68.48.115`，已能 direct 连接 Mac Studio 的 `2222/tcp`。

## 05. 交付物

- `artifacts/gitlab-home-deployment-human-review-sample.zip`
  - 解压后可直接打开 `index.html` 阅读。
  - 包含内网机械鲸鱼 Logo 与 `KUNORA.internal` 文字 Logo 资产。
- Mac Studio 上运行的 GitLab 服务。
- GitLab Runner 与示例流水线。
- ECS4 上的公网反向代理配置。
- 域名、HTTPS 与访问策略。
- Git SSH / HTTPS 访问说明。
- 备份、恢复和日常维护说明。

## 06. 验收标准与方法

### 访问与身份

- 从外部网络打开 GitLab 域名。
- HTTPS 证书有效。
- 管理员账号可以登录。
- Mac Studio 不需要直接暴露公网端口。

### Git 操作

- 创建私有项目。
- 通过 SSH 完成 `clone`、`push`、`pull`。
- ECS5 通过 Tailscale 直连完成 GitLab SSH `clone`、`push`、`pull`，且不经过 ECS4。
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
- 重启 Mac Studio 和相关容器，服务能自动恢复。
- 暂时断开 Tailscale，公网入口明确不可用；恢复连接后能自动恢复。

### 验收证据

- 保留外部访问截图或命令输出。
- 保留 SSH 与 HTTPS Git 操作记录。
- 保留流水线编号、日志和制品记录。
- 保留备份文件位置与恢复结果。
- 保留 ECS4 转发链路和大流量 Git 操作记录。
