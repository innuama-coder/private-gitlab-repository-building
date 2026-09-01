---
id: team-network-ssh-access-mesh
title: Team Network SSH 互信基线
document_kind: environment-baseline
language: zh-CN
version: 1.1
status: verified
verified_at: 2026-08-31
---

# Team Network SSH 互信基线

## 1. 环境范围

已纳入以下十个环境：

- 本地 MacBook
- Mac Studio
- ECS1 至 ECS6
- `vircs-dev`
- `vircs-windows-runner`

本地 MacBook 仍是控制端和备份目标，不运行 GitLab 核心服务；本次只把它纳入 SSH 管理互信网。

## 2. 身份与密钥

- 所有环境统一使用 SSH 用户 `kunora`。
- 每个环境各自持有一把独立 Ed25519 私钥：`~/.ssh/id_ed25519_team_network`。
- Windows Agent 的标准私钥路径为 `C:\Users\kunora\.ssh\id_ed25519_team_network`。
- 十个环境只交换公钥；没有复制、共享或集中保存私钥。
- 每个目标的 `authorized_keys` 保留原内容，并包含十个团队环境公钥。
- SSH 配置启用 `IdentitiesOnly yes`、`BatchMode yes` 和 `StrictHostKeyChecking accept-new`。
- 本地 MacBook 的 `kunora` 是普通账号，只加入 macOS SSH 访问组，没有管理员权限。

## 3. 统一入口

| 环境 | SSH 别名 |
| --- | --- |
| ECS1 至 ECS6 | `team-ecs1` 至 `team-ecs6` |
| Mac Studio | `team-mac-studio` |
| 本地 MacBook | `team-local-macbook` |
| Linux Agent | `team-vircs-dev` |
| Windows Agent | `team-vircs-windows-runner` |

ECS1 至 ECS6 使用固定公网 IP 作为 SSH 管理入口。已加入 Tailscale 的节点通过 `100.65.102.93` 访问 Mac Studio，通过 `100.126.98.93` 访问本地 MacBook；两台未加入 Tailscale 的远程 Agent 通过 `team-ecs4` 跳转到这两台 Mac。各节点访问互联网时仍使用自己的默认出口，不使用 Exit Node。

## 4. 验收结果

十个环境之间共 90 条非自连有向连接已经逐条执行：

```text
ssh <team-alias> id -un
```

全部连接返回 `kunora`，退出码为 `0`。验证使用各环境自己的团队私钥和非交互模式，没有密码认证或共享私钥兜底。

Linux OpenSSH 10 连接 Windows OpenSSH 9.5 时会提示未使用后量子密钥交换；该提示不影响 Ed25519 公钥认证和本次连通性验收，后续随 Windows OpenSSH 升级消除。

## 5. 回退与安全边界

- Unix/macOS 环境的原 `authorized_keys` 和 SSH 配置已保留带 `codex-20260831.before-team-mesh` 后缀的备份。
- Windows Agent 的标准授权文件和当前用户 SSH 配置也已保留同名备份。
- 任一节点失陷后都可能使用自己的密钥访问其他九个节点。节点退役或失陷时，必须立即从其余九个目标的 `authorized_keys` 删除对应公钥，并撤销相关网络入口。
- SSH 互信只提供 `kunora` 登录能力，不自动赋予 `root`、`sudo`、GitLab 管理员或其他应用权限。
