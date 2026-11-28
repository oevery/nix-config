use super::*;
use ratatui::{
    layout::Rect,
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::Paragraph,
    Frame,
};

mod arrival;
mod resources;
pub(super) use arrival::reveal;
pub(super) use resources::usage_bar;

#[derive(Clone, Copy, PartialEq)]
pub(super) enum Target {
    Overview,
    Maintenance,
    Services,
    Logs,
    Search,
    Changes,
}
const TARGETS: [Target; 6] = [
    Target::Overview,
    Target::Maintenance,
    Target::Services,
    Target::Logs,
    Target::Search,
    Target::Changes,
];
impl Target {
    pub fn label(self) -> &'static str {
        match self {
            Self::Overview => "总览",
            Self::Maintenance => "维护",
            Self::Services => "服务",
            Self::Logs => "日志",
            Self::Search => "搜索",
            Self::Changes => "查看更改",
        }
    }
    pub fn accepts(self, id: ActionId) -> bool {
        match self {
            Self::Maintenance => id.module().is_none(),
            Self::Services => matches!(id, Open(_)),
            Self::Logs => matches!(id, Logs(_)),
            _ => true,
        }
    }
    pub fn step(self, delta: isize, changes: bool) -> Self {
        let len = if changes { 6 } else { 5 };
        let index = TARGETS
            .iter()
            .position(|target| *target == self)
            .unwrap_or(0);
        TARGETS[shift(index, delta, len)]
    }
}
pub(super) struct Layout {
    pub(super) area: Rect,
    pub badge: Rect,
    identity_y: u16,
    cpu: Rect,
    memory: Rect,
    disk: Rect,
    network: Rect,
    maintenance: u16,
    wide: bool,
}
impl Layout {
    pub fn graphic_badge(&self) -> Rect {
        if self.badge.height == 4 {
            Rect::new(self.badge.x + 1, self.identity_y, self.badge.width - 2, 4)
        } else {
            self.badge
        }
    }
    pub fn wordmark(&self) -> Rect {
        Rect::new(self.area.x, u16::from(self.wide), 8, 1)
    }
    pub fn badge_ready(&self, progress: f64) -> bool {
        arrival::badge_ready(self, progress)
    }
    pub fn new(width: u16, height: u16) -> Self {
        let wide = width >= 104;
        let inner = width.saturating_sub(if wide { 8 } else { 4 }).min(144);
        let margin = (width - inner) / 2;
        let area = Rect::new(margin, 0, inner, height);
        let tall = wide && height >= 28;
        let spacious = height >= 33;
        let gap = if spacious { 2 } else { u16::from(tall) };
        let header_height = 2 + u16::from(wide);
        let badge = Rect::new(
            margin,
            header_height + 2 * u16::from(spacious),
            10,
            if wide && spacious { 4 } else { 5 },
        );
        let identity_y = badge.y + u16::from(!wide);
        let start = badge.bottom() + gap;
        let pane = (inner - 4) / 2;
        let right = margin + pane + 4;
        let cpu = Rect::new(margin, start, pane, if tall { 7 } else { 5 });
        let memory = Rect::new(right, start, pane, 5);
        let disk = Rect::new(margin, cpu.bottom() + gap.max(1), pane, 4);
        let network = Rect::new(right, disk.y, pane, 4);
        let maintenance = disk.bottom() + gap;
        Self {
            area,
            badge,
            identity_y,
            cpu,
            memory,
            disk,
            network,
            maintenance,
            wide,
        }
    }
    fn target(&self, target: Target) -> Rect {
        let top = u16::from(self.wide);
        match target {
            Target::Search => Rect::new(self.area.right() - 14, top, 14, 1),
            Target::Changes => Rect::new(self.area.right() - 16, self.maintenance + 1, 16, 1),
            _ => {
                let index = TARGETS.iter().position(|item| *item == target).unwrap() as u16;
                Rect::new(self.area.x + 16 + index * 8, top, 7, 1)
            }
        }
    }
    pub fn hit(&self, col: u16, row: u16, changes: bool) -> Option<Target> {
        TARGETS
            .into_iter()
            .filter(|t| *t != Target::Changes || changes)
            .find(|t| self.target(*t).contains((col, row).into()))
    }
}
fn strong() -> Style {
    Style::default().add_modifier(Modifier::BOLD)
}
fn ink() -> Style {
    theme::brand().add_modifier(Modifier::BOLD)
}
fn line(frame: &mut Frame, left: u16, top: u16, width: u16, text: impl Into<Line<'static>>) {
    frame.render_widget(Paragraph::new(text.into()), Rect::new(left, top, width, 1))
}
pub(super) fn section(frame: &mut Frame, area: Rect, title: &str) {
    line(
        frame,
        area.x,
        area.y,
        area.width,
        Line::from(vec![
            Span::styled(format!("{title}  "), ink()),
            Span::styled(
                "─".repeat(area.width.into()),
                Style::default().add_modifier(Modifier::DIM),
            ),
        ]),
    );
}
fn symbol(system: &str, height: u16) -> &'static [&'static str] {
    if height == 4 {
        return match system {
            "macOS" => &["     ▗▛   ", " ▗▟██▟██▙ ", " ▜█████▛  ", "  ▜█▛▀▜█▘ "],
            name if name.contains("Debian") => {
                &["   ▗▄▅▅▄  ", " ▗▛ ▗▄▖ ▜▌", " ▐▙ ▝▀▀▀▘ ", "   ▀▚▄▄   "]
            }
            _ => &["   ▗▄▄▖   ", "   ▌••▐   ", "  ▟▌▾ ▐▙  ", "  ▀▀  ▀▀  "],
        };
    }
    if system == "macOS" {
        &[
            "     ▗▛   ",
            " ▗▟██▟██▙ ",
            " ▟█████▛  ",
            " ▜██████▙ ",
            "  ▜█▛▀▜█▘ ",
        ]
    } else if system.contains("Debian") {
        &[
            "   ▗▄▅▅▄  ",
            " ▗▛ ▗▄▄ ▜▌",
            " ▐▌ ▝▙ ▀▟▘",
            "  ▜▙ ▝▀▀  ",
            "    ▀▚▄   ",
        ]
    } else {
        &[
            "   ▗▄▄▖   ",
            "   ▌••▐   ",
            "  ▟▌▾ ▐▙  ",
            " ▐█▌  ▐█▌ ",
            "  ▀▀  ▀▀  ",
        ]
    }
}
pub(super) fn header(frame: &mut Frame, state: &State, graphic: bool) {
    let size = frame.area();
    let layout = Layout::new(size.width, size.height);
    let current = state.route.section();
    if !graphic {
        let slot = layout.wordmark();
        line(
            frame,
            slot.x,
            slot.y,
            slot.width,
            Line::styled("HMOPS", ink()),
        );
    }
    for &target in &TARGETS[..5] {
        let rect = layout.target(target);
        let focus = state.header_focus && state.home_target == target && state.nav_enabled();
        let text = if target == Target::Search {
            "[ 搜索 / ]".into()
        } else {
            format!(" {} ", target.label())
        };
        let style = if focus {
            strong().add_modifier(Modifier::REVERSED)
        } else if target == current {
            ink()
        } else {
            Style::default()
        };
        let label = Line::styled(text, style);
        line(
            frame,
            rect.x,
            rect.y,
            rect.width,
            if target == Target::Search {
                label.right_aligned()
            } else {
                label
            },
        );
    }
    let nav = layout.target(current);
    line(frame, nav.x + 1, nav.y + 1, 4, Line::styled("━━━━", ink()));
}

pub(super) fn draw(frame: &mut Frame, state: &State, graphic: bool) {
    let size = frame.area();
    let layout = Layout::new(size.width, size.height);
    let area = layout.area;
    let identity = state.overview.identity.as_ref();
    let text = |get: fn(&overview::Identity) -> &String| {
        identity.map(|info| get(info).as_str()).unwrap_or("读取中")
    };
    let start = layout.badge.right() + 2;
    let width = area.right() - start;
    let hero = layout.identity_y;
    if !graphic {
        for (row, text) in symbol(&state.system, layout.badge.height)
            .iter()
            .enumerate()
        {
            line(
                frame,
                layout.badge.x,
                layout.badge.y + row as u16,
                layout.badge.width,
                Line::styled(*text, ink()),
            );
        }
    }
    let uptime = identity
        .and_then(|v| v.boot_age.map(|age| age + v.sampled.elapsed()))
        .map(|age| {
            format!(
                "已运行 {} 天 {} 小时",
                age.as_secs() / 86400,
                age.as_secs() / 3600 % 24
            )
        })
        .unwrap_or_else(|| "运行时间未读取".into());
    let session = if env::var_os("SSH_CONNECTION").is_some() {
        "SSH"
    } else {
        "本地"
    };
    let model = identity.and_then(|v| v.model.as_deref());
    let (title, subtitle) = match (session, model) {
        ("本地", Some(model)) => (model, Some(state.machine.as_str())),
        (_, model) => (state.machine.as_str(), model),
    };
    line(
        frame,
        start,
        hero,
        width - 18,
        Line::styled(title.to_owned(), strong()),
    );
    line(
        frame,
        area.right() - 17,
        hero,
        17,
        format!("{session} · 普通权限"),
    );
    let mut row = hero + 1;
    if let Some(subtitle) = subtitle {
        line(frame, start, row, width, subtitle.to_owned());
        row += 1;
    }
    if layout.wide {
        let hardware = identity
            .map(|info| info.processor.as_str())
            .unwrap_or("读取中");
        let memory = state
            .overview
            .resources
            .memory
            .map(|(_, total)| format!("  ·  {} 内存", resources::capacity(total)))
            .unwrap_or_default();
        line(frame, start, row, width, format!("{hardware}{memory}"));
        row += 1;
    }
    let os = identity.map(|v| v.os.as_str()).unwrap_or(&state.system);
    if layout.wide && subtitle.is_none() {
        line(frame, start, row, width, os.to_owned());
        row += 1;
    }
    line(
        frame,
        start,
        row,
        width,
        if layout.wide && subtitle.is_none() {
            uptime
        } else {
            format!("{os}  ·  {uptime}")
        },
    );
    resources::draw(frame, &layout, &state.overview);
    let info = layout.maintenance;
    section(frame, Rect::new(area.x, info, area.width, 1), "配置状态");
    let dirty = state.has_changes();
    line(
        frame,
        area.x,
        info + 1,
        area.width - 17,
        Line::from(vec![
            Span::raw("工作区    "),
            Span::styled(
                text(|v| &v.repository).to_owned(),
                if dirty {
                    Style::default().fg(Color::Yellow)
                } else {
                    Style::default()
                },
            ),
        ]),
    );
    if dirty {
        let rect = layout.target(Target::Changes);
        line(
            frame,
            rect.x,
            rect.y,
            rect.width,
            Line::styled(
                "[ 查看更改 ↵ ]",
                if state.header_focus && state.nav_enabled() && state.home_target == Target::Changes
                {
                    strong().add_modifier(Modifier::REVERSED)
                } else {
                    Style::default()
                },
            )
            .right_aligned(),
        );
    }
    let config = Line::from(format!("生效配置  {}", text(|v| &v.generation)));
    let clipped = config.width() > usize::from(area.width);
    line(
        frame,
        area.x,
        info + 2,
        area.width - u16::from(clipped),
        config,
    );
    if clipped {
        line(frame, area.right() - 1, info + 2, 1, "…");
    }
    if dirty {
        line(
            frame,
            area.x,
            info + 3,
            area.width,
            "同步会在预检时停止，当前系统不受影响。",
        );
    }
    line(
        frame,
        area.x,
        size.height - 2,
        area.width,
        Line::styled(
            "─".repeat(area.width.into()),
            Style::default().add_modifier(Modifier::DIM),
        ),
    );
    line(
        frame,
        area.x,
        size.height - 1,
        area.width,
        "Tab / ←→ 选择    ↵ 打开    / 搜索    ? 帮助    q 退出",
    );
}
