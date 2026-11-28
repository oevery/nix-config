mod actions;
mod badge;
mod dashboard;
mod overview;
mod reader;
mod subscriptions;
mod theme;
mod view;
use crate::ops::{command, failure, output, repo, Host, Mode, Step};
use actions::{ActionId, ActionId::*, Module, Tab};
use crossterm::{
    event::{
        self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind, MouseButton,
        MouseEventKind,
    },
    execute,
    terminal::{self, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};
use reader::Reader;
use serde_json::Value;
use std::{
    env, fs,
    io::{self, IsTerminal, Write},
    process::{Command, Stdio},
    sync::mpsc::{self, Receiver, TryRecvError},
    thread,
    time::{Duration, Instant},
};

type Display = Terminal<CrosstermBackend<io::Stdout>>;
type Reply<T> = Result<T, String>;
fn spawn<T: Send + 'static>(
    work: impl FnOnce() -> Reply<T> + Send + 'static,
) -> Receiver<Reply<T>> {
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        let _ = tx.send(work());
    });
    rx
}
fn poll<T>(rx: &Receiver<Reply<T>>) -> Option<Reply<T>> {
    match rx.try_recv() {
        Ok(result) => Some(result),
        Err(TryRecvError::Empty) => None,
        Err(TryRecvError::Disconnected) => Some(Err("后台任务已中断".into())),
    }
}
fn enter() -> Reply<Display> {
    terminal::enable_raw_mode().map_err(|e| e.to_string())?;
    execute!(io::stdout(), EnterAlternateScreen, EnableMouseCapture).map_err(|e| e.to_string())?;
    Terminal::new(CrosstermBackend::new(io::stdout())).map_err(|e| e.to_string())
}
fn leave() -> io::Result<()> {
    terminal::disable_raw_mode()?;
    execute!(
        io::stdout(),
        DisableMouseCapture,
        LeaveAlternateScreen,
        crossterm::cursor::Show
    )
}
struct Restore;
impl Drop for Restore {
    fn drop(&mut self) {
        let _ = leave();
    }
}

#[derive(Clone, Copy, PartialEq)]
enum Route {
    Home,
    Maintenance,
    Services,
    Logs,
    Module(Module, Tab),
    Plan(Mode),
}
impl Route {
    fn section(self) -> dashboard::Target {
        use dashboard::Target;
        match self {
            Self::Home => Target::Overview,
            Self::Maintenance | Self::Plan(_) => Target::Maintenance,
            Self::Services | Self::Module(..) => Target::Services,
            Self::Logs => Target::Logs,
        }
    }
    fn module(self) -> Option<Module> {
        if let Self::Module(module, _) = self {
            Some(module)
        } else {
            None
        }
    }
}
enum Outlet {
    Idle,
    Waiting(String, Receiver<Reply<()>>),
    Receipt(String, Reply<()>),
}
enum Overlay {
    None,
    Help,
    Confirm(ActionId),
    Input,
    Reader(Reader),
    Subscriptions(subscriptions::Panel),
}
struct LogOrigin {
    module: Module,
    breadcrumb: String,
    previous: Overlay,
    resume_follow: bool,
    header_focus: bool,
    target: dashboard::Target,
}
struct UpdateJob {
    steps: Vec<Step>,
    index: usize,
    worker: Option<Receiver<Reply<()>>>,
}
struct State {
    route: Route,
    focus: usize,
    home_focus: usize,
    overlay: Overlay,
    machine: String,
    system: String,
    overview: overview::Overview,
    home_target: dashboard::Target,
    header_focus: bool,
    reentered: bool,
    palette: Option<(String, usize)>,
    boot: Option<Instant>,
    capacity: Option<(u64, u8)>,
    status: Value,
    query: Option<Receiver<Reply<Value>>>,
    status_error: String,
    services: Option<Value>,
    services_query: Option<Receiver<Reply<Value>>>,
    compact: bool,
    controls_open: bool,
    interface: String,
    hinted: Option<String>,
    outlet: Outlet,
    note: String,
    job: Option<UpdateJob>,
    report: Vec<String>,
    report_mode: Option<Mode>,
    motion: String,
    opened: Instant,
}
impl State {
    fn is_home(&self) -> bool {
        self.route == Route::Home && matches!(self.overlay, Overlay::None)
    }
    fn has_changes(&self) -> bool {
        self.overview
            .identity
            .as_ref()
            .is_some_and(|info| info.changes.is_some())
    }
    fn boot_progress(&self) -> Option<f64> {
        let duration = match self.motion.as_str() {
            "full" => 0.6,
            "reduced" => 0.16,
            _ => return None,
        };
        let progress = self.boot?.elapsed().as_secs_f64() / duration;
        (progress < 1.).then_some(progress)
    }
    fn nav_enabled(&self) -> bool {
        self.job.is_none()
            && self.palette.is_none()
            && !matches!(
                self.overlay,
                Overlay::Confirm(_) | Overlay::Input | Overlay::Help | Overlay::Subscriptions(_)
            )
    }
    fn content_focused(&self) -> bool {
        !self.header_focus && self.palette.is_none() && matches!(self.overlay, Overlay::None)
    }
    fn open_logs(&mut self, module: Module) {
        let mut previous = std::mem::replace(&mut self.overlay, Overlay::None);
        let (breadcrumb, resume_follow) = match &mut previous {
            Overlay::Reader(reader) => (
                format!("{} / {}", reader.title, module.name()),
                reader.stop(),
            ),
            _ => {
                let mut path = self.route.section().label().to_owned();
                match self.route {
                    Route::Plan(mode) => path.push_str(&format!(" / {}", Plan(mode).index_label())),
                    Route::Module(owner, tab) => {
                        path.push_str(&format!(" / {}", owner.name()));
                        if tab == Tab::Diagnostics {
                            path.push_str(" / 网络诊断");
                        }
                    }
                    _ => {}
                }
                if self.route.module() != Some(module) {
                    path.push_str(&format!(" / {}", module.name()));
                }
                (path, false)
            }
        };
        self.overlay = Overlay::Reader(Reader::logs(LogOrigin {
            module,
            breadcrumb,
            previous,
            resume_follow,
            header_focus: self.header_focus,
            target: self.home_target,
        }));
        self.header_focus = false;
    }
    fn close_reader(&mut self) {
        if let Overlay::Reader(mut reader) = std::mem::replace(&mut self.overlay, Overlay::None) {
            reader.stop();
            if let Some(origin) = reader.origin.take() {
                self.header_focus = origin.header_focus;
                self.home_target = origin.target;
                self.overlay = origin.previous;
                if origin.resume_follow {
                    if let Overlay::Reader(previous) = &mut self.overlay {
                        previous.connect();
                    }
                }
            }
        }
    }
    fn activate_nav(&mut self, target: dashboard::Target) {
        use dashboard::Target;
        if target == Target::Search {
            self.palette = Some((String::new(), 0));
            return;
        }
        self.header_focus = false;
        self.home_target = target;
        match target {
            Target::Overview => {
                self.overlay = Overlay::None;
                self.go(Route::Home)
            }
            Target::Changes => {
                if let Some(changes) = self
                    .overview
                    .identity
                    .as_ref()
                    .and_then(|info| info.changes.clone())
                {
                    self.overlay =
                        Overlay::Reader(Reader::text("配置仓库 / 工作区改动".into(), changes));
                }
            }
            Target::Maintenance | Target::Services | Target::Logs => {
                self.overlay = Overlay::None;
                self.go(match target {
                    Target::Maintenance => Route::Maintenance,
                    Target::Services => Route::Services,
                    _ => Route::Logs,
                });
            }
            Target::Search => unreachable!(),
        }
    }
    fn items(&self, host: &Host) -> Vec<ActionId> {
        match self.route {
            Route::Home => actions::home(host),
            Route::Maintenance | Route::Services | Route::Logs => self
                .search(host, "")
                .into_iter()
                .filter(|id| self.route.section().accepts(*id))
                .collect(),
            Route::Plan(mode) => {
                let mut items = vec![Apply(mode), Diff];
                if mode != Mode::All {
                    items.push(Plan(Mode::All));
                }
                if !self.report.is_empty() {
                    items.insert(0, UpdateReport);
                }
                items
            }
            Route::Module(Module::Mihomo, Tab::Diagnostics) => vec![Probe, Logs(Module::Mihomo)],
            Route::Module(module, _) => {
                let mut items = actions::module_actions(module, &self.status);
                if module == Module::Mihomo && self.compact {
                    if let Some(index) = items.iter().position(|item| matches!(item, Control(..))) {
                        if !self.controls_open {
                            items.truncate(index);
                        }
                        items.insert(index, ServiceControls);
                    }
                }
                items
            }
        }
    }
    fn search(&self, host: &Host, text: &str) -> Vec<ActionId> {
        let mut list = actions::home(host);
        list.extend([Plan(Mode::All), Check]);
        for module in [Module::Mihomo, Module::Multica, Module::Magpie] {
            if list.contains(&Open(module)) {
                list.extend(actions::module_actions(module, &self.status));
                if module == Module::Mihomo {
                    list.extend([Diagnose, Refresh, Probe]);
                }
            }
        }
        if !self.report.is_empty() {
            list.push(UpdateReport);
        }
        let text = text.to_lowercase();
        list.retain(|item| {
            format!(
                "{} {} {} {}",
                item.section().label(),
                item.module().map_or("主机", Module::name),
                item.label(),
                item.index_label()
            )
            .to_lowercase()
            .contains(&text)
        });
        if let Some(module) = self.route.module() {
            list.sort_by_key(|a| a.module() != Some(module));
        }
        list
    }
    fn refresh(&mut self) {
        self.status_error.clear();
        self.query = Some(spawn(|| {
            let data = output("mihomoctl", &["status", "--json"])
                .map_err(|err| format!("{err}；请确认使用配套新版 mihomoctl"))?;
            let parsed: Value =
                serde_json::from_str(&data).map_err(|_| "控制器未返回 JSON 状态")?;
            if !parsed["state"].is_string() {
                return Err("控制器状态格式不兼容，请使用配套新版 mihomoctl".into());
            }
            Ok(parsed)
        }));
    }
    fn go(&mut self, next: Route) {
        if self.route == Route::Home {
            self.home_focus = self.focus;
        }
        if next.module() == Some(Module::Mihomo) && self.route.module() != Some(Module::Mihomo) {
            self.status = Value::Null;
            self.hinted = None;
            self.refresh();
        }
        if next == Route::Services {
            self.services = None;
            self.query = None;
            self.status = Value::Null;
        }
        self.controls_open = false;
        if matches!(next, Route::Plan(_)) {
            self.capacity = store_space();
        }
        self.route = next;
        self.home_target = next.section();
        self.header_focus = false;
        if next == Route::Home {
            self.overview.refresh()
        }
        self.focus = if next == Route::Home {
            self.home_focus
        } else {
            0
        };
        self.note.clear();
        self.opened = Instant::now();
    }
    fn foreground(
        &mut self,
        display: &mut Display,
        work: impl FnOnce() -> Reply<String>,
    ) -> Reply<()> {
        leave().map_err(|err| err.to_string())?;
        let result = work();
        self.note = result.unwrap_or_else(|reason| format!("× {reason}"));
        println!("{}\n按 Enter 返回控制台。", self.note);
        io::stdin()
            .read_line(&mut String::new())
            .map_err(|e| e.to_string())?;
        *display = enter()?;
        self.reentered = true;
        Ok(())
    }
    fn dispatch(
        &mut self,
        action: ActionId,
        host: &Host,
        display: &mut Display,
        confirmed: bool,
    ) -> Reply<()> {
        if self.job.is_some() {
            self.note = "更新正在执行，请等待本步骤结束".into();
            return Ok(());
        }
        if !confirmed && action.impact().is_some() {
            self.overlay = Overlay::Confirm(action);
            return Ok(());
        }
        match action {
            Open(module) => self.go(Route::Module(module, Tab::Overview)),
            Subscriptions => {
                match subscriptions::terminal(display, subscriptions::Panel::load)? {
                    Ok(panel) => self.overlay = Overlay::Subscriptions(panel),
                    Err(reason) => self.note = reason,
                }
                self.reentered = true;
                self.refresh();
            }
            ServiceControls => self.controls_open = !self.controls_open,
            Plan(mode) => self.go(Route::Plan(mode)),
            Apply(mode) => {
                self.report.clear();
                self.report_mode = Some(mode);
                self.note.clear();
                self.focus = 0;
                self.job = Some(UpdateJob {
                    steps: host.steps(mode),
                    index: 0,
                    worker: None,
                });
            }
            Logs(module) => self.open_logs(module),
            Diff => {
                let path = repo()?;
                let data = Command::new("git")
                    .current_dir(path)
                    .args([
                        "diff",
                        "--no-ext-diff",
                        "--no-textconv",
                        "--color=never",
                        "HEAD",
                        "--",
                        "flake.lock",
                    ])
                    .output();
                let text = match data {
                    Ok(out) if out.status.success() => String::from_utf8_lossy(&out.stdout)
                        .lines()
                        .take(4000)
                        .map(clean)
                        .collect::<Vec<_>>()
                        .join("\n"),
                    _ => "无法读取 flake.lock 差异，请检查仓库。".into(),
                };
                self.overlay = Overlay::Reader(Reader::text(
                    "配置仓库 / 锁文件变更".into(),
                    if text.is_empty() {
                        "没有锁文件变更".into()
                    } else {
                        text
                    },
                ));
            }
            UpdateReport => {
                self.overlay = Overlay::Reader(Reader::text(
                    "主机更新 / 执行记录".into(),
                    self.report.join("\n"),
                ))
            }
            Refresh => {
                if self.route.module() != Some(Module::Mihomo) {
                    self.go(Route::Module(Module::Mihomo, Tab::Overview));
                } else {
                    self.refresh();
                }
            }
            Diagnose => self.go(Route::Module(Module::Mihomo, Tab::Diagnostics)),
            Probe => {
                if self.route != Route::Module(Module::Mihomo, Tab::Diagnostics) {
                    self.go(Route::Module(Module::Mihomo, Tab::Diagnostics));
                }
                if !matches!(self.outlet, Outlet::Waiting(..)) {
                    if self.interface.is_empty() {
                        self.interface = self.hinted.clone().unwrap_or_default();
                    }
                    self.overlay = Overlay::Input;
                }
            }
            UpdateSource | Control(_, _) | Check => {
                if matches!(action, Control(Module::Mihomo, _))
                    && !actions::module_actions(Module::Mihomo, &self.status).contains(&action)
                {
                    self.note = "当前状态不支持此操作，请刷新后重试".into();
                    return Ok(());
                }
                if action.module() == Some(Module::Mihomo)
                    && matches!(self.outlet, Outlet::Waiting(..))
                {
                    self.note = "请等待当前出口探测完成".into();
                    return Ok(());
                }
                self.foreground(display, || run_privileged_or_check(action))?;
                if action.module() == Some(Module::Mihomo) {
                    self.outlet = Outlet::Idle;
                    self.interface.clear();
                    self.hinted = None;
                    self.status = Value::Null;
                    self.refresh();
                }
            }
            Status(module) => {
                self.overlay = Overlay::Reader(Reader::text(
                    format!("{} / 服务状态", module.name()),
                    output(
                        "systemctl",
                        &[
                            "--user",
                            "show",
                            "-p",
                            "LoadState,ActiveState,SubState",
                            module.unit(),
                        ],
                    )
                    .unwrap_or_else(|reason| reason),
                ))
            }
            Health | Engine => self.foreground(display, || {
                if action == Health {
                    command("magpie", &["healthcheck"])?;
                } else {
                    command("omp", &["--version"])?;
                }
                Ok("检查完成".into())
            })?,
            Entry => self.note = "默认网关：127.0.0.1:63430；自定义监听以本机服务配置为准。".into(),
        }
        Ok(())
    }
    fn tick(&mut self, host: &Host, display: &mut Display) -> Reply<bool> {
        let mut dirty = false;
        if self.route == Route::Services && self.services.is_none() && self.services_query.is_none()
        {
            let host = host.clone();
            self.services_query = Some(spawn(move || Ok(host.status())));
        }
        if let Some(result) = self.services_query.as_ref().and_then(poll) {
            let snapshot = result.unwrap_or(Value::Null);
            if self.route == Route::Services {
                self.status = snapshot["services"]["mihomo"].clone();
            }
            self.services = Some(snapshot);
            self.services_query = None;
            dirty = true;
        }
        if let Some(result) = self.query.as_ref().and_then(poll) {
            let initial_detail = self.route == Route::Module(Module::Mihomo, Tab::Overview)
                && self.status.is_null()
                && self.focus == 0
                && matches!(self.overlay, Overlay::None);
            let selected = (!initial_detail)
                .then(|| self.items(host).get(self.focus).copied())
                .flatten();
            let search_selection = if let Some((text, pick)) = &self.palette {
                self.search(host, text).get(*pick).copied()
            } else {
                None
            };
            self.query = None;
            match result {
                Ok(value) => {
                    self.hinted = value["tun_device"].as_str().map(str::to_owned);
                    self.status = value;
                }
                Err(reason) => {
                    self.status = Value::Null;
                    self.hinted = None;
                    self.status_error = reason;
                }
            }
            self.focus = selected
                .and_then(|id| self.items(host).iter().position(|item| *item == id))
                .unwrap_or(0);
            if let Some((text, _)) = &self.palette {
                let pick = search_selection
                    .and_then(|id| self.search(host, text).iter().position(|item| *item == id))
                    .unwrap_or(0);
                self.palette = Some((text.clone(), pick));
            }
            dirty = true;
        }
        if let Outlet::Waiting(name, rx) = &self.outlet {
            if let Some(result) = poll(rx) {
                self.outlet = Outlet::Receipt(name.clone(), result);
                dirty = true;
            }
        }
        if let Overlay::Reader(reader) = &mut self.overlay {
            dirty |= reader.poll();
        }
        if let Some(job) = &mut self.job {
            let step = job.steps[job.index];
            let result = if let Some(rx) = &job.worker {
                poll(rx)
            } else if step.foreground() {
                leave().map_err(|e| e.to_string())?;
                println!("控制台 › {}", step.label);
                let result = step.execute(true, false);
                if let Err(reason) = &result {
                    println!("{reason}\n按 Enter 返回执行记录。");
                    io::stdin()
                        .read_line(&mut String::new())
                        .map_err(|e| e.to_string())?;
                }
                *display = enter()?;
                self.reentered = true;
                Some(result)
            } else {
                job.worker = Some(spawn(move || step.execute(false, true)));
                None
            };
            if let Some(result) = result {
                job.worker = None;
                match result {
                    Ok(()) => {
                        self.report.push(format!("✓ {}", step.label));
                        job.index += 1;
                        if job.index == job.steps.len() {
                            self.job = None;
                            self.note = "更新完成".into();
                        }
                    }
                    Err(reason) => {
                        self.report
                            .push(format!("× {}", failure(&job.steps, job.index, reason)));
                        for step in &job.steps[job.index + 1..] {
                            self.report.push(format!("— {} · 未执行", step.label));
                        }
                        self.job = None;
                        self.focus = 0;
                        self.note = "更新已停止，工作区未自动回滚".into();
                    }
                }
                dirty = true;
            }
        }
        Ok(dirty)
    }
}
fn clean(text: &str) -> String {
    text.chars().filter(|ch| !ch.is_control()).collect()
}
fn store_space() -> Option<(u64, u8)> {
    let data = output("df", &["-Pk", "/nix/store"]).ok()?;
    let mut fields = data.lines().last()?.split_whitespace();
    let available = fields.nth(3)?.parse().ok()?;
    let used = fields.next()?.strip_suffix('%')?.parse().ok()?;
    Some((available, used))
}
fn probe(interface: String) -> Receiver<Reply<()>> {
    spawn(move || {
        let out = Command::new("mihomoctl")
            .args(["probe", &interface])
            .stdin(Stdio::null())
            .output()
            .map_err(|err| format!("无法启动 mihomoctl：{err}"))?;
        if out.status.success() {
            return Ok(());
        }
        Err(
            match String::from_utf8_lossy(&out.stderr)
                .trim()
                .strip_prefix("mihomoctl: ")
            {
                Some(
                    reason @ ("指定接口不存在，未执行出口验证。"
                    | "指定接口不是 TUN，未执行出口验证。"
                    | "指定 TUN 接口未取得预期 HTTPS 204 回执。"),
                ) => reason.into(),
                _ => format!("未取得回执（{}），请检查接口与服务。", out.status),
            },
        )
    })
}
fn run_privileged_or_check(action: ActionId) -> Reply<String> {
    match action {
        UpdateSource => subscriptions::apply_message(&["config", "update", "--json"]),
        Control(Module::Mihomo, verb) => {
            command("mihomoctl", &[verb.command()])?;
            Ok(if matches!(verb, actions::Verb::Reload) {
                "已发送重载请求，实际加载结果请查看日志"
            } else {
                "操作完成"
            }
            .into())
        }
        Control(module, verb) => {
            command("systemctl", &["--user", verb.command(), module.unit()])?;
            Ok("操作完成".into())
        }
        Check => {
            command("hc", &[])?;
            Ok("检查完成".into())
        }
        _ => Err("非前台操作".into()),
    }
}

fn shift(focus: usize, delta: isize, len: usize) -> usize {
    (focus as isize + delta).rem_euclid(len.max(1) as isize) as usize
}
fn key(state: &mut State, host: &Host, display: &mut Display, code: KeyCode) -> Reply<bool> {
    if let Some((mut text, mut pick)) = state.palette.take() {
        let found = state.search(host, &text);
        match code {
            KeyCode::Esc => return Ok(true),
            KeyCode::Up => pick = shift(pick, -1, found.len()),
            KeyCode::Down => pick = shift(pick, 1, found.len()),
            KeyCode::Enter => {
                if let Some(&action) = found.get(pick) {
                    if let Logs(module) = action {
                        state.open_logs(module);
                        return Ok(true);
                    }
                    state.header_focus = false;
                    state.overlay = Overlay::None;
                    match action.section() {
                        dashboard::Target::Maintenance
                            if state.route.section() != action.section() =>
                        {
                            state.go(Route::Maintenance)
                        }
                        dashboard::Target::Services if state.route.module() != action.module() => {
                            if let Some(module) = action.module() {
                                state.go(Route::Module(module, Tab::Overview));
                            }
                        }
                        _ => {}
                    }
                    state.dispatch(action, host, display, false)?;
                    return Ok(true);
                }
            }
            KeyCode::Backspace => {
                text.pop();
                pick = 0;
            }
            KeyCode::Char(ch) if !ch.is_control() && text.len() < 160 => {
                text.push(ch);
                pick = 0;
            }
            _ => {}
        }
        state.palette = Some((text, pick));
        return Ok(true);
    }
    if state.job.is_some() {
        state.note = "更新进行中；退出界面不能取消系统操作".into();
        return Ok(true);
    }
    if !state.is_home() && state.nav_enabled() {
        if matches!(code, KeyCode::Tab | KeyCode::BackTab) {
            state.header_focus = !state.header_focus;
            if state.header_focus {
                state.home_target = state.route.section()
            }
            return Ok(true);
        }
        if state.header_focus {
            match code {
                KeyCode::Esc => state.header_focus = false,
                KeyCode::Left | KeyCode::Right => {
                    state.home_target = state
                        .home_target
                        .step(if code == KeyCode::Left { -1 } else { 1 }, false)
                }
                KeyCode::Enter => state.activate_nav(state.home_target),
                KeyCode::Char('/') => state.activate_nav(dashboard::Target::Search),
                _ => {}
            }
            return Ok(true);
        }
    }
    match &mut state.overlay {
        Overlay::Subscriptions(panel) => {
            match panel.key(code, display)? {
                subscriptions::Effect::Close => state.overlay = Overlay::None,
                subscriptions::Effect::Changed => {
                    state.reentered = true;
                    state.refresh();
                }
                subscriptions::Effect::Stay => {}
            }
            return Ok(true);
        }
        Overlay::Help => {
            state.overlay = Overlay::None;
            return Ok(true);
        }
        Overlay::Confirm(action) => {
            let selected = *action;
            match code {
                KeyCode::Esc | KeyCode::Char('n') => state.overlay = Overlay::None,
                KeyCode::Char('y') => {
                    state.overlay = Overlay::None;
                    state.dispatch(selected, host, display, true)?;
                }
                _ => {}
            }
            return Ok(true);
        }
        Overlay::Input => {
            match code {
                KeyCode::Esc => state.overlay = Overlay::None,
                KeyCode::Backspace => {
                    state.interface.pop();
                }
                KeyCode::Enter if !state.interface.is_empty() => {
                    state.outlet =
                        Outlet::Waiting(state.interface.clone(), probe(state.interface.clone()));
                    state.overlay = Overlay::None;
                }
                KeyCode::Char(ch)
                    if state.interface.len() < 32
                        && (ch.is_ascii_alphanumeric() || "_.-".contains(ch)) =>
                {
                    state.interface.push(ch)
                }
                _ => {}
            }
            return Ok(true);
        }
        Overlay::Reader(reader) => {
            if reader.editing {
                match code {
                    KeyCode::Esc | KeyCode::Enter => reader.editing = false,
                    KeyCode::Backspace => {
                        reader.filter.pop();
                    }
                    KeyCode::Char(ch) if !ch.is_control() && reader.filter.len() < 160 => {
                        reader.filter.push(ch)
                    }
                    _ => {}
                }
                reader.offset = 0;
            } else {
                match code {
                    KeyCode::Char('l') if reader.kernel.is_some() => {
                        reader.stop();
                        reader.kernel = reader.kernel.map(|kernel| !kernel);
                        reader.lines.clear();
                        reader.offset = 0;
                        reader.paused = false;
                        reader.connect();
                    }
                    KeyCode::Esc | KeyCode::Char('q') => state.close_reader(),
                    KeyCode::Char('/') => reader.editing = true,
                    KeyCode::Char(' ')
                        if reader.live() || (reader.origin.is_some() && reader.paused) =>
                    {
                        reader.paused = !reader.paused;
                        if !reader.paused {
                            reader.offset = 0;
                        }
                    }
                    KeyCode::Up | KeyCode::PageUp if !reader.tail_view => {
                        reader.offset =
                            reader
                                .offset
                                .saturating_sub(if code == KeyCode::Up { 1 } else { 10 });
                    }
                    KeyCode::Down | KeyCode::PageDown if !reader.tail_view => {
                        reader.offset = (reader.offset
                            + if code == KeyCode::Down { 1 } else { 10 })
                        .min(reader.matching().len().saturating_sub(1));
                    }
                    KeyCode::Up | KeyCode::PageUp => {
                        reader.offset = (reader.offset + if code == KeyCode::Up { 1 } else { 10 })
                            .min(reader.matching().len().saturating_sub(1));
                        if reader.live() {
                            reader.paused = true;
                        }
                    }
                    KeyCode::Down | KeyCode::PageDown => {
                        reader.offset =
                            reader
                                .offset
                                .saturating_sub(if code == KeyCode::Down { 1 } else { 10 })
                    }
                    _ => {}
                }
            }
            return Ok(true);
        }
        Overlay::None => {}
    }
    let items = state.items(host);
    state.focus = state.focus.min(items.len().saturating_sub(1));
    match code {
        KeyCode::Char('q') => return Ok(false),
        KeyCode::Esc if state.is_home() && state.header_focus => {
            state.header_focus = false;
            state.home_target = state.route.section();
        }
        KeyCode::Esc if state.route == Route::Home => return Ok(false),
        KeyCode::Esc => state.go(match state.route {
            Route::Plan(_) => Route::Maintenance,
            Route::Module(Module::Mihomo, Tab::Diagnostics) => {
                Route::Module(Module::Mihomo, Tab::Overview)
            }
            Route::Module(..) => Route::Services,
            _ => Route::Home,
        }),
        KeyCode::Char('/') => state.activate_nav(dashboard::Target::Search),
        KeyCode::Char('?') => state.overlay = Overlay::Help,
        KeyCode::Char('r') if state.route == Route::Module(Module::Mihomo, Tab::Overview) => {
            if state.query.is_none() {
                state.refresh();
            }
        }
        KeyCode::Tab if state.is_home() && !state.header_focus => {
            state.header_focus = true;
            state.home_target = state.route.section();
        }
        KeyCode::Tab
        | KeyCode::BackTab
        | KeyCode::Right
        | KeyCode::Left
        | KeyCode::Down
        | KeyCode::Up
        | KeyCode::Char('j' | 'k')
            if state.is_home() =>
        {
            state.header_focus = true;
            let backwards = matches!(
                code,
                KeyCode::BackTab | KeyCode::Left | KeyCode::Up | KeyCode::Char('k')
            );
            state.home_target = state
                .home_target
                .step(if backwards { -1 } else { 1 }, state.has_changes());
        }
        KeyCode::Enter if state.is_home() => state.activate_nav(state.home_target),
        KeyCode::Up | KeyCode::Char('k') => state.focus = shift(state.focus, -1, items.len()),
        KeyCode::Down | KeyCode::Char('j') => state.focus = shift(state.focus, 1, items.len()),
        KeyCode::Enter => {
            if let Some(id) = items.get(state.focus) {
                state.dispatch(*id, host, display, false)?;
            }
        }
        _ => {}
    }
    Ok(true)
}

pub fn run(host: &Host, motion: Option<&str>) -> Reply<()> {
    if !io::stdin().is_terminal() || !io::stdout().is_terminal() {
        return Err("TUI 需要交互终端，请用 status --json".into());
    }
    let (width, height) = terminal::size().map_err(|e| e.to_string())?;
    if !view::fits(width, height) {
        return Err(format!("当前终端 {width}×{height}，控制台至少需要 80×24"));
    }
    let system = if host.system.ends_with("-darwin") {
        "macOS".into()
    } else {
        fs::read_to_string("/etc/os-release")
            .ok()
            .and_then(|data| {
                data.lines().find_map(|line| {
                    line.strip_prefix("NAME=")
                        .map(|name| clean(name.trim_matches('"')))
                })
            })
            .unwrap_or_else(|| "Linux".into())
    };
    let mut state = State {
        route: Route::Home,
        focus: 0,
        home_focus: 0,
        overlay: Overlay::None,
        machine: sysinfo::System::host_name()
            .map(|name| clean(&name))
            .unwrap_or_else(|| host.name.clone()),
        system,
        overview: overview::Overview::new(),
        home_target: dashboard::Target::Overview,
        header_focus: false,
        reentered: false,
        palette: None,
        boot: None,
        capacity: None,
        status: Value::Null,
        query: None,
        status_error: String::new(),
        services: None,
        services_query: None,
        compact: width < 104,
        controls_open: false,
        interface: String::new(),
        hinted: None,
        outlet: Outlet::Idle,
        note: String::new(),
        job: None,
        report: vec![],
        report_mode: None,
        motion: motion
            .unwrap_or(if env::var_os("SSH_CONNECTION").is_some() {
                "reduced"
            } else {
                "full"
            })
            .into(),
        opened: Instant::now(),
    };
    let _restore = Restore;
    let mut display = enter()?;
    let mut first_frame = true;
    let mut badge = badge::Badge::new(&state.system);
    let mut dirty = true;
    loop {
        dirty |= state.tick(host, &mut display)?;
        let size = display.size().map_err(|e| e.to_string())?;
        if state.compact != (size.width < 104) {
            state.compact = size.width < 104;
            state.controls_open = false;
            if state.route == Route::Module(Module::Mihomo, Tab::Overview) && state.focus >= 3 {
                state.focus = 0;
            }
            dirty = true;
        }
        let homepage = state.is_home() && view::fits(size.width, size.height);
        if homepage {
            dirty |= state.overview.tick();
            if !state.has_changes() && state.home_target == dashboard::Target::Changes {
                state.home_target = dashboard::Target::Search;
            }
        }
        if first_frame {
            state.boot = Some(Instant::now());
            first_frame = false;
        }
        let progress = state.boot_progress();
        let boot = progress.is_some();
        if !boot && state.boot.take().is_some() {
            dirty = true
        }
        let animation = (homepage && boot)
            || (state.route != Route::Home
                && state.motion == "full"
                && matches!(state.overlay, Overlay::None)
                && (state.opened.elapsed() < Duration::from_millis(520)
                    || (matches!(state.route, Route::Module(Module::Mihomo, Tab::Diagnostics))
                        && matches!(state.outlet, Outlet::Waiting(..)))));
        if dirty || animation {
            let rect = display.size().map_err(|e| e.to_string())?;
            let layout = dashboard::Layout::new(rect.width, rect.height);
            if std::mem::take(&mut state.reentered) {
                badge.sync([None, None]).map_err(|err| err.to_string())?;
            }
            let brand = badge.visible_candidate(
                view::fits(rect.width, rect.height)
                    && progress.is_none_or(|p| !homepage || layout.badge_ready(p)),
            );
            let system = brand
                && homepage
                && (state.palette.is_none()
                    || !view::popup_rect(ratatui::layout::Rect::new(
                        0,
                        0,
                        rect.width,
                        rect.height,
                    ))
                    .intersects(layout.graphic_badge()));
            display
                .draw(|frame| {
                    view::draw(frame, host, &state, brand, system);
                    if let Some(progress) = progress.filter(|_| homepage) {
                        dashboard::reveal(frame, progress, state.motion == "reduced");
                    }
                })
                .map_err(|e| e.to_string())?;
            badge
                .sync([
                    system.then(|| layout.graphic_badge()),
                    brand.then(|| layout.wordmark()),
                ])
                .map_err(|err| err.to_string())?;
            dirty = false;
        }
        if !event::poll(Duration::from_millis(if animation { 30 } else { 180 }))
            .map_err(|e| e.to_string())?
        {
            continue;
        }
        let input = event::read().map_err(|e| e.to_string())?;
        if badge.consume_reply(&input) {
            dirty = true;
            continue;
        }
        match input {
            Event::Resize(..) => {
                dirty = true;
                continue;
            }
            Event::Mouse(click)
                if state.nav_enabled()
                    && view::fits(size.width, size.height)
                    && click.kind == MouseEventKind::Down(MouseButton::Left) =>
            {
                state.boot = None;
                dirty = true;
                if let Some(target) = dashboard::Layout::new(size.width, size.height).hit(
                    click.column,
                    click.row,
                    homepage && state.has_changes(),
                ) {
                    state.activate_nav(target);
                }
                continue;
            }
            Event::Key(pressed) => {
                if pressed.kind != KeyEventKind::Press {
                    continue;
                }
                state.boot = None;
                dirty = true;
                let size = display.size().map_err(|e| e.to_string())?;
                if !view::fits(size.width, size.height) {
                    if pressed.code == KeyCode::Char('q') && state.job.is_none() {
                        break;
                    }
                    continue;
                }
                if !key(&mut state, host, &mut display, pressed.code)? {
                    break;
                }
            }
            _ => {}
        }
    }
    Ok(())
}
