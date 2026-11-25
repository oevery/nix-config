# home-manager

<!-- rsp:begin -->
## RSP Entry

RSP tracks current work, stable specs, and archives under `.rsp/`.

Use supplied or confirmed paths; discover only missing paths or applicable ancestor instructions, without overlapping whole-tree scans:
1. Nearest `AGENTS.md` for project or module instructions.
2. Root `CONTEXT.md` if present, then the relevant nearest `CONTEXT.md` for domain language, relationships, and navigation. If a legacy `CONTEXT-MAP.md` remains, retain its relevant context and use Core's context-migration branch; discovery alone does not authorize migration.
3. Establish the request's scope, authority and existing owner. A clear bounded request selecting one capability with sufficient owner facts loads that project Skill directly from `.agents/skills/`, without a Core or Focus preflight. For tracked work read the selected Change; for grouped work read its sibling Group Brief first. Read only relevant Specs and Decision Records under the configured authoritative path.
4. Load `rsp` at `.agents/skills/rsp/SKILL.md` for unresolved routing or ownership, actual cross-capability coordination, or lifecycle operations. Read `.rsp/focus.d/` only when needed to resolve or recover the owner; marker paths are open-work candidates and optional bounded Markdown is recovery guidance, not authority. An explicit WorkRef or the user's mentioned Change selects first; otherwise use current status and dependency evidence.

Direct capability invocation does not make tracked work untracked. Preserve existing Changes, required tracking prerequisites, Group dependencies, independent review and permission boundaries; missing prerequisites stop dependent work. Skills are the only workflow: hosts may discover them or read them directly, but a missing or unusable required Skill stops dependent work and must be reported as an incomplete installation. Do not use retired Rules or install implicitly.
Do not treat `.rsp/specs/` or `.rsp/changes/` as replacements for nearest `AGENTS.md` or `CONTEXT.md`.

This project pins RSP `4.2.0` in `.rsp/version`. For every CLI operation use `npx -y @oevery/rsp@4.2.0 <command>` (or a verified executable of that exact version). Skill examples use `rsp` as shorthand for this selected invocation. Never substitute `@latest`, a version range, or an unverified global CLI. Package fetching requires authority; if unavailable, report the gap. Only an authorized upgrade uses a deliberately selected target CLI with `update`; it updates the complete managed environment. Notices grant no upgrade authority.
<!-- rsp:end -->

## 项目验证

- 运行 `nix flake check` 验证当前平台的构建；使用 `nix flake check --all-systems --no-build --no-write-lock-file` 检查所有平台的求值。单台主机可直接求值对应 Home Manager 激活包或 Darwin 系统的 `drvPath`。
- 安装、日常命令与排障说明写入 `README.md` 或 `docs/`；主机装配与配置边界见 `.rsp/specs/design.md`。
