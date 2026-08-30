---
id: gitlab-home-deployment-six-elements
title: 家庭 GitLab 部署任务六要素
document_kind: machine-readable-task-brief
language: zh-CN
version: 1.0
status: agreed
human_review_sample: ../artifacts/gitlab-home-deployment-human-review-sample.zip
architecture:
  primary_node: Mac Studio
  public_entry: ECS4
  private_network: Tailscale
  reverse_proxy: Caddy-or-Nginx
  secondary_node: ECS5
  secondary_node_role: reserved-for-backup-or-secondary-runner
---

# 家庭 GitLab 部署任务六要素

## 01. 目标

### 目标陈述

在家里的 Mac Studio 上建立一套可长期使用的 GitLab，提供代码托管、协作评审和基础 CI/CD 能力；通过 ECS4 提供公网入口，通过 Tailscale 连接家庭网络，Mac Studio 不直接暴露在公网。

### 能力范围

- 代码托管：私有仓库、用户登录、权限管理。
- 协作能力：Issue、Merge Request、代码评审。
- 自动化：GitLab CI/CD 与 Runner 执行任务。

## 02. 工作方法

### 实施顺序

1. 在 Mac Studio 上准备 Linux 容器运行环境。
2. 在 Mac Studio 上部署 GitLab 和 Runner。
3. 在 Mac Studio 与 ECS4 之间建立 Tailscale 私网连接。
4. 在 ECS4 上配置 Caddy 或 Nginx，将域名请求转发到 Mac Studio。
5. 配置 HTTPS、Git over HTTPS，以及标准 SSH 克隆和推送。
6. 创建示例仓库，验证测试、构建、制品保存、备份和恢复。

### 工作原则

- 每一步都留下可复查的配置和结果。
- 先打通访问，再部署服务，最后验证流水线。
- 首期优先使用简单、低运维的单节点方案。

## 03. 边界

### 包含

- 单节点 GitLab。
- 一个主要 GitLab Runner。
- ECS4 公网入口。
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
- 外部访问依赖 ECS4 公网 IP、域名解析和 Tailscale；ECS4 停机会导致公网入口不可用。
- Mac Studio 使用 Apple Silicon；CI 镜像优先使用 ARM64，使用 amd64 时必须显式验证兼容性。
- GitLab 仓库数据保存在 Mac Studio；备份必须复制到另一处，不能只保存在同一块硬盘。
- ECS5 首期不参与部署，保留作备份机或第二个 Runner 的候选节点。

### 已确认条件

- Mac Studio：24 核 CPU。
- Mac Studio：64GB 内存。
- Mac Studio：约 736GB 可用磁盘。
- Mac Studio：已能通过 Tailscale SSH 访问，Tailscale 地址为 `100.65.102.93`。

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

