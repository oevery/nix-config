use super::*;

pub(super) fn draw(
    frame: &mut Frame,
    area: Rect,
    host: &Host,
    state: &State,
    mode: Mode,
    labels: &[String],
) {
    let title = match mode {
        Mode::Sync => "同步已锁定配置",
        Mode::Daily => "日常更新",
        Mode::All => "完整系统更新",
    };
    let steps = host.steps(mode);
    let report = if state.report_mode == Some(mode) {
        state.report.as_slice()
    } else {
        &[]
    };
    let stopped = report.iter().find(|entry| entry.starts_with('×'));
    let status = if stopped.is_some() {
        "已停止"
    } else if state.job.is_some() {
        "执行中"
    } else if report.is_empty() {
        "只读预览"
    } else {
        "已完成"
    };
    row(
        frame,
        area,
        0,
        Line::from(vec![
            Span::styled(format!("{title}  "), bold()),
            Span::styled(status, accent()),
        ]),
    );
    row(
        frame,
        area,
        1,
        format!(
            "{}  ·  {} 个步骤  ·  {}",
            host.name,
            steps.len(),
            if mode == Mode::All {
                "包含宿主系统更新"
            } else {
                "不含宿主系统更新"
            }
        ),
    );

    let wide = frame.area().width >= 104;
    let top = if area.height >= 26 { 4 } else { 3 };
    let content = after(area, top);
    let (timeline, context) = if wide {
        let half = (content.width - 4) / 2;
        (
            Rect {
                width: half,
                ..content
            },
            Rect {
                x: content.x + half + 4,
                width: content.width - half - 4,
                ..content
            },
        )
    } else {
        (after(content, 1), content)
    };
    dashboard::section(frame, timeline, "执行步骤");
    for (index, step) in steps.iter().enumerate() {
        let (label, style) = match report.get(index).and_then(|entry| entry.chars().next()) {
            Some('✓') => ("✓ 已完成", accent()),
            Some('×') => (
                "× 失败  ",
                if *theme::PLAIN {
                    bold()
                } else {
                    bold().fg(Color::Red)
                },
            ),
            Some('—') => ("— 未执行", Style::default().add_modifier(Modifier::DIM)),
            _ if state.job.as_ref().is_some_and(|job| job.index == index) => ("▸ 执行中", accent()),
            _ => ("· 待执行", Style::default()),
        };
        row(
            frame,
            timeline,
            index as u16 + 1,
            Line::from(vec![
                Span::styled(label, style),
                Span::raw(format!("   {}", step.label)),
            ]),
        );
    }

    if wide {
        dashboard::section(frame, context, "存储空间");
    }
    let mut volume = vec![Span::raw("Nix 卷  ")];
    if let Some((available, used)) = state.capacity {
        volume.extend(dashboard::usage_bar(used, 8));
        volume.push(Span::raw(format!(
            "  {used}% · 可用 {:.1} GiB",
            available as f64 / 1_048_576.0
        )));
    } else {
        volume.push(Span::raw("可用空间未知"));
    }
    row(frame, context, u16::from(wide), Line::from(volume));
    let mut actions = if wide { 4 } else { steps.len() as u16 + 2 };
    if let Some(reason) = stopped {
        let reason_area = after(context, actions);
        let height = if wide { 3 } else { 1 };
        frame.render_widget(
            Paragraph::new(reason.as_str()).wrap(Wrap { trim: true }),
            Rect {
                height: height.min(reason_area.height),
                ..reason_area
            },
        );
        actions += height;
    }
    if state.job.is_none() {
        dashboard::section(frame, after(context, actions), "可用操作");
        menu(
            frame,
            after(context, actions + 1),
            labels,
            state.focus,
            state.content_focused(),
        );
    }
}
