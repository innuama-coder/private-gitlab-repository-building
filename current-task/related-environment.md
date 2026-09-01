---
id: related-environment
title: 相关环境
document_kind: machine-readable-environment-brief
language: zh-CN
version: 1.8
status: verified
verified_at: 2026-09-01
source_of_truth: six-elements.md
frozen_dependency: true
execution_targets:
  - Proxmox host
  - GitLab VM 9002
  - Mac Studio
  - ECS1
  - ECS2
  - ECS3
  - ECS4
  - ECS5
  - ECS6
---

# 相关环境

## 01. 执行目标总览

| 环境 | 执行定位 | 当前职责 | 是否运行核心服务 |
| --- | --- | --- | --- |
| Proxmox VM `9002` | GitLab 主节点 | GitLab、仓库数据、数据库、配置、日志、制品 | 是 |
| Mac Studio | Runner 与回退节点 | 主要 Runner；保留迁移前 GitLab 数据 | Runner 是；旧 GitLab 否 |
| ECS4 | 公网入口 | HTTPS、HTTP、Git SSH 转发 | 否 |
| ECS1-ECS6 | 私网访问节点 | `git.whale-smart.com` 直达 GitLab VM | 否 |
| `roymacbook-pro` | 独立备份目标 | 接收和校验 GitLab 备份 | 否 |

```text
外部用户 -> ECS4 公网入口 -> Tailscale -> GitLab VM 9002
ECS1 至 ECS6 -> Tailscale 点对点 -> GitLab VM 9002
Mac Studio Runner -> 正式域名 -> GitLab VM 9002
```

## 02. Proxmox 与 GitLab VM

### Proxmox 主机

- 管理地址：`192.168.101.201` / `192.168.101.203`。
- GitLab VM：`9002`。
- Proxmox 负责 VM 生命周期；不直接运行 GitLab 容器。

### GitLab VM 9002

- 主机名：`gitlab`。
- 局域网地址：`192.168.101.202`。
- Tailscale 地址：`100.83.178.99`，节点名 `gitlab-vm`。
- 资源：`8 vCPU / 16GB RAM`。
- 数据盘：约 `1TB`，挂载到 `/srv/gitlab`。
- 系统默认互联网出口：`192.168.101.1` 经 `eth0`；不使用 Exit Node。
- GitLab CE：`19.3.1`，Docker 容器名 `gitlab`，`restart: always`。
- 端口：HTTP `80/tcp`、HTTPS `443/tcp`、Git SSH `2222/tcp`。
- 持久化目录：`/srv/gitlab/config`、`/srv/gitlab/logs`、`/srv/gitlab/data`、`/srv/gitlab/backups`。
- Compose 文件：`/srv/gitlab/docker-compose.yml`。

### 已验证状态

- 容器状态为 `healthy`，Docker 服务为 `enabled/active`。
- 2026-09-01 执行容器重启，约 70 秒恢复到 `running healthy`，登录页返回 `200`。
- 数据库和 6 个项目已恢复；用户、管理员、SSH 主机密钥、TLS 证书和 GitLab secrets 已迁移。
- GitLab VM 不接受家庭路由器公网端口映射；公网访问只通过 ECS4。

## 03. Mac Studio

- 设备：Mac Studio `Mac14,14`，Apple Silicon，24 核 CPU、64GB 内存。
- Tailscale 地址：`100.65.102.93`，节点名 `roymac-studio`。
- 当前职责：运行 GitLab Runner `mac-studio-arm64`，使用 Docker executor。
- 2026-09-01 的真实流水线 `#6` 已由该 Runner 完成，`test`、`build` 均为 `success`；临时失败恢复验收为 `#9` 失败、`#10` 修复后成功。
- 迁移前 GitLab 数据和原实例保持原样，至少观察 7 天；未确认新实例稳定前不删除。
- 旧实例只用于回退，不接收当前正式流量，不与新实例双写。

## 04. ECS4 公网入口

- 公网 IPv4：`39.105.43.18`；内网 IPv4：`10.0.0.69`。
- Tailscale 地址：`100.100.85.86`，节点名 `ecs4-gitlab-gateway`。
- 公共 DNS：`git.whale-smart.com` A 记录仍指向 `39.105.43.18`。
- 公网入口：`80/tcp`、`443/tcp`、`2222/tcp`；管理 SSH 保留 `22/tcp`。
- Nginx HTTPS 上游：`https://100.83.178.99:443`。
- Nginx Git SSH TCP 上游：`100.83.178.99:2222`。
- ECS4 到 GitLab VM 的 Tailscale 路径已验证为 direct。
- ECS4 只转发流量，不保存仓库、数据库、制品或备份。
- 切换前配置备份保存在 `/etc/nginx/config-backups/`。

## 05. ECS1 至 ECS6

- 六台均已加入同一 tailnet，并将 `git.whale-smart.com` 解析为 `100.83.178.99`。
- 六台到 GitLab VM 的路由均使用 `tailscale0`；到互联网的默认路由仍使用各自 `eth0`。
- 六台均通过 HTTP `301`、HTTPS `200`、SSH `2222/tcp` banner 和 direct path 验收。
- 每个环境继续使用独立 GitLab Agent 账号和独立 Ed25519 密钥。
- ECS5 Tailscale 地址为 `100.68.48.115`；DNS 固定为 `223.5.5.5/223.6.6.6`，公网访问正常。
- 2026-09-01，ECS5 的 `kunora` 完成 SSH `clone`、分支 `push`、第二工作副本 `pull`，随后删除验收分支。
- ECS5 的 `kunora` 已验证可写 `/srv/reports/`。
- ECS1 至 ECS6 不运行 GitLab 核心服务，也不作为备份目标。

## 06. 备份与回退

- 迁移备份：`1788237582_2026_09_01_19.3.1_gitlab_backup.tar`。
- SHA-256：`376afcba7779ae30d8812fca6086dcb56b84887f917a9916ac8deb9a6662394d`。
- 独立备份目标：`roymacbook-pro`，Tailscale 地址 `100.126.98.93`，接收目录 `/Users/royzuo/gitlab-backups`。
- GitLab VM 的正式定时备份必须复制到独立目标，并保持与 `/srv/gitlab` 不同的故障域。
- Mac Studio 原 GitLab 数据是迁移回退副本，不代替正式的长期备份策略。
- ECS5 明确不作为备份目标。

## 07. 验收标准

ECS1 至 ECS6 访问 `git.whale-smart.com` 的 HTTP、HTTPS 和 Git SSH，均直接连接 `100.83.178.99`，不经过 ECS4 公网 IP；到 GitLab VM 使用 `tailscale0`，到互联网仍使用各自 `eth0`。

公网用户通过 ECS4 访问正式域名；ECS4 的 HTTPS 和 SSH 上游均为 GitLab VM。GitLab 容器重启后自动恢复，Mac Studio Runner 能继续执行流水线。

## 08. SSH 与安全边界

- 本地 MacBook、Mac Studio、ECS1 至 ECS6、`vircs-dev` 和 `vircs-windows-runner` 使用 `kunora` 用户组成 SSH 互信网。
- 每个环境持有独立私钥，只交换公钥；SSH 互信不自动赋予 `root`、`sudo` 或 GitLab 管理员权限。
- 密码、Token、私钥、GitLab secrets 和 TLS 私钥不得进入仓库。
- GitLab VM 管理入口经局域网或受控跳板访问，业务入口只使用正式域名。
