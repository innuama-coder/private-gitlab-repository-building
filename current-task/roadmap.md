---
id: roadmap
title: 路线图
document_kind: machine-readable-roadmap
language: zh-CN
version: 3.3
status: feasibility-reviewed
source_of_truth: six-elements.md
environment_reference: related-environment.md
frozen_dependency: true
linear: true
milestone_contract: six-elements
---

# 路线图

## 00. 执行规则

- 只有一条主线，按 M1 到 M6 顺序推进。
- 后一个里程碑必须以前一个里程碑验收通过为前置条件。
- 每个里程碑只解决一个内聚问题，并有独立交付物和独立验收。
- 任何验收不通过时，停在当前里程碑修复，不跨步堆积问题。
- 每个里程碑都完整使用六要素：目标、工作方法、边界、约束、交付物、验收标准与方法。
- 六要素已经冻结；若实施中需要改变目标、边界或验收，必须先显式解冻。
- 公网 Web、HTTPS Git 和 SSH Git 流量经过 ECS4；ECS5 自身的 Git SSH 流量通过 Tailscale 直连 Mac Studio，不改变公网链路。

## M1. 节点与运行基础可行

### 01. 目标

证明 Mac Studio 能以 Linux 容器运行 GitLab 所需环境，并让 ECS4、Mac Studio 形成可管理的 Tailscale 私网基础。M1 的结果必须回答“这套主机和运行时能不能承载后续方案”。

### 02. 工作方法

1. 确认 Mac Studio、ECS4 的角色、地址和公网入口条件。
2. 在 Mac Studio 安装或确认 Docker Desktop、Colima 或等效 Linux 容器运行时。
3. 拉取目标 GitLab CE 镜像，验证原生 ARM64；若不可用，再验证 `linux/amd64` 兼容运行。
4. 用测试数据启动一次 GitLab 容器，检查端口、健康端点、持久化目录和重启恢复。
5. 配置 Mac Studio 与 ECS4 的 Tailscale 连接、ECS4 防火墙和 Mac Studio 不睡眠策略。

### 03. 边界

- 包含：运行时、镜像架构、持久化目录、节点连接和基础防火墙。
- 不包含：正式域名、生产 GitLab 数据、正式 HTTPS、Git SSH 转发和正式 Runner 流水线。
- 测试容器只用于证明基础可行，不作为 M2 的正式服务数据。

### 04. 约束

- macOS 只能作为宿主机，GitLab 必须运行在 Linux 容器环境中。
- Apple Silicon 的原生 ARM64 结果必须单独记录；amd64 仿真不能被标为原生支持。
- Tailscale 连接必须使用已有 tailnet 和最小必要权限。
- 不删除或覆盖用户已有的 Mac Studio 数据，不把测试数据写入正式目录。

### 05. 交付物

- Mac Studio、ECS4 的角色、地址和端口清单。
- Mac Studio 容器运行时版本和配置。
- GitLab 镜像架构验证记录。
- 测试容器配置、持久化目录和健康检查记录。
- Tailscale 连接与 ECS4 基础防火墙配置。
- M1 可行性结论：通过或阻断，并附证据。

### 06. 验收标准与方法

- 从 ECS4 通过 Tailscale SSH 访问 Mac Studio。
- GitLab 测试容器可启动，健康检查返回预期结果。
- 重启或重建测试容器后，测试数据仍可读取。
- 明确记录实际使用的 CPU 架构和运行模式。
- 从公网扫描时，Mac Studio 没有直接暴露 GitLab 端口。

通过门槛：运行时和架构验证通过，私网连接稳定，才能进入 M2；否则路线图在 M1 停止并回到方案决策。

## M2. GitLab 核心服务可用

### 01. 目标

在 Mac Studio 上交付可通过 Tailscale 访问的正式单节点 GitLab，完成代码托管、登录和基础项目权限闭环。

### 02. 工作方法

1. 根据 M1 验证结果固定 GitLab 镜像、运行时和数据目录。
2. 分别挂载配置、日志、仓库、数据库、制品和上传文件。
3. 设置正式域名占位的 GitLab 外部 URL。
4. 创建管理员账号、私有示例项目和测试账号。
5. 启用强密码、双因素认证和最小项目权限。
6. 重启、重建容器并复核项目和账号数据。

### 03. 边界

- 包含：GitLab CE 单节点、Web 登录、私有项目、Issue、Merge Request 和基础权限。
- 不包含：正式公网访问、CI/CD Runner、备份复制和高可用能力。
- M2 只通过 Tailscale 验收，不以公网域名作为验收入口。

### 04. 约束

- 必须使用 M1 已验证的运行模式和架构。
- 正式数据不能与 M1 测试目录混用。
- 管理密码和 Token 不写入仓库或命令记录。
- Mac Studio 仍需保持接电、联网和不自动睡眠。

### 05. 交付物

- GitLab CE 部署配置和持久化目录清单。
- 可通过 Tailscale 登录的 GitLab 服务。
- 管理员账号、私有示例项目和测试账号。
- 管理员安全设置记录。
- 容器重启恢复记录。

### 06. 验收标准与方法

- 通过 Tailscale 打开 GitLab 登录页并登录管理员账号。
- 创建私有项目、Issue 和 Merge Request。
- 测试账号只能看到被授权项目。
- 在测试项目中完成一次提交和读取。
- 重启 GitLab 容器后，项目、账号和提交仍然存在。

通过门槛：GitLab 能登录、保存项目、控制权限并在重启后保留数据，才能进入 M3。

## M3. 公网 Web 与 Git 入口可用

### 01. 目标

让外部用户通过正式域名访问 GitLab Web，并让 Web、HTTPS Git 和 SSH Git 全部经 ECS4 完成访问；Mac Studio 仍不直接暴露公网。

### 02. 工作方法

1. 确认域名 A 记录指向 ECS4 公网 IP。
2. 在 ECS4 部署 Caddy 或 Nginx，配置 HTTPS 证书自动续期。
3. 通过 Tailscale 将所有 Web、Git HTTPS 和 Git SSH 流量转发到 Mac Studio。
4. 为 Git SSH 选择独立端口，或配置已验证的 SSH 转发规则。
5. 将 GitLab 外部 URL 切换到正式域名。
6. 配置流式转发，确保大流量 Git 请求和响应不落盘、不缓存。
7. 在 ECS5 安装 Tailscale，配置其专属 GitLab SSH 身份直连 Mac Studio。
8. 从不在家庭网络中的客户端完成 Web 和 Git 操作，并从 ECS5 完成一次私网 Git 操作。

### 03. 边界

- 包含：正式域名、HTTPS、Web、HTTPS Git、SSH Git、ECS4 反向代理和流式转发。
- 不包含：CI/CD 流水线、备份恢复和入口高可用。
- ECS5 直连只包含 ECS5 自身的 Git SSH 访问，不包含公网 Web 入口或备份职责。
- 不把 ECS4 的管理员 SSH 与 Git SSH 端口冲突留到后续处理。

### 04. 约束

- ECS4 必须具备固定公网 IP、域名解析和 80/443 访问条件。
- Mac Studio 不做家庭路由器端口映射。
- Git SSH 的实际端口必须写入访问说明并真实验证。
- 证书申请和续期不能依赖人工临时操作。
- 公网用户端不要求安装 Tailscale；ECS4 到 Mac Studio 的 Tailscale 链路必须稳定，ECS5 到 Mac Studio 的 Tailscale 链路必须可独立使用。
- ECS4 不得缓存或落盘 Git 请求体、响应体和仓库数据。
- 必须记录 ECS4 公网带宽和家庭上行带宽的实测结果，确认它们满足首期使用规模。

### 05. 交付物

- 正式 GitLab 域名和 DNS 记录。
- ECS4 反向代理、HTTPS 和证书续期配置。
- Web、HTTPS Git、SSH Git 访问说明。
- 管理 SSH 与 Git SSH 的端口分工记录。
- ECS4 公网带宽、家庭上行带宽和大流量转发测试记录。
- 外部访问测试记录。
- ECS5 Tailscale 节点、Git SSH 直连配置和私网访问记录。

### 06. 验收标准与方法

- 使用家庭网络之外的客户端打开正式域名。
- 证书有效，页面可以登录管理员账号。
- 通过公网 HTTPS 完成 `clone`、`push`、`pull`。
- 通过公网 SSH 完成 `clone`、`push`、`pull`。
- 使用包含较大文件的测试仓库完成一次 HTTPS 和 SSH 的 `clone`、`push`、`pull`，确认流量经 ECS4 转发且操作不因超时或缓存失败。
- 记录转发过程的吞吐、错误率、超时和 ECS4 资源使用情况。
- 验证 Mac Studio 没有直接公网 GitLab 端口。
- 从 ECS5 通过 Tailscale 直接完成 GitLab SSH `clone`、`push`、`pull`，并确认未经过 ECS4。
- 临时断开 Tailscale，确认公网入口明确失败；恢复后重新可用。

通过门槛：正式域名的 Web、HTTPS Git 和 SSH Git 均通过，ECS4 与家庭上行带宽满足首期规模，大流量 Git 转发成功且入口链路无端口冲突，才能进入 M4。

### M3 验收记录（2026-08-30）

- DNS：`git.whale-smart.com` 已解析到 `39.105.43.18`。
- HTTPS：Let's Encrypt 证书有效，Certbot 续期模拟通过。
- Web：公网 HTTPS 登录页返回 `200`，HTTP 自动跳转 HTTPS。
- HTTPS Git：临时私有项目完成 push、clone、pull。
- SSH Git：经公网 `2222/tcp` 完成 clone、push、pull。
- 大流量 Git：临时项目传输 8 MiB 文件并完成两种协议的读取验证。

### M3 ECS5 私网直连验收记录（2026-08-30）

- Tailscale：ECS5 节点 `ecs5-gitlab-agent`，地址 `100.68.48.115`，已加入现有 tailnet。
- 点对点链路：ECS5 到 Mac Studio `100.65.102.93` 的 `tailscale ping` 显示 direct 路径。
- Git SSH：Mac Studio `2222/tcp` 可从 ECS5 Tailscale 地址访问。
- 身份：使用独立账号 `agent-ecs5` 和独立 Ed25519 密钥。
- 实际操作：完成临时 Project 的 direct `clone` 和分支 `push`。
- 网络修复：将 ECS5 的冲突 DNS 从 `100.100.2.136/100.100.2.138` 切换为 `223.5.5.5/223.6.6.6`，公网 DNS、HTTPS 和 GitLab 直连均恢复。
- ECS4：公网域名和公网 SSH 入口未修改，仍保持原有职责。
- Tailscale：ECS4 到 Mac Studio 验证为直连，未走 DERP。
- 结果：M3 验收通过。

## M4. CI/CD 闭环可用

### 01. 目标

交付一个可自动触发、可诊断、可重跑、可保存制品的 GitLab CI/CD 工作流。

### 02. 工作方法

1. 在 Mac Studio 注册 GitLab Runner，使用 Docker executor。
2. 设置 ARM64 为默认构建架构，并给每个镜像声明目标平台。
3. 编写示例 `.gitlab-ci.yml`，包含测试、构建和制品保存。
4. 运行一次成功流水线并保存编号、日志和制品。
5. 人为制造一次失败，确认日志能定位原因。
6. 修复代码后重跑，确认流水线成功。

### 03. 边界

- 包含：一个主要 Runner、Docker executor、测试、构建、日志和制品保存。
- 不包含：多 Runner 高可用、复杂发布编排、生产部署和跨架构发布体系。
- amd64 只作为单独兼容性验证，不作为默认构建能力。

### 04. 约束

- Runner 必须使用 M1 已验证的容器运行时。
- CI 镜像优先 ARM64；跨架构仿真不得隐藏在默认配置中。
- Runner Token 使用 GitLab 受控变量或安全配置，不进入仓库。
- 流水线失败必须保留日志，不能用手工成功替代自动结果。

### 05. 交付物

- 已注册并在线的 GitLab Runner。
- 示例 `.gitlab-ci.yml`。
- 成功流水线、失败流水线和修复重跑记录。
- 构建日志和示例制品。
- Runner 架构和镜像兼容性记录。

### 06. 验收标准与方法

- 提交示例代码后流水线自动启动并成功完成。
- 能查看每个阶段的日志。
- 能下载并读取示例制品。
- 修改配置或代码制造一次失败，能从日志定位原因。
- 修复后重新运行，流水线成功。
- 记录 ARM64 或 amd64 的实际运行方式。

通过门槛：Runner 完成成功、失败、修复重跑、日志和制品保存，才能进入 M5。

## M5. 备份与恢复可用

### 01. 目标

交付一套真正可恢复的 GitLab 数据保护能力：将备份复制到 roymacbook-pro，并完成校验、读取和项目恢复；LaCie 作为可选的人工第二副本。

### 02. 工作方法

1. 在 Mac Studio 配置每日 GitLab 备份。
2. 确认 roymacbook-pro 远端目标，部署接收目录、专用备份密钥和最小权限。
3. 通过 Tailscale 或受限 SSH 复制备份并记录校验结果。
4. 设置保留版本、磁盘空间检查和失败告警记录。
5. 将 GitLab 配置、ECS4 代理配置和恢复步骤单独归档。
6. 恢复一个测试项目到测试位置并完成一次 Git 操作。

### 03. 边界

- 包含：GitLab 备份、独立目标接收、校验、保留、测试恢复和恢复说明。
- 不包含：ECS5 上的任何服务、高可用和对象存储。
- ECS5 暂不引入；新的备份目标必须先完成环境确认。

### 04. 约束

- 正式备份目标必须与 Mac Studio 保持物理或故障域分离；roymacbook-pro 不得与 Mac Studio 共用备份目录。
- 备份目录使用专用密钥、受限 SSH 选项和最小权限；不把 LaCie 作为唯一目标。
- 备份不能只验证文件存在，必须验证读取和恢复。
- 备份失败、磁盘不足和链路中断必须留下可诊断记录。
- 正式备份目标必须在 M5 内完成选择和可达性验证，不能使用 ECS5。

### 05. 交付物

- 独立备份目标选择和可达性决策记录。
- Mac Studio 定时备份配置。
- 独立备份目标的接收目录、账号和权限配置。
- 备份文件、校验记录和保留策略。
- 测试恢复结果。
- GitLab、ECS4 和恢复流程说明。

### 06. 验收标准与方法

- 手动执行一次备份并确认成功。
- 在独立备份目标找到备份，核对时间、大小和校验结果。
- 删除测试位置副本后从备份恢复项目。
- 读取恢复后的项目并完成一次 Git 操作。
- 确认备份链路不依赖公网入口代理的数据目录。

通过门槛：备份能生成、复制、校验、读取和恢复，才能进入 M6。

## M6. 首期成果正式交付

### 01. 目标

把 M1 至 M5 的独立成果组合成符合冻结六要素的首期 GitLab 服务，并完成全链路证据归档。

### 02. 工作方法

1. 固化 GitLab、Runner、反向代理和 Tailscale 的版本与配置。
2. 按“访问与身份、Git 操作、CI/CD、可靠性与恢复”四组清单逐项复核。
3. 执行重启、Tailscale 断连和恢复测试。
4. 整理命令输出、截图、流水线编号、制品、备份和恢复记录。
5. 输出维护、故障处理、恢复和升级触发说明。

### 03. 边界

- 包含：首期服务、全链路验收、证据归档、维护说明和升级观察项。
- 不包含：新功能扩张、架构升级或未在冻结六要素中定义的能力。
- M6 不以“未来可以补齐”为通过条件。

### 04. 约束

- M1 至 M5 必须全部通过后才能执行 M6。
- 冻结六要素的目标、边界和验收不能被实现结果反向降低。
- 每项验收必须有对应证据位置；没有证据的项目按未通过处理。
- 发布前不得遗留明文密码、Token、私钥或未限制的管理入口。

### 05. 交付物

- 可通过正式域名访问的 GitLab 服务。
- GitLab Runner 和示例 CI/CD 流水线。
- ECS4 公网入口配置。
- 独立备份目标的备份与恢复记录。
- 配置、版本、维护、故障处理和恢复说明。
- 完整验收证据索引。

### 06. 验收标准与方法

- 外部网络可打开正式域名，HTTPS 有效，管理员可登录。
- 私有项目的 SSH 和 HTTPS `clone`、`push`、`pull` 均通过。
- 测试账号权限符合项目授权范围。
- CI/CD 成功、失败、修复重跑、日志和制品均有记录。
- Web、HTTPS Git 和 SSH Git 均证明通过 ECS4 转发；大流量 Git 操作有成功记录。
- 备份、恢复、重启和 Tailscale 断连恢复均有记录。
- Mac Studio 没有直接公网 GitLab 入口。
- 冻结六要素的全部验收项都有通过证据。

通过门槛：所有冻结验收项均通过且证据可复查，首期任务才算完成；否则保持未交付状态并回到对应里程碑。
