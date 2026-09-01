---
id: team-network-overall-design
title: Team Network 总体设计
document_kind: overall-design
language: zh-CN
version: 3.1
status: design-corrected-pending-implementation
created_at: 2026-08-31
environment_reference: environment-baseline.md
---

# Team Network 总体设计

## 1. 核心结论

本项目的核心不是把所有 ECS 组成一张 Tailscale 内网，而是解决 Mac Studio 位于家庭网络、没有稳定公网入站地址的问题。

同时，单台 ECS4 的公网带宽有限，因此采用“**Mac Studio + ECS1 至 ECS6 访问节点**”的结构：

- Mac Studio 是唯一的家庭核心节点，安装 Tailscale。
- ECS1 至 ECS6 全部安装 Tailscale，具备访问 Mac Studio 的能力。
- 需要作为公网入口的 ECS 用自己的固定公网 IP 接收外部 GitLab 请求，再通过自己的 Tailscale 链路把请求转到 GitLab VM `9002`。
- 公网 DNS 将 GitLab 域名分配到已启用入口职责的 ECS，消除单台 ECS4 的入口瓶颈并提供节点故障切换。
- 成员设备可直接安装 Tailscale，绕过接入池访问 Mac Studio；大流量 Git 可选择直连路径。

必须明确：多台 ECS 可以扩大公网接入池的总入口能力，但不能突破 Mac Studio 家庭网络上行带宽的总上限。DNS 分流也不能把一条单独的 `clone` 连接拆到多台 ECS 上；单条连接仍受所选 ECS 和家庭上行的较小者限制。若未来需要突破家庭上行上限，必须把 GitLab 或仓库存储迁移到云端，或建设真正的多链路聚合方案，不能只靠增加 Tailscale 节点。

## 2. 目标与边界

### 2.1 目标

- 让外部用户通过正式 GitLab 域名访问家庭网络内 GitLab VM `9002` 上的 GitLab。
- 让多个 ECS 分摊公网入口流量，避免 ECS4 成为唯一公网瓶颈。
- 让接入 ECS 到 Mac Studio 的链路统一使用 Tailscale 加密连接。
- 让五名成员可以用自己的 Tailscale 设备直接访问 Mac Studio，获得低绕行、可审计的管理和 Git 路径。
- 保留 ECS1 至 ECS6 的固定 IP 服务和现有远程 Agent，不因 Tailscale 改变无关服务。
- 为接入节点、GitLab VM、Mac Studio、成员设备和 GitLab 访问提供清晰的身份、权限、回退和验收方法。

### 2.2 首期包含

- 公司控制的 Tailscale tailnet。
- Mac Studio Tailscale 节点。
- ECS1 至 ECS6 的 Tailscale 接入，以及其中至少两个公网入口 ECS。
- 接入 ECS 的反向代理、TCP 转发、健康检查和公网 DNS 分流。
- 五名成员的 Tailscale 设备直连 Mac Studio。
- GitLab 的公网接入池路径、成员直连路径和大流量对比测试。
- ECS 固定 IP 服务的现状记录和安全基线。

### 2.3 首期不包含

- 把 ECS1 至 ECS6 的所有业务流量都导入 Tailscale。
- 把所有互联网流量经 ECS4 或 Mac Studio 出口。
- Tailscale Exit Node、Subnet Router、全网三层路由和专用 DNS 集群。
- 通过 Tailscale 自动实现多链路带宽聚合。
- 迁移 ECS3 上的 Wiki；Wiki 继续运行在 ECS3。
- GitLab 高可用、仓库多副本和家庭上行故障的自动容灾。

## 3. 目标拓扑

```text
外部用户
    |
    | git.whale-smart.com
    | DNS 返回多个固定公网 IP
    v
┌──────────────┬──────────────┬──────────────┐
│ ECS1 gateway │ ECS2 gateway │ ECS3 gateway │
│ ECS4 gateway │ ECS5 gateway │ ECS6 gateway │
└──────┬───────┴──────┬───────┴──────┬───────┘
       | Tailscale     | Tailscale     | Tailscale
       └───────────────┴───────────────┴─────────┐
                                                   v
                                  Mac Studio（家庭网络）
                                  GitLab / Runner

成员设备 ───────────── Tailscale 直连 ───────────► Mac Studio

成员设备 ───── 固定 IP / HTTPS ─────► ECS1 至 ECS6 的其他服务
```

### 3.1 三条访问路径

| 路径 | 适用对象 | 说明 |
| --- | --- | --- |
| 公网接入池 | 不安装 Tailscale 的外部用户 | DNS 分配到某个 ECS gateway，再经 Tailscale 到 Mac Studio |
| 成员直连 | 五名成员和管理设备 | Tailscale 直接访问 Mac Studio，不经过 ECS gateway |
| 固定 IP 服务 | Wiki、Agent、开发测试服务 | 继续使用各自固定 IP/域名、HTTPS、云安全组和应用认证 |
| ECS 访问 Mac Studio | ECS1 至 ECS6 的目标流量 | 只经过 Tailscale，不改变 ECS 其他流量 |

公网接入池是“多入口”，不是“多副本”。所有 gateway 最终访问同一个 GitLab VM 数据面，因此不能把它描述成 GitLab 高可用集群。

## 4. 节点职责

| 节点 | 目标职责 | 是否安装 Tailscale |
| --- | --- | --- |
| GitLab VM `9002` | GitLab、仓库数据、家庭核心服务 | 是，核心节点 |
| Mac Studio | Runner、迁移回退副本 | 是，执行节点 |
| 公网接入 ECS | TLS 终止、HTTP 反向代理、Git SSH TCP 转发、健康检查 | 是，`tag:gitlab-gateway` |
| 其他 ECS | Wiki、Agent、开发测试和基础设施服务 | 是，`tag:macstudio-access`；只允许访问 Mac Studio 登记端口 |
| ECS3 | Wiki、Wiki API、Spec Execution | 当前固定 IP；Wiki 域名为 `wiki.whale-smart.com` |
| 成员终端 | 直接访问 Mac Studio，必要时访问固定 IP ECS | 是，个人设备 |

ECS4 不再天然承担唯一公网入口。ECS1 至 ECS6 都可以访问 Mac Studio；其中哪些节点同时承担公网 gateway，由公网带宽、时延、丢包、稳定性、现有负载和故障影响决定。

## 5. Tailscale 部署方案

### 5.1 正式 tailnet

1. 使用公司控制的 `whale-smart.com` 身份建立或接管正式 tailnet。
2. 启用 SSO、MFA、设备登录通知和至少两名恢复管理员。
3. 建立五名成员的个人身份：`roy`、`liao`、`suo`、`rock`、`dongqi`。
4. 确认套餐覆盖成员设备、Mac Studio 和全部公网接入 gateway。
5. 现有个人 tailnet只作为迁移期连接，不能作为公司长期控制面。

### 5.2 Mac Studio 接入

Mac Studio 使用官方客户端加入正式 tailnet，固定主机名为 `mac-studio`。加入前保留本机控制台和家庭局域网恢复路径。

- 不发布子网路由。
- 不发布 Exit Node。
- 不要求家庭路由器做公网端口映射。
- Tailscale SSH 只用于受控运维；GitLab SSH 仍由 GitLab 服务授权。
- 记录 Tailscale IP、版本、最近握手和 GitLab 监听端口。

成员设备可以直接连接 Mac Studio 的 Tailscale IP；这条路径用于管理、日常 Git 和大文件传输基准测试。

### 5.3 ECS1 至 ECS6 接入

ECS1 至 ECS6 全部作为独立 Tailscale 节点加入，使用独立主机名、独立标签、独立 auth key 和独立系统账号。不得复制另一台服务器的 Tailscale 状态目录、节点密钥或 SSH 私钥。只有被选为公网入口的节点额外运行 GitLab gateway 代理。

安装前记录：公网 IP、云安全组、DNS、默认路由、容器、代理配置、资源使用和当前 SSH 入口。安装时保持 `--accept-routes=false` 和 `--accept-dns=false`，不让 Tailscale 改写 ECS 公网解析。

建议命令形态如下，真实 auth key 只能通过安全注入；未承担公网入口的 ECS 只保留 `tag:macstudio-access`：

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up \
  --hostname=ecs1-macstudio-access \
  --auth-key="$TS_AUTHKEY" \
  --advertise-tags=tag:macstudio-access \
  --accept-routes=false \
  --accept-dns=false
sudo tailscale status
sudo tailscale ip -4
sudo tailscale netcheck
```

所有 ECS 都不使用 `--advertise-routes` 和 `--advertise-exit-node`。Tailscale 只承载到 GitLab VM Tailscale IP 的目标流量；ECS 的公网、Wiki、Agent 和开发测试流量继续使用固定 IP 网络。被选为 gateway 的 ECS 才作为应用层/传输层代理，通过 Grants 访问 GitLab VM 的 GitLab 端口。

### 5.4 成员设备加入

- Windows、macOS 和移动设备安装官方 Tailscale 客户端。
- 每名成员使用个人公司身份 SSO 登录，不共享账号或设备密钥。
- 默认不选择 Exit Node，不接受不必要的子网路由。
- 设备丢失时撤销设备；人员离开时撤销成员身份。
- 先验证 Mac Studio 直连，再验证公网 GitLab 接入池路径。

### 5.5 Tailscale 标签与 Grants

建议只保留四类关键机器标签：

| 标签 | 绑定对象 | 权限方向 |
| --- | --- | --- |
| `tag:macstudio` | Mac Studio | 接收成员和 gateway 的登记端口 |
| `tag:gitlab-gateway` | 公网接入 ECS | 只能访问 Mac Studio GitLab 443、2222 |
| `tag:macstudio-access` | ECS1 至 ECS6 | 只能访问 Mac Studio 登记端口 |
| `tag:member-device` | 成员设备（如需标签） | 访问 Mac Studio GitLab 和登记的管理端口 |

最小访问规则：

| 来源 | 目标 | 端口 |
| --- | --- | --- |
| `tag:gitlab-gateway` | `tag:macstudio` | TCP 443、2222 |
| `tag:macstudio-access` | `tag:macstudio` | 仅明确登记的 Mac Studio 业务端口 |
| `group:team` | `tag:macstudio` | TCP 443、2222，以及明确登记的管理端口 |
| Mac Studio 管理员 | Mac Studio | Tailscale SSH 或明确登记的运维端口 |

默认拒绝未登记连接。网络可达不等于 GitLab 管理员权限，也不等于宿主机 root 权限。

### 5.6 公网出口保持各自独立

ECS1 至 ECS6 都可以继续访问互联网，不需要把公网流量送进 Tailscale。安装 Tailscale 后，系统只为 Tailscale 目标地址增加 `tailscale0` 路径；默认路由仍然指向各 ECS 原有的公网网卡。

服务器统一保持以下设置：

```bash
sudo tailscale set --accept-routes=false --accept-dns=false
sudo tailscale set --exit-node=
ip route get 1.1.1.1
curl -4 https://api.ipify.org
```

验收时应看到：

- `ip route get 1.1.1.1` 仍从 ECS 自己的默认公网网卡出去。
- `curl -4 https://api.ipify.org` 返回该 ECS 自己的固定公网 IP。
- 访问 Mac Studio 的 `100.x` Tailscale 地址时，才使用 `tailscale0`。
- 不使用 `--advertise-exit-node`，成员设备也不选择 Exit Node。

如果未来某台机器需要经过 Tailscale 访问另一台没有安装客户端的局域网设备，那是 Subnet Router 场景；如果需要把全部互联网流量从某台 ECS 出口，那才是 Exit Node 场景。本项目当前两者都不需要。

## 6. 多公网接入设计

### 6.1 接入池实现

每个 gateway 运行同构配置：

- HTTPS 443 反向代理到 GitLab VM Tailscale IP 的 GitLab Web/HTTP 端口。
- SSH Git 使用独立公网端口，例如 2222，TCP 透传到 GitLab VM SSH 端口。
- 代理不缓存 Git 请求体、响应体或制品，不把大流量请求落盘。
- 每个 gateway 提供本地健康检查，检查 Tailscale 上游、GitLab HTTPS 和 SSH TCP。
- gateway 之间不保存 GitLab 仓库、数据库、制品或备份。

### 6.2 DNS 分流

- `git.whale-smart.com` 的公网 DNS 返回多个 gateway 固定 IP。
- DNS TTL 建议先设为 60 至 120 秒，但不能把 TTL 当作即时故障切换保证。
- 更好的生产方式是使用支持健康检查的 DNS 负载均衡；无此能力时，使用多 A 记录并配合人工摘除故障 IP。
- 成员设备可以配置 Split DNS，使同一域名直接解析到 Mac Studio Tailscale IP，从而绕过公网接入池。
- gateway 上游固定使用 Mac Studio Tailscale IP，不依赖公网 DNS 回环。

DNS 多 A 记录主要解决多用户分流和节点故障，不保证单个用户每次都命中不同 ECS，也不实现单条连接的带宽叠加。

### 6.2.1 ECS 发起 Git 操作时的实际路由

当前同时提供两条路径：公网用户进入 ECS4，ECS1 至 ECS6 的服务器流量直接进入 GitLab VM。两条路径使用同一正式域名和同一 GitLab 实例：

```text
公网用户
    -> git.whale-smart.com 公网 DNS
    -> ECS4 Nginx
    -> Tailscale
    -> 100.83.178.99:443/2222（GitLab VM）

ECS1 至 ECS6 上的 Git
    -> git.whale-smart.com（本机解析为 100.83.178.99）
    -> tailscale0
    -> 100.83.178.99:443/2222（GitLab VM）
```

当前已核实的端口映射为：

| ECS4 入口 | Tailscale 上游 | 用途 |
| --- | --- | --- |
| `443/tcp` | `100.83.178.99:443` | GitLab Web、HTTPS Git |
| `2222/tcp` | `100.83.178.99:2222` | Git SSH |

因此，ECS1 至 ECS6 的 `/etc/hosts` 均使用 `100.83.178.99 git.whale-smart.com`，Git 的解析和连接都直接走 `tailscale0`。公网 DNS 仍保留 ECS4 地址，外部用户仍由 ECS4 Nginx 转发到同一个 Tailscale 上游。TLS SNI、Host header 和 SSH 主机名保持正式域名，ECS 的默认互联网路由也不受影响。

GitLab VM 的 `443/tcp` 已在 Tailscale 地址上提供 HTTPS，因此直接解析不会绕过有效服务。该端口没有家庭路由器公网映射，公网暴露边界仍是 ECS4。

本次网络改动只有一个验收标准：ECS1 至 ECS6 访问 `git.whale-smart.com` 的 HTTP、HTTPS 和 Git SSH，均直接连接 GitLab VM，不经过 ECS4 公网 IP。逐台检查解析、HTTP `301`、HTTPS GitLab 响应、SSH `2222/tcp` banner 和路由即可完成验收。

### 6.3 选取 gateway

候选 ECS 使用同一工具、同一时间窗口和同一测试文件比较：

- 公网上下行带宽和持续传输稳定性。
- 到主要用户网络和 Mac Studio 的时延、抖动、丢包。
- Tailscale `direct` 与 DERP 情况。
- CPU、内存、磁盘、现有服务和重启影响。
- 云安全组、固定公网 IP、DDoS 防护和故障切换条件。

ECS1 至 ECS6 都具备成为 gateway 的条件，但是否启用公网入口职责仍需按测试结果决定。至少保留两个通过测试的 gateway；不能仅因 ECS4 历史上承担过入口就直接定案。

## 7. GitLab 访问与迁移

### 7.1 两种入口

- **公网入口**：外部用户访问 `git.whale-smart.com`，由 DNS 选择一个 gateway，再经 Tailscale 到 Mac Studio。
- **成员直连**：Team Network 成员使用 Tailscale Split DNS 或专用内网名称，直接访问 Mac Studio。

两种入口访问同一 GitLab 实例。GitLab 的外部 URL、回调、SSH 克隆地址和代理可信配置必须统一，不能因为入口节点不同而产生两套项目地址。

### 7.2 迁移步骤

1. 保留当前 ECS4 公网 GitLab 入口作为回退路径。
2. 建立正式 tailnet，接入 Mac Studio 和 ECS1 至 ECS6。
3. 在每个 gateway 完成 HTTPS、SSH、健康检查和流式转发配置。
4. 用公网 DNS 的低风险测试域名验证多入口，不立即替换正式域名。
5. 五名成员验证 Tailscale 直连和公网接入池两条路径。
6. 用大文件仓库分别测试直连、ECS4 gateway 和其他 gateway 的吞吐与稳定性。
7. 正式切换 `git.whale-smart.com` 到接入池，观察至少 24 小时。
8. 根据数据决定是否保留 ECS4 作为 gateway；故障时从 DNS 池摘除单台节点，不影响其他入口。

## 8. Wiki 与其他 ECS

Wiki 已确认位于 ECS3，公网 IP 为 `8.221.138.205`，域名为 `wiki.whale-smart.com`。本设计不迁移 Wiki，也不要求 ECS3 为了访问 Mac Studio 安装 Tailscale。

因此：

- Wiki 继续使用 ECS3 固定 IP、Caddy、HTTPS、云安全组和应用认证。
- 其他 ECS 继续使用固定 IP 或正式域名访问。
- 如果未来要求 Wiki 仅 Team Network 可访问，需要另行给 ECS3 安装 Tailscale，或建设身份代理/白名单方案；Mac Studio 的 Tailscale 不会自动保护 ECS3。

## 9. 安全、备份与可用性

- gateway 只拥有访问 Mac Studio GitLab 443/2222 的网络权限，不拥有其他内网端口权限。
- gateway 不保存仓库、制品、数据库和备份；只做转发。
- 每个 gateway 使用独立 OS 账号、Tailscale 节点身份、代理配置和 SSH 管理密钥。
- GitLab、Wiki、gateway 配置和 Tailscale 策略分别备份，密钥不进入仓库。
- Mac Studio 的备份继续复制到独立目标；ECS5 不能因为成为 gateway 就自动成为备份目标。
- 60 分钟 RTO 适用于 Tailscale 重连、gateway 故障摘除、代理重启和 GitLab 容器故障。
- 家庭断电、家庭网络中断或 Mac Studio 整机故障时，多 gateway 不能提供真正的服务恢复；需要云端温备或云端主服务。

## 10. 线性实施顺序

| 阶段 | 独立交付 | 验收门槛 |
| --- | --- | --- |
| P1 需求与容量 | 正式 tailnet、成员、套餐和访问模式确认 | 五人身份可用，明确公网模式 |
| P2 Mac Studio | Mac Studio Tailscale 节点和直连访问 | GitLab 可直连，恢复路径有效 |
| P3 gateway 试点 | 一台候选 ECS 完成 Tailscale + 代理 | 公网解析、原有服务和 SSH 不受影响 |
| P4 gateway 扩展 | 至少两个 gateway 同构运行 | 两条公网入口都能完成 Git 操作 |
| P5 DNS 分流 | 正式域名指向 gateway 池 | 健康检查、摘除和回退有效 |
| P6 性能验收 | 直连与多 gateway 对比报告 | 单节点不成为唯一瓶颈，结论记录家庭上行上限 |
| P7 正式交付 | 监控、备份、故障演练和文档 | 验收矩阵全部有证据 |

## 11. 验收矩阵

| 验收项 | 方法 | 通过标准 |
| --- | --- | --- |
| Tailscale 范围 | 查看设备清单和标签 | Mac Studio、成员设备、ECS1 至 ECS6 在内；仅登记的 Mac Studio 端口可达 |
| 成员身份 | 五人分别 SSO 登录 | 无共享账号，业务访问能力对等 |
| Mac Studio 直连 | `tailscale ping`、HTTPS、SSH Git | 直连可用，记录 direct/DERP 路径 |
| Gateway 上游 | 每台 gateway 做 Tailscale ping、HTTPS 和 TCP 检查 | 每台都能到 Mac Studio 的登记端口 |
| 多入口 DNS | 多地解析和逐个摘除 gateway | 健康节点仍可访问，故障 IP 可撤除 |
| 公网 GitLab | Web、HTTPS Git、SSH Git | 外部用户经任一健康 gateway 完成操作 |
| 大流量 Git | 大文件 clone、push、pull | 比较各 gateway 吞吐；确认不缓存、不落盘 |
| 成员直连 | 成员设备绕过 gateway 完成 Git 操作 | 直连路径可用，流量不经过 ECS4 |
| 固定 IP ECS | 访问 ECS3 Wiki 和现有 Agent | 原有容器、权限和网络路径不受影响 |
| 安全边界 | 端口和拒绝规则测试 | gateway 只能访问 Mac Studio 登记端口 |
| 故障回退 | 摘除一个 gateway、停止 Tailscale、恢复 DNS | 其他入口可用，本机管理路径能恢复节点 |
| 备份恢复 | 恢复 GitLab 和 Wiki 测试数据 | 数据可读取，服务可操作 |

## 12. 可行性结论与限制

该方案可行，并且比“所有 ECS 全网互联”更贴合问题：Tailscale 只承担 Mac Studio 的安全可达性，多个公网 ECS 负责分摊入口和提供切换能力，ECS 固定 IP 服务不被强行改造。

但它解决的是**单台公网入口 ECS 的瓶颈和单点故障**，不是家庭网络上行带宽瓶颈。实施验收必须同时给出两项数据：

1. 多 gateway 相比单 ECS4 的入口吞吐、错误率和故障切换改善。
2. Mac Studio 家庭上行的最大可用吞吐，以及它对最终 GitLab 访问的硬上限。

如果第二项成为主要瓶颈，下一阶段应把 GitLab 主服务迁到云端，或建设正式的云端温备/多链路方案；继续增加 ECS gateway 不会带来线性收益。
