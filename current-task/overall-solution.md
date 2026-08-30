---
id: overall-solution
title: 总体方案
document_kind: machine-readable-solution-brief
language: zh-CN
version: 2.0
status: agreed
source_of_truth: six-elements.md
frozen_dependency: true
primary_node: Mac Studio
public_entry_node: ECS4
backup_node: ECS5
private_network: Tailscale
---

# 总体方案

## 01. 方案结论

采用“Mac Studio 承载核心服务，ECS4 承载公网入口，Tailscale 负责私网连接，ECS5 承载备份”的分层方案。

这条路径同时解决三件事：Mac Studio 有足够资源运行 GitLab，家庭网络不直接暴露，外部用户仍能使用标准 HTTPS 和 SSH Git 访问。首期只建设单节点 GitLab，不引入高可用集群或 Kubernetes。

## 02. 目标到实现的对应关系

| 目标 | 实现方式 | 交付证据 |
| --- | --- | --- |
| 代码托管 | Mac Studio 运行 GitLab，数据保存到独立数据目录 | 私有项目、仓库访问记录 |
| 协作评审 | 启用项目权限、Issue 和 Merge Request | 测试账号权限记录、评审页面 |
| CI/CD | GitLab Runner 执行 ARM64 优先的示例流水线 | 流水线编号、日志、制品 |
| 外部访问 | ECS4 公网反向代理，经 Tailscale 转发到 Mac Studio | 域名访问、证书和 Git 操作 |
| 可恢复运行 | 定时备份到 ECS5，配置自动重启并执行恢复演练 | 备份文件、恢复结果、重启记录 |

## 03. 部署拓扑

```text
外部用户
  |  HTTPS / SSH
  v
ECS4 公网入口
  |  Tailscale 私网
  v
Mac Studio
  |-- GitLab Web / Git SSH / Git HTTPS
  |-- GitLab Runner
  |-- GitLab 数据目录
  |
  +--> ECS5 备份目标
```

## 04. 节点职责

### Mac Studio：核心服务节点

- 安装 Linux 容器运行环境，建议使用 Colima；如已有合适运行时，也可复用。
- 运行 GitLab 单节点服务和主要 Runner。
- 将配置、日志、仓库、数据库、制品和上传文件分别挂载到稳定的数据目录。
- 配置容器自动启动、主机不自动睡眠和服务健康检查。
- 只允许通过本机和 Tailscale 私网访问管理端口。

Mac Studio 已确认具备 24 核 CPU、64GB 内存和约 736GB 可用磁盘，满足首期运行条件。由于它使用 Apple Silicon，Runner 默认采用 ARM64 镜像；需要 amd64 时单独验证。

### ECS4：公网入口节点

- 保留固定公网 IP，开放 80、443，以及经过限制的 Git SSH 入口。
- 安装 Caddy 或 Nginx，负责域名、HTTPS 证书和反向代理。
- 通过 Tailscale 将 Web 请求转发到 Mac Studio。
- 将 Git SSH 连接转发到 Mac Studio 的 GitLab SSH 服务。
- 不保存 GitLab 仓库和核心业务数据。

### ECS5：备份节点

- 首期不承载用户访问和流水线任务。
- 通过 Tailscale 或受限 SSH 接收 GitLab 备份。
- 只开放备份所需的最小访问权限。
- 后续可在备份职责稳定后改作第二个 Runner 或备用入口。

## 05. 网络与访问实现

### 私网连接

1. Mac Studio 和 ECS4 加入同一个 Tailscale 网络。
2. 使用稳定的 Tailscale 地址或 MagicDNS 名称作为上游地址。
3. ECS4 只将必要请求转发到 Mac Studio，不把家庭网关端口映射到公网。
4. ECS5 使用同一私网接收备份，备份链路不经过公网入口代理。

### Web 与 Git 访问

- 域名的 A 记录指向 ECS4 公网 IP。
- Caddy 或 Nginx 在 ECS4 上完成 HTTPS。
- GitLab 的外部 URL 使用正式域名，避免后续从 IP 访问造成地址迁移。
- HTTPS Git 使用 GitLab 的标准 HTTPS 入口。
- SSH Git 使用 ECS4 的 22 端口转发到 GitLab SSH 服务；如果 ECS4 需要保留管理员 SSH，则使用独立公网端口或明确的 SSH 转发规则。

### 安全边界

- Mac Studio 不开放公网端口。
- ECS4 的管理 SSH 仅允许可信来源；公网 Git SSH 只转发 GitLab 所需流量。
- GitLab 首次登录后立即修改管理员密码并启用双因素认证。
- 每一层都使用最小权限账号和密钥，不把密码、Token 或私钥写入仓库。

## 06. 服务与数据实现

### GitLab 服务

- 使用官方 GitLab CE 容器镜像。
- 为配置、日志和数据分别设置持久化目录。
- 保留 GitLab 版本号、镜像摘要和部署配置。
- 通过 GitLab 健康端点和容器状态检查服务可用性。

### Runner 与流水线

- Runner 使用 Docker executor，便于隔离构建环境。
- 首个示例流水线只做依赖安装、测试、构建和制品保存。
- 构建镜像明确声明 `linux/arm64`；跨架构构建作为单独验证项。
- 流水线同时验证成功、失败、日志、重跑和制品读取。

### 备份与恢复

- 每日执行 GitLab 备份，保留多个历史版本。
- 将备份复制到 ECS5 的独立目录，并限制访问权限。
- 每个备份记录时间、版本、文件大小和校验结果。
- 至少定期恢复一个测试项目，验证备份可读取、可恢复。
- 主节点数据、入口节点配置和备份节点数据分别记录恢复方法。

## 07. 交付合格的判定链

交付不是“容器启动”就结束，而是沿着以下链路逐段验证：

1. 主节点能稳定运行 GitLab。
2. 私网链路能从 ECS4 抵达主节点。
3. 公网域名能通过 HTTPS 打开 GitLab。
4. 用户能用 SSH 和 HTTPS 完成完整 Git 操作。
5. Runner 能完成成功、失败、修复重跑和制品保存。
6. 备份能生成、复制、读取并恢复。
7. 重启和网络恢复后，服务能回到可用状态。

每一段都对应路线图中的一个独立里程碑，最后再进行全链路验收。

## 08. 交付边界

首期交付单节点、低运维、可访问、可构建、可备份的最小闭环。高可用、Kubernetes、对象存储、多地域容灾和复杂发布编排留到出现明确需求或瓶颈后再设计。

