use super::*;
mod logs;
mod plan;
mod services;
use ratatui::{
    layout::Rect,
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Clear, Paragraph, Wrap},
    Frame,
};
fn accent() -> Style {
    theme::brand().add_modifier(Modifier::BOLD)
}
fn bold() -> Style {
    Style::default().add_modifier(Modifier::BOLD)
}
fn row(frame: &mut Frame, area: Rect, line: u16, text: impl Into<Line<'static>>) {
    if line < area.height {
        frame.render_widget(
            Paragraph::new(text.into()),
            Rect::new(area.x, area.y + line, area.width, 1),
        );
    }
}
fn after(area: Rect, top: u16) -> Rect {
    let offset = area.height.min(top);
    Rect::new(area.x, area.y + offset, area.width, area.height - offset)
}
fn flag(value: &Value, key: &str, yes: &'static str, no: &'static str) -> &'static str {
    match value[key].as_bool() {
        Some(true) => yes,
        Some(false) => no,
        None => "未知",
    }
}
fn item(frame: &mut Frame, area: Rect, line: u16, label: &str, active: bool) {
    row(
        frame,
        area,
        line,
        Line::styled(
            format!("{} {label}", if active { "➤" } else { " " }),
            if active { accent() } else { Style::default() },
        ),
    );
}
fn menu(frame: &mut Frame, area: Rect, labels: &[String], focus: usize, focused: bool) {
    let start = focus.saturating_sub(usize::from(area.height).saturating_sub(1));
    for (idx, label) in labels
        .iter()
        .enumerate()
        .skip(start)
        .take(area.height.into())
    {
        item(
            frame,
            area,
            (idx - start) as u16,
            label,
            focused && idx == focus,
        );
    }
}
fn maintenance(frame: &mut Frame, area: Rect, items: &[ActionId], state: &State) {
    let entries: Vec<_> = items
        .iter()
        .map(|action| {
            let description = match action {
                Plan(Mode::Sync) => "预览按锁文件同步配置的步骤",
                Plan(Mode::Daily) => "预览配置和工具更新，不含系统升级",
                Diff => "对比工作区与当前提交的锁文件",
                Plan(Mode::All) => "预览日常更新及宿主系统升级",
                Check => "运行主机配置检查并查看结果",
                _ => "",
            };
            (action.index_label(), description)
        })
        .collect();
    described_items(frame, area, &entries, state);
}
fn described_items(
    frame: &mut Frame,
    area: Rect,
    entries: &[(String, &'static str)],
    state: &State,
) {
    let column = entries
        .iter()
        .map(|(name, _)| Line::raw(name.as_str()).width())
        .max()
        .unwrap_or(0)
        + 6;
    let paired = entries
        .iter()
        .all(|(_, note)| column + Line::raw(*note).width() <= usize::from(area.width));
    for (index, (name, note)) in entries.iter().enumerate() {
        let selected = state.focus == index;
        let active = state.content_focused() && selected;
        item(frame, area, index as u16, name, active);
        let style = if active {
            theme::brand()
        } else {
            Style::default()
        };
        if paired {
            let column = column as u16;
            row(
                frame,
                Rect {
                    x: area.x + column,
                    width: area.width - column,
                    ..area
                },
                index as u16,
                Line::styled(*note, style),
            );
        } else if selected {
            frame.render_widget(
                Paragraph::new(*note).style(style).wrap(Wrap { trim: true }),
                after(area, entries.len() as u16 + 1),
            );
        }
    }
}
fn path(frame: &mut Frame, area: Rect, state: &State) {
    let width = area.width;
    let end = width.saturating_sub(7);
    let middle = width / 2;
    let first = 3;
    let secs = state.opened.elapsed().as_secs_f64();
    let phase = if state.motion == "full" {
        (secs / 0.42).min(1.0)
    } else {
        1.0
    };
    let pos = |target: u16| {
        (f64::from(middle)
            + (f64::from(target) - f64::from(middle)) * (1.0 - (1.0 - phase).powi(2)))
        .round() as u16
    };
    let success = matches!(state.outlet, Outlet::Receipt(_, Ok(())));
    let waiting = matches!(state.outlet, Outlet::Waiting(..));
    let pulse =
        middle + ((secs * 10.0) as u64 % u64::from(end.saturating_sub(middle).max(1))) as u16;
    let line = (0..width)
        .map(|col| {
            let ch = if col == pos(first) {
                if state.status["running"].as_bool() == Some(true) {
                    "●"
                } else {
                    "○"
                }
            } else if col == middle {
                "◇"
            } else if col == pos(end) {
                if success {
                    "◆"
                } else {
                    "◇"
                }
            } else if col < pos(first) || col > pos(end) {
                " "
            } else if waiting && state.motion == "full" && col == pulse {
                "▸"
            } else if success && col >= middle {
                "─"
            } else {
                "┄"
            };
            Span::styled(
                ch,
                if ch == "◇" || ch == "┄" {
                    Style::default()
                } else {
                    accent()
                },
            )
        })
        .collect::<Vec<_>>();
    row(frame, area, 0, Line::from(line));
    if phase > 0.9 {
        for (pos, text) in [(first, "进程"), (middle, "接口"), (end, "回执")] {
            row(
                frame,
                Rect {
                    x: area.x + pos.saturating_sub(2),
                    width: 8,
                    ..area
                },
                1,
                text,
            );
        }
    }
    row(
        frame,
        area,
        3,
        format!(
            "进程 {}   配置指定：{}",
            flag(&state.status, "running", "运行", "停止"),
            state.hinted.as_deref().unwrap_or("未提供")
        ),
    );
    let (text, style) = match &state.outlet {
        Outlet::Idle => (
            "尚未发出探测；接口归属需自行确认。".into(),
            Style::default(),
        ),
        Outlet::Waiting(name, _) => (format!("◈ {name} · 等待 HTTPS 回执"), accent()),
        Outlet::Receipt(name, Ok(())) => {
            (format!("✓ {name} · 本次接口请求收到 HTTPS 204"), accent())
        }
        Outlet::Receipt(name, Err(reason)) => (
            format!("× {name} · {reason}"),
            Style::default().fg(Color::Red),
        ),
    };
    frame.render_widget(
        Paragraph::new(text).style(style).wrap(Wrap { trim: false }),
        Rect {
            height: 2.min(area.height.saturating_sub(4)),
            ..after(area, 4)
        },
    );
}
fn route(frame: &mut Frame, area: Rect, host: &Host, state: &State) {
    let items = state.items(host);
    let labels = items
        .iter()
        .map(|id| id.label().to_owned())
        .collect::<Vec<_>>();
    match state.route {
        Route::Home => unreachable!("首页单独布局"),
        Route::Logs => logs::sources(frame, area, &items, state),
        Route::Maintenance | Route::Services => {
            dashboard::section(frame, area, state.route.section().label());
            if items.is_empty() {
                row(frame, area, 2, "本机没有配置此栏目的项目");
            } else if state.route == Route::Services {
                services::list(frame, after(area, 2), &items, state);
            } else {
                maintenance(frame, after(area, 2), &items, state);
            }
        }
        Route::Module(module, tab) => {
            if module == Module::Mihomo && tab == Tab::Overview {
                services::overview(frame, area, &items, state);
                return;
            }
            row(
                frame,
                area,
                0,
                Line::styled(
                    format!(
                        "{} / {}",
                        module.name(),
                        if module != Module::Mihomo {
                            "服务管理"
                        } else {
                            "网络诊断"
                        }
                    ),
                    bold(),
                ),
            );
            let top = if module == Module::Mihomo {
                path(frame, after(area, 2), state);
                8
            } else {
                2
            };
            menu(
                frame,
                after(area, top),
                &labels,
                state.focus,
                state.content_focused(),
            );
        }
        Route::Plan(mode) => plan::draw(frame, area, host, state, mode, &labels),
    }
}
pub(super) fn fits(width: u16, height: u16) -> bool {
    width >= 80 && height >= 24
}
pub(super) fn popup_rect(bounds: Rect) -> Rect {
    let width = bounds.width.saturating_sub(8).min(68);
    let height = 12;
    Rect::new(
        (bounds.width - width) / 2,
        4 + bounds.height.saturating_sub(24) / 4,
        width,
        height,
    )
}
fn search_popup(frame: &mut Frame, host: &Host, state: &State, text: &str, pick: usize) {
    let rect = popup_rect(frame.area());
    let panel = Block::bordered()
        .title(" 搜索 ")
        .border_style(theme::brand());
    let inner = panel.inner(rect);
    frame.render_widget(Clear, rect);
    frame.render_widget(panel, rect);
    let input = format!("{text}▏");
    let scroll = Line::raw(&input)
        .width()
        .saturating_sub(usize::from(inner.width));
    frame.render_widget(
        Paragraph::new(input).scroll((0, scroll as u16)),
        Rect { height: 1, ..inner },
    );
    let results = state
        .search(host, text)
        .into_iter()
        .map(|id| {
            let module = id
                .module()
                .map(|module| format!("{} · ", module.name()))
                .unwrap_or_default();
            format!("{}  /  {module}{}", id.section().label(), id.label())
        })
        .collect::<Vec<_>>();
    if results.is_empty() {
        row(frame, inner, 2, "没有匹配的本机操作");
    } else {
        menu(
            frame,
            Rect {
                height: inner.height - 3,
                ..after(inner, 2)
            },
            &results,
            pick,
            true,
        );
    }
    row(
        frame,
        inner,
        inner.height - 1,
        "↑↓ 选择   Enter 打开   Esc 返回",
    );
}
pub(super) fn draw(
    frame: &mut Frame,
    host: &Host,
    state: &State,
    graphic: bool,
    system_graphic: bool,
) {
    let bounds = frame.area();
    if !fits(bounds.width, bounds.height) {
        row(frame, bounds, 0, "请放大到至少 80×24");
        if state.job.is_none() {
            row(frame, bounds, 1, "q 退出；其他操作已暂停");
        } else {
            row(frame, bounds, 1, "更新仍在执行");
        }
        return;
    }
    dashboard::header(frame, state, graphic);
    if state.is_home() {
        dashboard::draw(frame, state, system_graphic);
    } else {
        draw_body(frame, host, state);
    }
    if let Some((text, pick)) = &state.palette {
        search_popup(frame, host, state, text, *pick);
    }
}
fn draw_body(frame: &mut Frame, host: &Host, state: &State) {
    let bounds = frame.area();
    let width = dashboard::Layout::new(bounds.width, bounds.height)
        .area
        .width;
    let area = Rect::new((bounds.width - width) / 2, 1, width, bounds.height - 1);
    let top = 3;
    let body = Rect {
        height: area.height.saturating_sub(top + 3),
        ..after(area, top)
    };
    let log_hint;
    let hint = match &state.overlay {
        Overlay::Help => {
            frame.render_widget(Paragraph::new("按键帮助\n\n↑↓ 或 j/k 选择操作\nTab 进入顶栏，←→ 选择栏目\n/ 搜索操作；日志中筛选已读取的行\nEnter 打开；更改系统状态前另按 y\nEsc 返回，不取消已发出的探测\nq 退出控制台"),body);
            "按任意键返回"
        }
        Overlay::Confirm(id) => {
            let target = id.module().map_or("主机", Module::name);
            row(
                frame,
                body,
                0,
                Line::styled(
                    format!("{target} / {} · {}", id.label(), host.name),
                    accent(),
                ),
            );
            let mut impact = id.impact().unwrap_or("").to_owned();
            if matches!(id, Apply(_)) && host.system.ends_with("-darwin") {
                impact.push_str(" 应用 Darwin 配置时也可能更新或清理 Homebrew 软件。");
            }
            frame.render_widget(
                Paragraph::new(impact).wrap(Wrap { trim: false }),
                after(body, 2),
            );
            "y 确认执行   Esc 取消"
        }
        Overlay::Input => {
            row(frame, body, 0, Line::styled("Mihomo / 网络诊断", bold()));
            path(frame, after(body, 1), state);
            row(frame, body, 6, format!("TUN  › {}▏", state.interface));
            frame.render_widget(
                Paragraph::new("确认后经指定接口向 Google 发出一次 HTTPS 请求；留空不会发送。")
                    .wrap(Wrap { trim: false }),
                after(body, 7),
            );
            "Enter 发送探测   Esc 取消"
        }
        Overlay::Subscriptions(panel) => {
            route(frame, body, host, state);
            services::subscriptions_popup(frame, panel);
            "Esc 返回"
        }
        Overlay::Reader(reader) if reader.origin.is_some() => {
            log_hint = logs::reader(frame, body, reader);
            &log_hint
        }
        Overlay::Reader(reader) => {
            row(frame, body, 0, Line::styled(reader.title.clone(), bold()));
            row(
                frame,
                body,
                1,
                format!(
                    "阅读   筛选：{}{}",
                    reader.filter,
                    if reader.editing { "▏" } else { "" }
                ),
            );
            row(frame, body, 2, reader.notice.clone());
            let data = after(body, 3);
            let filtered = reader.matching();
            let start = reader
                .offset
                .min(filtered.len().saturating_sub(data.height.into()));
            let end = (start + usize::from(data.height)).min(filtered.len());
            if filtered.is_empty() {
                row(
                    frame,
                    data,
                    0,
                    if !reader.filter.is_empty() {
                        "没有匹配行"
                    } else if reader.notice.is_empty() {
                        "暂无可见记录"
                    } else {
                        ""
                    },
                );
            }
            for (idx, line) in filtered[start..end].iter().enumerate() {
                row(frame, data, idx as u16, clean(line));
            }
            if reader.editing {
                "Enter 应用筛选   Esc 结束输入"
            } else {
                "↑↓ 翻阅   / 筛选   空格 暂停/跟随   Esc 返回"
            }
        }
        Overlay::None => {
            route(frame, body, host, state);
            row(frame, area, area.height - 3, state.note.clone());
            if state.route == Route::Logs {
                "↑↓ 选择   Enter 查看"
            } else if state.route == Route::Module(Module::Mihomo, Tab::Overview) {
                "↑↓ 选择   Enter 打开   r 刷新状态   Esc 返回"
            } else {
                "↑↓ 选择   Enter 打开   / 找操作   Esc 返回"
            }
        }
    };
    row(frame, area, area.height - 2, "─".repeat(width.into()));
    let hint = if state.header_focus {
        "顶栏   ←→ 选择   Enter 打开   Tab / Esc 返回内容".to_owned()
    } else if state.nav_enabled() {
        format!("{hint}   Tab 顶栏")
    } else {
        hint.to_owned()
    };
    row(frame, area, area.height - 1, hint);
}
