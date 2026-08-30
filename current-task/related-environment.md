---
id: related-environment
title: 相关环境
document_kind: machine-readable-environment-brief
language: zh-CN
version: 1.0
status: agreed
source_of_truth: six-elements.md
frozen_dependency: true
execution_targets:
  - Mac Studio
  - ECS4
---

# 相关环境

## 01. 执行目标总览

| 环境 | 执行定位 | 首期职责 | 是否运行核心服务 |
| --- | --- | --- | --- |
| Mac Studio | 家庭主节点 | GitLab、主要 Runner、仓库数据 | 是 |
| ECS4 | 公网入口节点 | Caddy/Nginx、HTTPS、Git 访问转发 | 否，不保存仓库数据 |

Mac Studio 和 ECS4 通过 Tailscale 组成私网。公网用户只访问 ECS4，ECS4 再把请求转发到 Mac Studio。

```text
外部用户 -> ECS4 公网入口 -> Tailscale -> Mac Studio GitLab
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
- 磁盘：约 926GiB，总可用空间约 736GB（检查时）。
- Tailscale 地址：`100.65.102.93`。
- Tailscale 名称：`roymac-studio`。

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
- 通过 Tailscale 将必要流量转发到 Mac Studio。

### 已确认环境

- 公网 IPv4：`39.105.43.18`。
- 内网 IPv4：`10.0.0.69`。
- 系统：Ubuntu `26.04`。
- 资源：4 vCPU、7.1GiB 内存、59G 根盘。
- 磁盘可用空间：约 46G（检查时）。

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

## 04. 备份环境状态

- 首期不引入额外执行节点。
- 冻结六要素仍要求备份离开 Mac Studio 保存。
- 独立备份目标必须在 M5 开始前确定并完成验收。
- 备份目标确定前，不能把备份与恢复能力标记为已交付。

## 05. 非执行环境

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

## 06. 执行目标与路线图对应

| 里程碑 | 执行环境 | 主要结果 |
| --- | --- | --- |
| M1 | Mac Studio、ECS4 | 容器运行时、架构、Tailscale 和基础防火墙可行 |
| M2 | Mac Studio | GitLab 核心服务可用 |
| M3 | ECS4、Mac Studio | 公网 Web、HTTPS Git、SSH Git 可用 |
| M4 | Mac Studio | GitLab Runner 和 CI/CD 可用 |
| M5 | Mac Studio、待确定的独立备份目标 | 备份、复制、校验和恢复可用 |
| M6 | 当前全部执行目标及已确认的备份目标 | 全链路验收和正式交付 |

## 07. 环境使用规则

- 先验证环境，再在对应环境部署职责范围内的服务。
- 任何节点改变角色，都必须先更新总体方案和路线图，并重新检查冻结六要素。
- 只有 Mac Studio 和 ECS4 被列为当前执行目标；其他机器不作为隐含依赖。
- 备份目标在 M5 前单独确认，不把未确认的机器作为默认目标。
- 环境地址、端口、版本和运行模式以实际验收记录为准，不以历史探测结果代替验收证据。
