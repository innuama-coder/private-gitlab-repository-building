---
id: team-network-environment-baseline
title: Team Network 环境基线
document_kind: environment-baseline
language: zh-CN
version: 1.4
status: verified
verified_at: 2026-08-31
---

# Team Network 环境基线

## 1. 记录原则

本文只记录已经核实的环境事实，不代表目标架构已经落地。目标架构、迁移顺序和验收要求见 `overall-design.md`。

## 2. 核心服务

| 服务 | 当前节点 | 当前域名 | 当前访问方式 | 核实结果 |
| --- | --- | --- | --- | --- |
| GitLab CE | Proxmox VM `9002` | `git.whale-smart.com` | ECS1-ECS6 经 Tailscale 直连；公网用户经 ECS4 转发 | 已运行 |
| GitLab Runner | Mac Studio | 不适用 | GitLab 内部注册 | 已运行 |
| Wiki（BookStack） | ECS3 | `wiki.whale-smart.com` | ECS3 Caddy 公网入口 | 已运行 |
| 远程 Agent | ECS2 等现有环境 | 按现有配置 | 保持现状，逐台纳入 | 不在本次基线中重建 |

### Wiki 核实证据

- ECS3 主机名：`iZ6wed0d2mou4kz5jes8wtZ`。
- ECS3 公网 IPv4：`8.221.138.205`。
- 公共 DNS 查询结果：`wiki.whale-smart.com` 的 A 记录为 `8.221.138.205`。
- ECS3 正在运行 `internal-wiki-bookstack-1`、`internal-wiki-caddy-1`、`internal-wiki-wiki-api-1` 和 `internal-wiki-mariadb-1` 等容器。
- Caddy 监听 `80/tcp` 和 `443/tcp`。
- 在 ECS3 本机以 `wiki.whale-smart.com` 访问 HTTPS，返回 `302` 并跳转到 `https://wiki.whale-smart.com/login`。

结论：Wiki 确认位于 ECS3，正式域名为 `wiki.whale-smart.com`。

## 3. 节点资源与现状

| 节点 | 计算资源 | 根盘 | 当前主要职责 | Tailscale 状态 |
| --- | --- | --- | --- | --- |
| GitLab VM `9002` | 8 vCPU、16GB 内存 | 数据盘约 1TB，挂载 `/srv/gitlab` | GitLab CE、仓库和核心数据 | 已加入，`100.83.178.99` |
| Mac Studio | 24 CPU、64GB 内存 | 内置盘约 926GiB；另有 4TB LaCie | Runner、迁移回退副本 | 已加入，`100.65.102.93` |
| ECS1 | 8 vCPU、约 15GB 内存 | 40GB | 暂无核心服务 | 已加入，`100.118.86.59` |
| ECS2 | 4 vCPU、约 7GB 内存 | 59GB | Authentik、Agent CLI | 已加入，`100.85.211.101` |
| ECS3 | 4 vCPU、约 7GB 内存 | 59GB | Wiki、Wiki API、Spec Execution | 已加入，`100.115.38.3` |
| ECS4 | 4 vCPU、约 7GB 内存 | 59GB | GitLab 公网入口 | 已加入，`100.100.85.86` |
| ECS5 | 4 vCPU、约 7GB 内存 | 59GB | GitLab Agent 私网访问 | 已加入，`100.68.48.115` |
| ECS6 | 4 vCPU、约 7GB 内存 | 99GB | Docker、Nginx | 已加入，`100.106.135.75` |

已知公网地址：ECS1 `39.107.81.166`、ECS2 `8.221.136.35`、ECS3 `8.221.138.205`、ECS4 `39.105.43.18`、ECS5 `47.93.189.15`、ECS6 `112.126.76.80`。

## 4. 当前 Tailscale 网络

- 当前 tailnet 由个人身份 `kins@live.cn` 持有，不作为公司网络的长期治理方案。
- 已知节点：GitLab VM、Mac Studio、ECS1 至 ECS6，以及一台 MacBook。
- ECS1 至 ECS6 到 GitLab VM 均已验证 Tailscale 可达；当前 GitLab 端口访问走各自 `tailscale0`，Tailscale 仍会在直连不可用时自动使用 DERP 中继。
- ECS5 曾因云厂商 DNS `100.100.2.136/100.100.2.138` 与 Tailscale 地址空间冲突而失去公网解析，现已改用 `223.5.5.5/223.6.6.6`。
- MacBook 当前 Tailscale 已停止，且留有旧的 Exit Node 偏好；重新纳入前必须清理旧设置。

### 目标范围修正

最新设计确认：Tailscale 的首期部署范围是 Mac Studio、成员设备和 ECS1 至 ECS6，但只允许到 GitLab VM 的目标流量进入 Tailscale。ECS1 至 ECS6 的 `git.whale-smart.com` 均在本机解析为 `100.83.178.99`，GitLab 访问直接走 Tailscale；ECS4 另外保留公网入口，外部用户经 ECS4 转发到 GitLab VM。

多台接入 ECS 可以消除单台 ECS4 的公网入口瓶颈并提供故障切换，但不能扩大 Mac Studio 家庭网络上行的物理总带宽。ECS1 至 ECS6 都具备访问 Mac Studio 的条件，哪些节点同时承担公网 gateway 仍需测试定型。ECS1 至 ECS6 已全部加入当前个人 tailnet，属于迁移期基础；正式公司 tailnet 尚未替换当前个人 tailnet。

### 2026-08-31 接入验收记录

| 节点 | Tailscale IPv4 | 主机名 | Mac Studio 目标访问 | 公网出口 |
| --- | --- | --- | --- | --- |
| ECS1 | `100.118.86.59` | `ecs1-macstudio-access` | direct，TCP 2222 可达 | `RouteAll=false`，无 Exit Node |
| ECS2 | `100.85.211.101` | `ecs2-macstudio-access` | direct，TCP 2222 可达 | `RouteAll=false`，无 Exit Node |
| ECS3 | `100.115.38.3` | `ecs3-macstudio-access` | direct，TCP 2222 可达 | `RouteAll=false`，无 Exit Node |
| ECS4 | `100.100.85.86` | `ecs4-gitlab-gateway` | direct，TCP 2222 可达 | `RouteAll=false`，无 Exit Node |
| ECS5 | `100.68.48.115` | `ecs5-gitlab-agent` | direct，TCP 2222 可达 | `RouteAll=false`，无 Exit Node |
| ECS6 | `100.106.135.75` | `ecs6-macstudio-access` | direct，TCP 2222 可达 | `RouteAll=false`，无 Exit Node |

六台 ECS 到互联网的默认路由仍指向各自 `eth0`。DNS 已统一使用 `223.5.5.5` 和 `223.6.6.6`，避免云厂商 `100.100.2.136/138` 解析超时。

### GitLab 直连验收记录

- GitLab VM 容器已启用正式域名 HTTPS，宿主机 `443/tcp` 映射到容器 `443/tcp`；Git SSH 继续使用 `2222/tcp`。
- ECS1 至 ECS6 的 `/etc/hosts` 均包含 `100.83.178.99 git.whale-smart.com`，每台均已保留变更前备份。
- ECS1 至 ECS6 的 HTTPS 请求均返回 `200`，远端地址为 `100.83.178.99`；SSH `2222/tcp` 均返回 GitLab SSH banner。
- 六台到 `100.83.178.99` 的路由均为 `tailscale0`，到 `1.1.1.1` 的默认路由仍为各自 `eth0`。
- ECS4 公网 Nginx 上游已切换为 `https://100.83.178.99:443`，公网 HTTPS 返回 `200`。

## 5. 已确认的组织需求

- 建立公司通用内网，首期纳入 Wiki、GitLab、现有远程 Agent，以及现有开发和测试环境。
- 最新带宽设计以 GitLab 多 gateway 公网接入为当前目标；此前“GitLab 与 Wiki 完全禁止公网访问”的要求与该目标存在冲突，正式实施前必须明确采用哪一种模式。
- 五名成员 `roy`、`liao`、`suo`、`rock`、`dongqi` 的业务访问权限对等。
- 五名成员自行在 Windows、macOS 和移动设备安装 Tailscale。
- Mac Studio 是主要计算节点，承担 Runner 和后续适合集中运行的服务；GitLab 已迁移到 Proxmox VM `9002`，本期不迁移 ECS3 上的 Wiki。
- ECS1 至 ECS6 全部纳入内网；保留现有远程 Agent 环境，其他职责重新规划。
- ECS 节点继续使用各自固定 IP；是否保留或调整某个公网反向代理，按具体服务单独决定，不再把“选择一台公网边界节点”作为 Mac Studio Tailscale 接入的前置条件。
- 初始服务恢复目标为 60 分钟；家庭网络或 Mac Studio 整机故障是否纳入硬性 60 分钟承诺，需要独立容灾能力支持。
- 每个环境使用独立账号和独立密钥，不共享人员账号、Agent 账号或私钥。

## 6. 实施前置门槛

- 使用公司控制的身份域建立或接管正式 tailnet，并确认套餐支持至少 5 名成员和计划中的全部设备。
- GitLab VM、Mac Studio 和 ECS1 至 ECS6 完成家庭网络、Tailscale 路径、代理吞吐和故障切换测试；公网入口继续由 ECS4 承担。
- 安装 Tailscale 前逐台记录 DNS、默认路由、防火墙、容器和远程 Agent 状态，避免重现 ECS5 的 DNS 冲突。
- GitLab 的多 gateway 公网入口必须在 Tailscale、代理、DNS、性能和故障回退全部验收后才能切换；若仍要求 GitLab/Wiki 完全私网化，则必须先为该模式单独确定访问方案。
