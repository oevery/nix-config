use crate::ops::{Host, Mode};

#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum Module {
    Mihomo,
    Multica,
    Magpie,
}
impl Module {
    pub fn name(self) -> &'static str {
        match self {
            Self::Mihomo => "Mihomo",
            Self::Multica => "Multica",
            Self::Magpie => "Magpie",
        }
    }
    pub fn unit(self) -> &'static str {
        match self {
            Self::Mihomo => "mihomo.service",
            Self::Multica => "multica-daemon.service",
            Self::Magpie => "magpie.service",
        }
    }
}
#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum Tab {
    Overview,
    Diagnostics,
}
#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum Verb {
    Start,
    Stop,
    Restart,
    Reload,
    Enable,
    Disable,
}
impl Verb {
    pub fn command(self) -> &'static str {
        match self {
            Self::Start => "start",
            Self::Stop => "stop",
            Self::Restart => "restart",
            Self::Reload => "reload",
            Self::Enable => "enable",
            Self::Disable => "disable",
        }
    }
    fn label(self) -> &'static str {
        match self {
            Self::Start => "启动服务",
            Self::Stop => "停止服务",
            Self::Restart => "重启服务",
            Self::Reload => "重载配置",
            Self::Enable => "开启自启",
            Self::Disable => "关闭自启",
        }
    }
}
#[derive(Clone, Copy, PartialEq)]
pub(super) enum ActionId {
    Plan(Mode),
    Apply(Mode),
    Diff,
    Check,
    Open(Module),
    Logs(Module),
    Control(Module, Verb),
    Refresh,
    Subscriptions,
    UpdateSource,
    Diagnose,
    Probe,
    Status(Module),
    Health,
    Entry,
    Engine,
    UpdateReport,
    ServiceControls,
}
use ActionId::*;
impl ActionId {
    pub fn index_label(self) -> String {
        match self {
            Plan(Mode::Daily) => "日常更新".into(),
            Probe => "验证网络出口".into(),
            Plan(Mode::All) => "完整系统更新".into(),
            Open(module) => module.name().into(),
            Logs(module) => format!("{} 日志", module.name()),
            _ => self.label().into(),
        }
    }
    pub fn section(self) -> super::dashboard::Target {
        use super::dashboard::Target;
        if matches!(self, Logs(_)) {
            Target::Logs
        } else if self.module().is_some() {
            Target::Services
        } else {
            Target::Maintenance
        }
    }
    pub fn label(self) -> &'static str {
        match self {
            Plan(Mode::Sync) => "同步已锁定配置",
            Plan(Mode::Daily) => "预览主机更新",
            Plan(Mode::All) => "预览完整系统更新",
            Apply(_) => "执行此计划",
            Diff => "查看锁文件变更",
            Check => "检查主机配置",
            Open(Module::Mihomo) => "管理 Mihomo",
            Open(Module::Multica) => "管理 Multica",
            Open(Module::Magpie) => "管理 Magpie",
            Logs(_) => "查看服务日志",
            Control(_, verb) => verb.label(),
            Refresh => "刷新状态",
            Subscriptions => "管理订阅",
            UpdateSource => "更新当前配置",
            Diagnose => "打开网络诊断",
            Probe => "验证指定接口",
            Status(_) => "查询服务状态",
            Health => "检查网关健康",
            Entry => "查看管理页入口",
            Engine => "检查执行环境",
            UpdateReport => "查看本次执行记录",
            ServiceControls => "服务控制",
        }
    }
    pub fn module(self) -> Option<Module> {
        match self {
            Open(module) | Logs(module) | Control(module, _) | Status(module) => Some(module),
            Refresh | Subscriptions | UpdateSource | Diagnose | Probe | ServiceControls => {
                Some(Module::Mihomo)
            }
            Health | Entry => Some(Module::Magpie),
            Engine => Some(Module::Multica),
            _ => None,
        }
    }
    pub fn impact(self) -> Option<&'static str> {
        match self {
            Control(_, Verb::Enable | Verb::Disable) => {
                Some("只更改开机自启，不立即改变运行状态。")
            }
            Control(_, _) => Some("将改变服务运行状态，现有连接或任务可能中断。"),
            Subscriptions => Some(
                "读取私有订阅列表需要管理员授权；旧来源可能迁移为当前订阅，不会下载或切换配置。",
            ),
            UpdateSource => Some("将刷新当前订阅并校验配置；配置改变且服务运行时将重启。"),
            Apply(Mode::All) => Some("将更新锁文件、应用配置并执行宿主操作系统更新。"),
            Apply(Mode::Daily) => Some("将快进同步、更新锁文件、应用配置并更新 mise 工具。"),
            Apply(Mode::Sync) => Some("将快进同步并按锁文件应用配置；可能重启服务。"),
            _ => None,
        }
    }
}
pub(super) fn home(host: &Host) -> Vec<ActionId> {
    let mut tasks = vec![Plan(Mode::Sync), Plan(Mode::Daily), Diff];
    for module in [Module::Mihomo, Module::Multica, Module::Magpie] {
        if host.has(&module.name().to_ascii_lowercase()) {
            tasks.push(Open(module));
        }
    }
    tasks
}
pub(super) fn module_actions(module: Module, status: &serde_json::Value) -> Vec<ActionId> {
    let mut actions = match module {
        Module::Multica => vec![Status(module), Logs(module), Engine],
        Module::Magpie => vec![Health, Logs(module), Status(module), Entry],
        Module::Mihomo => {
            let mut items = if status["state"] == "failed" {
                vec![Logs(module), UpdateSource, Subscriptions]
            } else if status["source_set"] == false {
                vec![Subscriptions, UpdateSource, Logs(module)]
            } else {
                vec![UpdateSource, Subscriptions, Logs(module)]
            };
            let verbs: &[Verb] = match status["state"].as_str() {
                Some("running") => &[Verb::Reload, Verb::Restart, Verb::Stop],
                Some("stopped" | "failed") => &[Verb::Start],
                _ => return items,
            };
            items.extend(verbs.iter().map(|verb| Control(module, *verb)));
            if let Some(enabled) = status["autostart"].as_bool() {
                items.push(Control(
                    module,
                    if enabled { Verb::Disable } else { Verb::Enable },
                ));
            }
            return items;
        }
    };
    actions.extend([Verb::Start, Verb::Stop, Verb::Restart].map(|verb| Control(module, verb)));
    actions
}
