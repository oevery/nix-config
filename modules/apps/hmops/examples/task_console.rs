use crossterm::event::{self, Event, KeyCode, KeyEventKind};
use ratatui::{
    layout::Rect,
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::Paragraph,
    Frame,
};
use std::{
    io,
    time::{Duration, Instant},
};

const TASKS: [(&str, &str); 4] = [
    ("主机更新", "查看更新计划"),
    ("Mihomo", "验证网络出口"),
    ("Multica", "管理运行器"),
    ("Magpie", "管理网关"),
];
const OPEN: f64 = 0.62;
const SHIFT: f64 = 0.18;
const RESPONSE: f64 = 1.3;

enum View {
    Home,
    Network {
        opened: Instant,
        sent: Option<Instant>,
    },
}

struct Demo {
    view: View,
    started: Instant,
    focus: usize,
    from_slot: f64,
    shifted: Instant,
    hint: bool,
}

impl Demo {
    fn new() -> Self {
        Self {
            view: View::Home,
            started: Instant::now(),
            focus: 0,
            from_slot: 0.0,
            shifted: Instant::now(),
            hint: false,
        }
    }

    fn slot(&self) -> f64 {
        let progress = ease(self.shifted.elapsed().as_secs_f64() / SHIFT);
        self.from_slot + (self.focus as f64 - self.from_slot) * progress
    }

    fn key(&mut self, key: KeyCode) -> bool {
        let now = Instant::now();
        match (&mut self.view, key) {
            (_, KeyCode::Char('q')) | (View::Home, KeyCode::Esc) => return false,
            (_, KeyCode::Char('r')) => *self = Self::new(),
            (
                View::Home,
                KeyCode::Up
                | KeyCode::Left
                | KeyCode::Char('k')
                | KeyCode::Down
                | KeyCode::Right
                | KeyCode::Char('j'),
            ) => {
                self.from_slot = self.slot();
                self.shifted = now;
                let backwards = matches!(key, KeyCode::Up | KeyCode::Left | KeyCode::Char('k'));
                self.focus =
                    (self.focus + if backwards { TASKS.len() - 1 } else { 1 }) % TASKS.len();
                self.hint = false;
            }
            (View::Home, KeyCode::Enter) if self.focus == 1 => {
                self.view = View::Network {
                    opened: now,
                    sent: None,
                };
            }
            (View::Home, KeyCode::Enter) => self.hint = true,
            (View::Network { .. }, KeyCode::Esc) => self.view = View::Home,
            (View::Network { sent, .. }, KeyCode::Enter)
                if sent.is_none_or(|start| start.elapsed().as_secs_f64() >= RESPONSE) =>
            {
                *sent = Some(now);
            }
            _ => {}
        }
        true
    }
}

fn accent() -> Style {
    Style::default().fg(Color::Cyan)
}
fn bold() -> Style {
    Style::default().add_modifier(Modifier::BOLD)
}

fn row(frame: &mut Frame, area: Rect, index: u16, text: impl Into<Line<'static>>) {
    if index < area.height {
        frame.render_widget(
            Paragraph::new(text.into()),
            Rect::new(area.x, area.y + index, area.width, 1),
        );
    }
}

fn ease(value: f64) -> f64 {
    let value = value.clamp(0.0, 1.0);
    value * value * (3.0 - 2.0 * value)
}

fn at(frame: &mut Frame, area: Rect, col: u16, line: u16, text: impl Into<Line<'static>>) {
    row(
        frame,
        Rect {
            x: area.x + col,
            width: area.width.saturating_sub(col),
            ..area
        },
        line,
        text,
    );
}

fn task_deck(frame: &mut Frame, area: Rect, demo: &Demo, baseline: u16) {
    let width = area.width;
    let step = width / 4;
    for (idx, (name, _)) in TASKS.iter().enumerate() {
        let style = if idx == demo.focus {
            bold().fg(Color::Cyan)
        } else {
            Style::default()
        };
        at(
            frame,
            area,
            1 + step * idx as u16,
            5,
            Line::styled(*name, style),
        );
    }
    let slider = (f64::from(step) * demo.slot()).round() as u16;
    let strip = (0..width)
        .map(|col| {
            if (slider..slider + step).contains(&col) {
                Span::styled("━", accent())
            } else if col % step == 0 {
                Span::raw("┬")
            } else {
                Span::raw("─")
            }
        })
        .collect::<Vec<_>>();
    row(frame, area, 6, Line::from(strip));
    let (_, task) = TASKS[demo.focus];
    let lower = baseline + 3;
    at(
        frame,
        area,
        0,
        baseline - 2,
        Line::styled(format!("╭─ 0{} / 04", demo.focus + 1), accent()),
    );
    at(frame, area, 2, baseline, Line::styled(task, bold()));
    at(
        frame,
        area,
        2,
        baseline + 1,
        [
            "预览 → 应用",
            "进程 → TUN → 出口",
            "运行器 / 服务",
            "网关 / 服务",
        ][demo.focus],
    );
    at(frame, area, 0, lower, Line::styled("╰──", accent()));
    at(
        frame,
        area,
        width - 3,
        baseline - 2,
        Line::styled("──╮", accent()),
    );
    at(frame, area, width - 3, lower, Line::styled("──╯", accent()));
}

fn trace(
    frame: &mut Frame,
    area: Rect,
    baseline: u16,
    focus: usize,
    spread: f64,
    elapsed: Option<f64>,
) {
    let end = area.width - 9;
    let middle = (4 + end) / 2;
    let offsets: [i16; 3] = match focus {
        0 => [2, 1, 0],
        1 => [1, -1, 0],
        2 => [-1, 1, -1],
        _ => [0, 2, 0],
    };
    let mix = |from: u16, to: u16| {
        (f64::from(from) + (f64::from(to) - f64::from(from)) * spread).round() as u16
    };
    let miniature = area.width / 2 + 1;
    let nodes = [miniature, (miniature + end) / 2, end]
        .into_iter()
        .zip([4, middle, end])
        .zip(offsets)
        .map(|((from, to), offset)| {
            (
                mix(from, to),
                mix(baseline.saturating_add_signed(offset), baseline),
            )
        })
        .collect::<Vec<_>>();
    let received = elapsed.is_some_and(|value| value >= RESPONSE);
    for (idx, pair) in nodes.windows(2).enumerate() {
        let [(left, first), (right, last)] = [pair[0], pair[1]];
        let bend = (left + right) / 2;
        let style = if idx == 0 || received {
            accent()
        } else {
            Style::default()
        };
        let rail = if idx == 0 || received { "─" } else { "┄" };
        at(
            frame,
            area,
            left + 1,
            first,
            Line::styled(rail.repeat((bend - left - 1).into()), style),
        );
        at(
            frame,
            area,
            bend + 1,
            last,
            Line::styled(rail.repeat((right - bend - 1).into()), style),
        );
        if first == last {
            at(frame, area, bend, last, Line::styled(rail, style));
        } else {
            let (turn_in, turn_out) = if first < last {
                ("╮", "╰")
            } else {
                ("╯", "╭")
            };
            at(frame, area, bend, first, Line::styled(turn_in, style));
            at(frame, area, bend, last, Line::styled(turn_out, style));
            for line in first.min(last) + 1..first.max(last) {
                at(frame, area, bend, line, Line::styled("│", style));
            }
        }
    }
    for (idx, (col, line)) in nodes.into_iter().enumerate() {
        let glyph = if idx == 0 {
            "●"
        } else if idx == 2 && received {
            "◆"
        } else {
            "◇"
        };
        at(
            frame,
            area,
            col,
            line,
            Line::styled(
                glyph,
                if idx == 2 && !received {
                    bold()
                } else {
                    accent()
                },
            ),
        );
        if spread > 0.95 {
            at(
                frame,
                area,
                col - 2,
                line - 1,
                Line::styled(["进程", "TUN", "出口"][idx], bold()),
            );
            at(
                frame,
                area,
                col - 2,
                line + 1,
                [
                    "运行",
                    "tun0",
                    if received {
                        "已回执"
                    } else if elapsed.is_some() {
                        "等待中"
                    } else {
                        "未验证"
                    },
                ][idx],
            );
        }
    }
    if let Some(secs) = elapsed.filter(|secs| *secs < RESPONSE) {
        let pulse = middle + 1 + ((secs / 0.70).fract() * f64::from(end - middle - 1)) as u16;
        at(frame, area, pulse, baseline, Line::styled("▸", accent()));
    }
}

fn draw(frame: &mut Frame, demo: &Demo) {
    let outer = frame.area();
    if outer.width < 48 || outer.height < 18 {
        row(frame, outer, 0, "请将终端放大至 48×18，或按 q 退出。");
        return;
    }
    let width = outer.width.saturating_sub(4).min(88);
    let height = outer.height.min(24);
    let area = Rect::new(
        (outer.width - width) / 2,
        (outer.height - height) / 2,
        width,
        height,
    );
    let age = demo.started.elapsed().as_secs_f64();
    let loading = age < 0.56 && matches!(demo.view, View::Home);
    row(
        frame,
        area,
        0,
        Line::from(vec![
            Span::styled("HMOPS", bold().fg(Color::Cyan)),
            Span::raw("  /  控制台"),
        ]),
    );
    frame.render_widget(
        Paragraph::new("模拟 · 不联网").right_aligned(),
        Rect::new(area.x + width - 16, area.y, 16, 1),
    );
    if loading {
        let head = (age / 0.48 * f64::from(width)) as u16;
        let sweep = (0..width)
            .map(|col| match head.checked_sub(col) {
                Some(0) => Span::styled("◆", bold().fg(Color::Cyan)),
                Some(1..=7) => Span::styled("━", accent()),
                _ => Span::raw("─"),
            })
            .collect::<Vec<_>>();
        row(frame, area, 1, Line::from(sweep));
    } else {
        row(frame, area, 1, "─".repeat(width.into()));
    }
    let path_row = if height < 21 { 10 } else { 12 };
    let footer = height - 2;
    match &demo.view {
        View::Home => {
            row(
                frame,
                area,
                3,
                Line::from(vec![
                    Span::styled("homelab", bold()),
                    Span::raw("  /  Linux   ·   普通权限"),
                ]),
            );
            task_deck(frame, area, demo, path_row);
            trace(frame, area, path_row, demo.focus, 0.0, None);
            if height >= 21 {
                row(
                    frame,
                    area,
                    footer - 2,
                    if demo.hint {
                        "此任务未接入样片，请选择 Mihomo。"
                    } else if demo.focus == 1 {
                        "Enter 展开网络路径；进入页面不会发出请求。"
                    } else {
                        "本次开放    02 / Mihomo 网络路径"
                    },
                );
            }
            row(
                frame,
                area,
                footer,
                if demo.hint {
                    "仅开放 Mihomo   ←→ 选择   q 退出"
                } else {
                    "←→ 选择任务   Enter 打开   r 重播   q 退出"
                },
            );
        }
        View::Network { opened, sent } => {
            let open = if sent.is_some() {
                1.0
            } else {
                (opened.elapsed().as_secs_f64() / OPEN).min(1.0)
            };
            if open < 0.18 {
                row(frame, area, 3, "homelab  /  Linux   ·   普通权限");
                task_deck(frame, area, demo, path_row);
                trace(frame, area, path_row, demo.focus, 0.0, None);
                at(
                    frame,
                    area,
                    2,
                    path_row + 1,
                    Line::styled("Mihomo  ▸", accent()),
                );
                return;
            }
            let elapsed = sent.map(|time| time.elapsed().as_secs_f64());
            let received = elapsed.is_some_and(|secs| secs >= RESPONSE);
            row(
                frame,
                area,
                3,
                Line::from(vec![
                    Span::styled("Mihomo", bold()),
                    Span::raw("  /  网络路径"),
                ]),
            );
            row(frame, area, 4, "homelab  /  Linux     ·     普通权限");
            trace(
                frame,
                area,
                path_row,
                1,
                ease((open - 0.18) / 0.82),
                elapsed,
            );
            if open < 0.85 {
                return;
            }
            let (marker, receipt) = if received {
                ("✓", "模拟 HTTPS 204   ·   接口 tun0")
            } else if elapsed.is_some() {
                ("◈", "模拟请求已发出，等待回执…")
            } else {
                ("◇", "尚未模拟验证")
            };
            row(
                frame,
                area,
                path_row + 4,
                Line::from(vec![
                    Span::styled("回执  ", accent()),
                    Span::raw("─".repeat(usize::from(width - 6))),
                ]),
            );
            row(
                frame,
                area,
                path_row + 5,
                Line::from(vec![
                    Span::styled(format!("{marker}  "), accent()),
                    Span::styled(receipt, bold()),
                ]),
            );
            row(
                frame,
                area,
                footer,
                if received {
                    "Enter 再次模拟   Esc 返回   r 重播   q 退出"
                } else if elapsed.is_some() {
                    "Esc 返回    q 退出"
                } else {
                    "Enter 模拟验证    Esc 返回    q 退出"
                },
            );
        }
    }
}

fn main() -> io::Result<()> {
    let mut terminal = ratatui::init();
    let mut demo = Demo::new();
    let result = (|| loop {
        terminal.draw(|frame| draw(frame, &demo))?;
        let animate = match demo.view {
            View::Home => {
                demo.started.elapsed().as_secs_f64() < 0.60
                    || demo.shifted.elapsed().as_secs_f64() < SHIFT + 0.08
            }
            View::Network { opened, sent } => {
                opened.elapsed().as_secs_f64() < OPEN + 0.08
                    || sent.is_some_and(|time| time.elapsed().as_secs_f64() < RESPONSE + 0.08)
            }
        };
        if event::poll(if animate {
            Duration::from_millis(25)
        } else {
            Duration::from_secs(60)
        })? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press && !demo.key(key.code) {
                    break Ok(());
                }
            }
        }
    })();
    ratatui::restore();
    result
}
