---
id: roadmap
title: 路线图
document_kind: machine-readable-roadmap
language: zh-CN
version: 3.5
status: delivered
source_of_truth: six-elements.md
environment_reference: related-environment.md
frozen_dependency: true
linear: true
milestone_contract: six-elements
---

# 路线图

## 00. 执行规则

- 只有一条主线，按 M1 到 M6 顺序推进。
- 后一个里程碑以前一个里程碑验收通过为前置条件。
- 每个里程碑只解决一个内聚问题，并有独立交付物和独立验收。
- 验收不通过时停在当前里程碑修复，不跨步堆积问题。
- 六要素已冻结；改变目标、边界或验收前必须显式解冻。
- 当前正式 GitLab 节点是 Proxmox VM `9002`；Mac Studio 只承担 Runner，旧 GitLab 作为回退副本。

## M1. 环境与运行基础

### 目标
证明 Proxmox VM、数据盘、Docker、Tailscale 和 Mac Studio Runner 具备承载 GitLab 的条件。

### 工作方法
1. 确认 VM `9002` 的地址、资源、数据盘和默认网络出口。
2. 验证 Docker、Tailscale、端口和容器自动启动能力。
3. 验证 Mac Studio 到 GitLab VM 的 Tailscale 访问路径。

### 边界
只覆盖运行基础、网络和资源，不覆盖正式项目迁移、备份策略和公网入口。

### 约束
不删除 Mac Studio 旧实例；ECS5 不作为服务或备份依赖；不使用 Exit Node 改变节点默认公网出口。

### 交付物
VM 资源与磁盘记录、Docker Compose 配置、Tailscale 节点记录和回退说明。

### 验收标准与方法
VM 默认路由经 `eth0`，Tailscale 地址为 `100.83.178.99`，Docker 为 `enabled/active`，GitLab 容器能启动并报告健康状态。

### 验收结果
通过。VM 为 `8 vCPU / 16GB RAM`，数据盘约 `1TB`，Docker 已启用，Tailscale 可达，旧 Mac Studio 实例保留。

## M2. GitLab 迁移与核心服务

### 目标
把原 GitLab 数据完整迁移到 VM `9002`，让正式 GitLab 在新节点稳定运行。

### 工作方法
1. 使用官方 GitLab 备份恢复数据库、仓库、Wiki、上传文件、制品、LFS、Packages 和 Terraform state。
2. 迁移 `gitlab.rb`、secrets、TLS 证书和 GitLab SSH 主机密钥。
3. 配置 `/srv/gitlab` 持久化目录、正式域名和 `2222/tcp` Git SSH。
4. 停止并禁用 VM 上残留的原生 Omnibus 实例，由 Docker 容器接管端口。

### 边界
只覆盖 GitLab 核心服务和数据，不迁移 ECS3 Wiki，不改变 ECS4 公网入口职责。

### 约束
迁移必须可校验、可回退；不覆盖 Mac Studio 原 GitLab 数据；密码、Token 和私钥不得进入仓库。

### 交付物
GitLab CE `19.3.1` 容器、`/srv/gitlab` 数据目录、迁移备份校验记录和 6 个恢复项目清单。

### 验收标准与方法
HTTPS 返回 `200`，Git SSH `2222/tcp` 可认证，项目、用户、权限和仓库可读取，容器重启后数据保持。

### 验收结果
通过。已恢复 6 个项目；迁移备份 SHA-256 为 `376afcba7779ae30d8812fca6086dcb56b84887f917a9916ac8deb9a6662394d`。

## M3. 公网与服务器直连

### 目标
公网用户经 ECS4 访问正式域名，ECS1 至 ECS6 通过 Tailscale 直接访问 GitLab VM。

### 工作方法
1. 保持 DNS A 记录指向 ECS4 `39.105.43.18`。
2. 将 ECS4 Nginx HTTPS 上游切换到 `https://100.83.178.99:443`，Git SSH 上游切换到 `100.83.178.99:2222`。
3. 在 ECS1 至 ECS6 将 `git.whale-smart.com` 解析为 `100.83.178.99`。
4. 逐台检查解析、路由、HTTP、HTTPS 和 Git SSH。

### 边界
ECS4 只转发，不存储仓库；ECS1 至 ECS6 只承担访问职责，不承担公网入口、GitLab 或备份职责。

### 约束
公网 DNS 不改为家庭地址；GitLab VM 不做端口映射；ECS1 至 ECS6 的目标路由必须走 `tailscale0`，互联网默认路由必须保留 `eth0`。

### 交付物
ECS4 代理配置、证书记录、ECS1 至 ECS6 解析与路由记录、Git 访问说明。

### 验收标准与方法
公网 HTTPS 返回 `200`，HTTP 自动跳转；ECS1 至 ECS6 的 HTTP 返回 `301`、HTTPS 返回 `200`、SSH `2222/tcp` 返回 GitLab banner，且目标地址为 `100.83.178.99`。

### 验收结果
通过。ECS4 上游已切换，六台 ECS 均完成 direct Tailscale 路径验收；公网 DNS 仍指向 ECS4。

## M4. CI/CD 闭环

### 目标
交付可自动触发、可诊断、可重跑并可保存制品的 GitLab CI/CD。

### 工作方法
1. 保留 Mac Studio `mac-studio-arm64` Docker Runner。
2. 使用仓库中的 `.gitlab-ci.yml` 执行 `test` 和 `build`。
3. 记录流水线编号、Job、Runner 和制品结果。

### 边界
只覆盖一个 Runner、基础测试、构建和制品保存，不覆盖高可用 Runner 或生产发布编排。

### 约束
Runner Token 不进仓库；Job 必须由真实 Runner 执行，不能用手工输出代替。

### 交付物
在线 Runner、示例流水线配置、Job 日志和构建制品。

### 验收标准与方法
流水线自动创建并完成，`test` 和 `build` 均成功，Job 绑定 `mac-studio-arm64`，制品可读取。

### 验收结果
通过。目标 GitLab 流水线 `#6` 由 Mac Studio Runner 执行，`test`、`build` 均为 `success`。

## M5. 备份与恢复

### 目标
让 GitLab 数据离开 VM 保存，并能从独立目标读取和恢复。

### 工作方法
1. 在 GitLab VM 生成官方 GitLab 备份。
2. 通过 Tailscale SSH 复制到 `roymacbook-pro` `/Users/royzuo/gitlab-backups`。
3. 校验 SHA-256、保留策略和恢复结果；LaCie 只作本地第二副本。

### 边界
不使用 ECS5 作为备份目标，不建设高可用和对象存储。

### 约束
备份目标必须与 VM 分离；备份必须可读取和实际恢复，不能只检查文件存在。

### 交付物
备份文件、校验记录、恢复记录、接收目录权限和维护说明。

### 验收标准与方法
在独立目标找到备份，校验一致；从备份恢复项目 bundle，执行 `git fsck` 并读取提交记录。

### 验收结果
通过。迁移备份已复制、校验并完成测试恢复；ECS5 已明确排除。

## M6. 正式交付与回退准备

### 目标
把 M1 至 M5 的成果组合成可维护、可验收、可回退的首期 GitLab 服务。

### 工作方法
1. 执行容器重启恢复测试和 ECS5 完整 Git 操作测试。
2. 核对公网入口、六台 ECS 直连、Runner、备份和安全边界。
3. 保留迁移前 Mac Studio 实例至少 7 天，整理维护与回退说明。

### 边界
不引入新功能，不迁移 ECS3 Wiki，不删除旧 GitLab，不扩展为高可用架构。

### 约束
没有证据的项目按未通过处理；仓库不得包含明文凭据；回退副本不得与新实例双写。

### 交付物
正式 GitLab 服务、ECS4 入口、Mac Studio Runner、备份与恢复记录、环境文档和验收证据。

### 验收标准与方法
容器重启后约 70 秒恢复为 `running healthy`；公网 HTTPS 为 `200`；ECS5 的 `kunora` 完成 `clone`、`push`、`pull`；`/srv/reports/` 可写；流水线成功；六台 ECS 直连且互联网出口未改变。

### 验收结果
通过。2026-09-01 完成重启恢复、ECS5 完整 Git 操作、报告目录写入和 CI 流水线复核。首期成果达到交付条件，进入 7 天观察期。
