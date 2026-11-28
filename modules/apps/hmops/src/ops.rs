use serde::Deserialize;
use serde_json::{json, Value};
use std::{
    env, fs,
    path::PathBuf,
    process::{Command, Stdio},
};

#[derive(Clone, Deserialize)]
pub struct Host {
    pub name: String,
    pub system: String,
    pub modules: Vec<String>,
}
#[derive(PartialEq, Clone, Copy)]
pub enum Mode {
    Sync,
    Daily,
    All,
}
#[derive(Clone, Copy)]
pub struct Step {
    pub label: &'static str,
    program: &'static str,
    args: &'static [&'static str],
}
impl Step {
    fn new(label: &'static str, program: &'static str, args: &'static [&'static str]) -> Self {
        Self {
            label,
            program,
            args,
        }
    }
    pub fn foreground(&self) -> bool {
        !matches!(self.program, "flu") && !self.args.contains(&"--porcelain")
    }
    pub fn execute(&self, interactive: bool, quiet: bool) -> Result<(), String> {
        let mut cmd = Command::new(self.program);
        cmd.current_dir(repo()?);
        if !interactive {
            cmd.stdin(Stdio::null())
                .env("GIT_TERMINAL_PROMPT", "0")
                .env("HMOPS_NONINTERACTIVE", "1");
            if self.program == "sudo" {
                cmd.arg("-n");
            }
        }
        cmd.args(self.args);
        if self.args.contains(&"--porcelain") {
            let result = cmd.output().map_err(|err| err.to_string())?;
            if !result.status.success() {
                return Err("无法读取仓库状态".into());
            }
            if !result.stdout.is_empty() {
                return Err("有本地改动，请先处理；未同步、暂存或重置".into());
            }
            return Ok(());
        }
        if quiet {
            cmd.stdout(Stdio::null()).stderr(Stdio::null());
        }
        let status = cmd.status().map_err(|err| err.to_string())?;
        if status.success() {
            Ok(())
        } else {
            Err(format!(
                "{} ({status})；{}",
                self.program,
                if quiet {
                    "请单独检查此命令和工作区"
                } else {
                    "请检查终端中的命令输出"
                }
            ))
        }
    }
}
pub fn failure(steps: &[Step], index: usize, reason: String) -> String {
    let pending = steps[index + 1..]
        .iter()
        .map(|item| item.label)
        .collect::<Vec<_>>()
        .join("、");
    format!(
        "{}失败：{reason}。已完成 {index} 步，不自动回滚；未执行：{}",
        steps[index].label,
        if pending.is_empty() { "无" } else { &pending }
    )
}
pub fn repo() -> Result<PathBuf, String> {
    Ok(PathBuf::from(env::var_os("HOME").ok_or("缺少 HOME")?).join(".config/home-manager"))
}
pub fn command(program: &str, args: &[&str]) -> Result<(), String> {
    let status = Command::new(program)
        .args(args)
        .status()
        .map_err(|err| format!("{program}: {err}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{program} 未成功（{status}）"))
    }
}
pub fn output(program: &str, args: &[&str]) -> Result<String, String> {
    let result = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .output()
        .map_err(|err| format!("{program}: {err}"))?;
    if !result.status.success() {
        return Err(format!("{program}：查询失败（{}）", result.status));
    }
    Ok(String::from_utf8_lossy(&result.stdout).trim().to_owned())
}
pub fn describe(value: &Value) -> String {
    serde_json::to_string_pretty(value).unwrap_or_default()
}
impl Host {
    pub fn load() -> Result<Self, String> {
        let base = env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".config")))
            .ok_or("缺少用户配置目录")?;
        let raw = fs::read(base.join("hmops/host.json"))
            .map_err(|err| format!("无法读取主机清单；请确认主机启用 apps/hmops：{err}"))?;
        serde_json::from_slice(&raw).map_err(|err| format!("主机清单无效：{err}"))
    }
    pub fn has(&self, module: &str) -> bool {
        self.modules
            .iter()
            .any(|entry| entry.strip_prefix("apps/") == Some(module))
    }
    pub fn status(&self) -> Value {
        let mut services = serde_json::Map::new();
        for (name, unit) in [
            ("multica", "multica-daemon.service"),
            ("magpie", "magpie.service"),
        ] {
            if self.has(name) {
                services.insert(
                    name.into(),
                    match output(
                        "systemctl",
                        &[
                            "--user",
                            "show",
                            "--property=LoadState,ActiveState,SubState",
                            unit,
                        ],
                    ) {
                        Ok(text) => json!(text
                            .lines()
                            .filter_map(|line| line.split_once('='))
                            .collect::<std::collections::BTreeMap<_, _>>()),
                        Err(reason) => json!({"error":reason}),
                    },
                );
            }
        }
        if self.has("mihomo") {
            services.insert(
                "mihomo".into(),
                output("mihomoctl", &["status", "--json"])
                    .and_then(|text| {
                        serde_json::from_str(&text).map_err(|_| "模块返回无效状态".into())
                    })
                    .unwrap_or_else(|reason| json!({"error":reason})),
            );
        }
        json!({"host":self.name,"system":self.system,"modules":self.modules,"services":services})
    }
    pub fn steps(&self, mode: Mode) -> Vec<Step> {
        let mac = self.system.ends_with("-darwin");
        let mut steps = vec![
            Step::new(
                "检查工作区",
                "git",
                &["status", "--porcelain", "--untracked-files=all"],
            ),
            Step::new("快进同步仓库", "git", &["pull", "--ff-only", "--no-rebase"]),
        ];
        if mode != Mode::Sync {
            steps.push(Step::new("更新锁文件", "flu", &[]))
        }
        steps.push(Step::new(
            "检查并应用配置",
            if mac { "drs" } else { "hms" },
            &[],
        ));
        if mode != Mode::Sync {
            steps.push(Step::new("更新全局工具", "mise", &["upgrade", "--global"]))
        }
        if mode == Mode::All {
            if mac {
                steps.push(Step::new(
                    "更新 macOS",
                    "/usr/sbin/softwareupdate",
                    &["-ia"],
                ))
            } else {
                steps.push(Step::new("更新系统软件索引", "sudo", &["apt", "update"]));
                steps.push(Step::new("升级系统软件", "sudo", &["apt", "upgrade"]));
            }
        }
        steps
    }
    pub fn update(
        &self,
        mode: Mode,
        interactive: bool,
        machine: bool,
        mut emit: impl FnMut(String),
    ) -> Result<(), String> {
        let steps = self.steps(mode);
        for (index, step) in steps.iter().enumerate() {
            emit(format!("› {}", step.label));
            if let Err(reason) = step.execute(interactive, machine) {
                if machine {
                    println!(
                        "{}",
                        json!({"ok":false,"code":"STEP_FAILED","step":step.program,"stage":step.label,
                        "completed":steps[..index].iter().map(|step|step.label).collect::<Vec<_>>(),
                        "remaining":steps[index+1..].iter().map(|step|step.label).collect::<Vec<_>>(),"reason":reason})
                    );
                }
                return Err(failure(&steps, index, reason));
            }
            emit(format!("✓ {}", step.label));
        }
        if machine {
            println!(
                "{}",
                json!({"ok":true,"completed":steps.iter().map(|step|step.label).collect::<Vec<_>>() })
            );
        }
        Ok(())
    }
}
