---
title: Archive Index
summary: Completed RSP changes.
kind: generated-index
index_type: archives
source_dir: .rsp/archives
entry_count: 3
---

# Archive Index

| Date | Change | Kind | Summary |
|------|--------|------|---------|
| 2026-05-23 | rsp-bootstrap | ops | 将初始化后的 `.rsp/` 骨架补齐为可直接使用的项目工作流文档。 |
| 2026-05-24 | kilo-zombie-cleaner | feature | 跨平台定时清理 Kilo Code、MCP 服务及命令遗留孤儿/僵尸进程的自动化脚本，通过 launchd (macOS) / systemd timer (Linux) 自动调度执行。 |
| 2026-05-27 | kilo-cleaner-log-optimization | refactor | 优化 `kilo-cleaner` 日志输出与平台日志接线，减少噪音并保持日志可读。 |