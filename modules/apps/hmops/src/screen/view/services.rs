use super::*;
use actions::Verb;

fn columns(area: Rect, at: u16) -> (Rect, Rect) {
    let width = at.min(area.width);
    (
        Rect { width, ..area },
        Rect {
            x: area.x + width,
            width: area.width - width,
            ..area
        },
    )
}

pub(super) fn list(frame: &mut Frame, area: Rect, items: &[ActionId], state: &State) {
    let (names, rest) = columns(area, 16);
    let (states, details) = columns(rest, 12);
    for (index, action) in items.iter().enumerate() {
        let Open(module) = action else { continue };
        let active = state.content_focused() && state.focus == index;
        let style = if active {
            theme::brand()
        } else {
            Style::default()
        };
        let description = match module {
            Module::Mihomo => "代理服务、配置订阅与日志",
            Module::Multica => "本机任务执行器与日志",
            Module::Magpie => "网关状态、健康检查与管理入口",
        };
        let status = state.services.as_ref().map_or("查询中", |snapshot| {
            let data = &snapshot["services"][module.name().to_ascii_lowercase()];
            if *module == Module::Mihomo {
                service_state(data)
            } else if data["LoadState"] == "loaded" {
                match data["ActiveState"].as_str() {
                    Some("active") if data["SubState"] == "running" => "运行中",
                    Some("active") => "已激活",
                    Some("inactive") => "已停止",
                    Some("failed") => "失败",
                    Some("activating") => "启动中",
                    Some("deactivating") => "停止中",
                    _ => "未知",
                }
            } else {
                "未知"
            }
        });
        let line = index as u16;
        item(frame, names, line, module.name(), active);
        row(frame, states, line, Line::styled(status, style));
        row(frame, details, line, Line::styled(description, style));
    }
}

fn service_state(status: &Value) -> &'static str {
    match status["state"].as_str() {
        Some("running") => "运行中",
        Some("stopped") => "已停止",
        Some("starting") => "启动中",
        Some("stopping") => "停止中",
        Some("not-installed") => "未安装",
        Some("failed") => "运行失败",
        _ => "未知",
    }
}

pub(super) fn overview(frame: &mut Frame, area: Rect, items: &[ActionId], state: &State) {
    row(frame, area, 0, Line::styled("服务 / Mihomo", bold()));
    let running = service_state(&state.status);
    let boot = flag(&state.status, "autostart", "已开启", "已关闭");
    let source = match (
        state.status["active_id"].as_u64(),
        state.status["source_set"].as_bool(),
    ) {
        (Some(id), _) => format!("#{id}"),
        (None, Some(true)) => "旧来源待迁移".into(),
        (None, Some(false)) => "未选择".into(),
        _ if state.status["state"].is_string() => "需授权查看".into(),
        _ => "未知".into(),
    };
    let config = match state.status["config"].as_str() {
        Some("installed") => "已安装",
        Some("placeholder") => "占位配置",
        Some("private") => "受保护",
        Some("missing") => "缺失",
        _ => "未知",
    };
    let body = after(area, 2);
    let actions = if state.compact {
        dashboard::section(frame, body, "◎ 运行状态");
        row(
            frame,
            body,
            1,
            format!("服务      {running}    开机自启  {boot}"),
        );
        row(
            frame,
            body,
            2,
            format!("配置文件  {config}    当前订阅  {source}"),
        );
        after(body, 4)
    } else {
        let (facts, actions) = columns(body, (body.width - 4) / 2 + 4);
        let facts = Rect {
            width: facts.width - 4,
            ..facts
        };
        dashboard::section(frame, facts, "◎ 运行状态");
        for (index, (name, value)) in [
            ("服务", running),
            ("开机自启", boot),
            ("配置文件", config),
            ("当前订阅", source.as_str()),
        ]
        .iter()
        .enumerate()
        {
            let (labels, values) = columns(facts, 12);
            row(frame, labels, index as u16 + 1, *name);
            row(frame, values, index as u16 + 1, (*value).to_owned());
        }
        actions
    };
    dashboard::section(frame, actions, "◇ 常用操作");
    let mut line = 1;
    for (index, action) in items.iter().enumerate() {
        if index == 3 && !state.compact {
            line += 1;
            dashboard::section(frame, after(actions, line), "⚙ 服务控制");
            line += 1;
        }
        let (name, note) = match action {
            Logs(_) => ("查看日志", "最近记录与后续输出"),
            UpdateSource => ("更新当前配置", "刷新当前订阅并应用"),
            Subscriptions => ("管理订阅", "添加、切换或移除订阅"),
            Control(_, Verb::Reload) => ("重载配置", "通知内核重读配置"),
            ServiceControls => (
                "服务控制",
                if state.controls_open {
                    "收起控制项"
                } else {
                    "展开控制项"
                },
            ),
            Control(_, Verb::Restart) => ("重启服务", "重新启动代理进程"),
            Control(_, Verb::Stop) => ("停止服务", "中断当前代理连接"),
            Control(_, Verb::Start) => ("启动服务", "运行代理进程"),
            Control(_, Verb::Enable) => ("开启自启", "不改变本次运行状态"),
            Control(_, Verb::Disable) => ("关闭自启", "不改变本次运行状态"),
            _ => continue,
        };
        let active = state.content_focused() && state.focus == index;
        let (labels, notes) = columns(actions, 17);
        item(frame, labels, line, name, active);
        row(
            frame,
            notes,
            line,
            Line::styled(
                note,
                if active {
                    theme::brand()
                } else {
                    Style::default()
                },
            ),
        );
        line += 1;
    }
    if state.query.is_some() || !state.status_error.is_empty() {
        let message = if state.query.is_some() {
            "正在读取服务状态…".into()
        } else {
            format!("状态查询失败：{}；按 r 重试", state.status_error)
        };
        row(frame, area, 1, message);
    }
}

pub(super) fn subscriptions_popup(frame: &mut Frame, panel: &subscriptions::Panel) {
    use subscriptions::Mode;
    let rect = popup_rect(frame.area());
    let block = Block::bordered()
        .title(" 管理订阅 ")
        .border_style(theme::brand());
    let inner = block.inner(rect);
    frame.render_widget(Clear, rect);
    frame.render_widget(block, rect);
    let (message, hint) = match &panel.mode {
        Mode::List => {
            let labels: Vec<_> = panel
                .subscriptions
                .iter()
                .map(|entry| {
                    format!(
                        "#{}  {}{}",
                        entry.id,
                        if Some(entry.id) == panel.active_id {
                            "当前  "
                        } else {
                            "      "
                        },
                        clean(&entry.name)
                    )
                })
                .collect();
            if labels.is_empty() {
                row(frame, inner, 0, "没有可显示的订阅");
            } else {
                menu(
                    frame,
                    Rect {
                        height: inner.height - 3,
                        ..inner
                    },
                    &labels,
                    panel.focus,
                    true,
                );
            }
            (
                panel.notice.clone(),
                "↑↓ 选择   Enter 应用   a 添加   d 移除   Esc 返回",
            )
        }
        Mode::Name(name) => {
            row(frame, inner, 0, format!("订阅名称  {name}▏"));
            (
                "下一步输入隐藏的 HTTPS 地址；添加只登记，不下载或切换。".into(),
                "Enter 继续   Esc 取消",
            )
        }
        Mode::Confirm { remove, id } => {
            row(
                frame,
                inner,
                0,
                format!("{}订阅 #{}？", if *remove { "移除" } else { "应用" }, id),
            );
            (
                (if *remove {
                    "只移除这条非当前订阅。"
                } else {
                    "下载并校验后应用；配置改变且服务运行时将重启。"
                })
                .into(),
                "y 确认   Esc 取消",
            )
        }
    };
    frame.render_widget(
        Paragraph::new(message).wrap(Wrap { trim: false }),
        Rect {
            height: 2,
            ..after(inner, inner.height - 3)
        },
    );
    row(frame, inner, inner.height - 1, hint);
}
