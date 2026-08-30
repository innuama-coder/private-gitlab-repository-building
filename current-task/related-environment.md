---
id: related-environment
title: 相关环境
document_kind: machine-readable-environment-brief
language: zh-CN
version: 1.4
status: agreed
source_of_truth: six-elements.md
frozen_dependency: true
execution_targets:
  - Mac Studio
  - ECS4
access_only_environments:
  - ECS5
---

# 相关环境

## 01. 执行目标总览

| 环境 | 执行定位 | 首期职责 | 是否运行核心服务 |
| --- | --- | --- | --- |
| Mac Studio | 家庭主节点 | GitLab、主要 Runner、仓库数据 | 是 |
| ECS4 | 公网入口节点 | Caddy/Nginx、HTTPS、Git 访问转发 | 否，不保存仓库数据 |
| ECS5 | 私网访问节点 | 仅为自身 Agent 提供 GitLab Tailscale 直连 | 否，不运行核心服务 |

Mac Studio 和 ECS4 通过 Tailscale 组成私网。公网用户只访问 ECS4，ECS4 再把请求转发到 Mac Studio。
ECS5 作为已授权的访问节点，通过 Tailscale 直接访问 Mac Studio；它不是公网入口、核心服务节点或备份目标。

```text
外部用户 -> ECS4 公网入口 -> Tailscale -> Mac Studio GitLab
ECS5 Agent -> Tailscale 点对点 -> Mac Studio GitLab
```

## 02. Mac Studio

### 执行定位

- 首要执行目标。
- 运行 GitLab 单节点服务。
- 运行主要 GitLab Runner。
- 保存 GitLab 仓库、数据库、配置、日志、制品和上传文件。

### 已确认环境

- 设备：Mac Studio，型号标识 `Mac14,14`。
- 系统：macOS `26.5.2`。
- 架构：Apple Silicon。
- CPU：24 核。
- 内存：64GB。
- 内置磁盘：约 926GiB，检查时可用约 736GB。
- 外置磁盘：`LaCie`，4TB HFS+，检查时可用约 2.0TB；作为本地第二份备份。
- Tailscale 地址：`100.65.102.93`。
- Tailscale 名称：`roymac-studio`。
- Docker Desktop：4.44.2，Linux ARM64，GitLab CE 与 ARM64 Runner 正常运行。

### 执行前状态

- 已能通过 Tailscale SSH 访问。
- 尚未确认可直接使用的 Linux 容器运行时；由 M1 安装或确认 Docker Desktop、Colima 或等效运行时。
- GitLab 正式数据目录尚未建立。

### 环境边界

- macOS 是宿主系统，GitLab 必须运行在 Linux 容器环境中。
- 主机必须接电、联网并关闭自动睡眠。
- 不接受家庭路由器端口映射作为公网访问方案。

## 03. ECS4

### 执行定位

- 首要执行目标。
- 公网入口和反向代理节点。
- 接收外部 Web、HTTPS Git 和 Git SSH 请求。
- 通过 Tailscale 将所有外部 Web、HTTPS Git 和 SSH Git 流量转发到 Mac Studio。

### 已确认环境

- 公网 IPv4：`39.105.43.18`。
- 内网 IPv4：`10.0.0.69`。
- 系统：Ubuntu `26.04`。
- 资源：4 vCPU、7.1GiB 内存、59G 根盘。
- 磁盘可用空间：约 46G（检查时）。
- Tailscale 地址：`100.100.85.86`，节点名 `ecs4-gitlab-gateway`。
- Nginx `1.28.3` 已部署；HTTP 反代与 Git SSH TCP 转发配置已加载。
- ECS4 到 Mac Studio 的 Tailscale 上游当前为直连，未走 DERP。
- 公网状态：`80/tcp`、`443/tcp`、`2222/tcp` 均已可达。
- `git.whale-smart.com` A 记录已指向 `39.105.43.18`。
- Let's Encrypt 证书已签发，当前有效期至 `2026-11-28`，Certbot 自动续期和续期模拟均通过。

### 首期部署内容

- Caddy 或 Nginx。
- 域名和 HTTPS 证书。
- Web 与 Git HTTPS 反向代理。
- Git SSH 转发。
- 最小防火墙规则和管理 SSH 来源限制。

### 环境边界

- 不运行 GitLab 核心服务。
- 不保存 GitLab 仓库、数据库或制品。
- 管理 SSH 与 Git SSH 必须使用不冲突的端口规则。
- 公网只开放验收所需端口。
- Tailscale 到 Mac Studio 当前可直连；公网访问仍必须经过 ECS4。
- 云安全组已放行 `80/tcp`、`443/tcp` 和 `2222/tcp`；`22/tcp` 保持管理用途。

## 04. ECS5

### 执行定位

- 访问专用节点，不是 GitLab 部署目标。
- 只为 ECS5 上的 Agent 提供 GitLab 私网访问。
- 不运行 GitLab、Runner 或备份服务。
- 不替代 ECS4 的公网入口。

### 已确认环境

- 系统：Ubuntu `26.04`，x86_64。
- Tailscale 地址：`100.68.48.115`，节点名 `ecs5-gitlab-agent`。
- Mac Studio Tailscale 地址：`100.65.102.93`。
- Tailscale `ping` 已显示到 Mac Studio 的 direct 路径。
- Mac Studio GitLab SSH `2222/tcp` 已从 ECS5 直连验证。
- ECS5 使用独立 GitLab 账号 `agent-ecs5` 和独立 Ed25519 密钥。
- Tailscale 安装后发现 ECS5 原有 `100.100.2.136/100.100.2.138` DNS 与 Tailscale 地址空间冲突；已通过 `/etc/netplan/99-ecs5-public-dns.yaml` 固定使用 `223.5.5.5/223.6.6.6`，公网 DNS 和 HTTPS 已恢复。

### 环境边界

- 只允许访问 Mac Studio GitLab 所需的 Tailscale 端口。
- 不承担公网 Web、HTTPS Git 或公网 SSH Git 入口。
- 不作为 GitLab 仓库、制品或备份数据的存储位置。
- ECS5 的直连配置不改变 ECS4 的公网代理配置。

## 05. 备份环境状态

- ECS5 不作为备份节点；它只提供自身 Agent 的 GitLab 私网直连。
- `roymacbook-pro` 已确定为正式远端备份目标，Tailscale 地址为 `100.126.98.93`，接收目录为 `/Users/royzuo/gitlab-backups`。
- Mac Studio 使用专用 Ed25519 备份密钥，通过 Tailscale SSH 和受限密钥选项复制备份；MacBook 目录权限为仅用户可读写。
- LaCie 可作为人工复制作业的本地第二副本，挂载点为 `/Volumes/LaCie`，可用空间约 2.0TB；正式定时链路不依赖它。
- 远端备份已完成 SHA-256 对比，并在 MacBook 上从备份恢复项目 bundle、执行 `git fsck` 和读取提交记录。

## 06. 非执行环境

### 本地控制环境

- 本地 MacBook、SSH 配置和 GitHub 仓库只用于管理连接、维护文档和记录证据。
- 不在本地控制环境运行 GitLab、Runner 或公网代理。
- 本地环境中的私钥、Token 和密码不得提交到仓库。

### 家庭网络设备

- 家庭路由器不是执行目标。
- 不配置公网端口映射。
- 不依赖家庭公网 IP、动态 DNS 或入站防火墙放行。

### 历史 Docker 环境

- ECS4 上原有的 `agent-*` 容器、Compose 配置和 Docker 数据不属于首期 GitLab 交付物。
- 若执行恢复出厂或清理操作，只清理上述历史环境，不影响本地 SSH 私钥和本仓库文档。

## 07. 执行目标与路线图对应

| 里程碑 | 执行环境 | 主要结果 |
| --- | --- | --- |
| M1 | Mac Studio、ECS4 | 容器运行时、架构、Tailscale 和基础防火墙可行 |
| M2 | Mac Studio | GitLab 核心服务可用 |
| M3 | ECS4、Mac Studio | 公网 Web、HTTPS Git、SSH Git 可用 |
| M4 | Mac Studio | GitLab Runner 和 CI/CD 可用 |
| M5 | Mac Studio、roymacbook-pro；LaCie 为本地副本 | 备份、复制、校验和恢复可用 |
| M6 | 当前全部执行目标及最终确认的备份目标 | 全链路验收和正式交付 |

## 08. 环境使用规则

- 先验证环境，再在对应环境部署职责范围内的服务。
- 任何节点改变角色，都必须先更新总体方案和路线图，并重新检查冻结六要素。
- 只有 Mac Studio 和 ECS4 被列为核心执行目标；ECS5 已明确列为访问专用节点，不作为核心服务或备份的隐含依赖。
- `roymacbook-pro` 是正式远端备份目标，LaCie 是本地第二副本；ECS5 不作为备份目标。
- 环境地址、端口、版本和运行模式以实际验收记录为准，不以历史探测结果代替验收证据。
