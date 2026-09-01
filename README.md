# Private GitLab Repository Building

## 当前任务

- [六要素](current-task/six-elements.md)
- [总体方案](current-task/overall-solution.md)
- [路线图](current-task/roadmap.md)
- [相关环境](current-task/related-environment.md)

## Team Network

- [环境基线](docs/team-network/environment-baseline.md)
- [SSH 互信基线](docs/team-network/ssh-access-mesh.md)
- [总体设计](docs/team-network/overall-design.md)

Team Network 文档描述公司内网的持续建设方案；GitLab 迁移本身已经完成。当前 GitLab 运行在 Proxmox VM `9002`，Mac Studio 运行 Runner，ECS4 保留公网入口，ECS1 至 ECS6 通过 Tailscale 直连 GitLab VM；ECS3 Wiki 保持现状。总体设计包含 Tailscale 部署、策略、回退和验收方案。
