use super::*;

pub(super) fn sources(frame: &mut Frame, area: Rect, items: &[ActionId], state: &State) {
    row(frame, area, 0, Line::styled("日志", bold()));
    dashboard::section(frame, after(area, 2), "日志来源");
    let list = after(area, 3);
    let entries: Vec<_> = items
        .iter()
        .filter_map(|action| {
            let Logs(module) = action else { return None };
            let description = match module {
                Module::Mihomo => "代理服务与内核日志",
                Module::Multica => "后台任务日志",
                Module::Magpie => "网关服务日志",
            };
            Some((module.name().to_owned(), description))
        })
        .collect();
    if entries.is_empty() {
        row(frame, list, 0, "本机未配置日志来源");
    } else {
        described_items(frame, list, &entries, state);
    }
}

pub(super) fn reader(frame: &mut Frame, area: Rect, reader: &Reader) -> String {
    row(frame, area, 0, Line::styled(reader.title.clone(), bold()));
    let mut status = match (reader.live(), reader.paused) {
        (false, true) => "跟随已结束 · 已暂停",
        (false, false) => "跟随已结束",
        (true, true) => "已暂停",
        (true, false) => "跟随中",
    }
    .to_owned();
    if reader.editing || !reader.filter.is_empty() {
        status.push_str(" · 筛选：");
        status.push_str(&reader.filter);
        if reader.editing {
            status.push('▏');
        }
    }
    row(frame, area, 1, status);
    let mut data = after(area, 2);
    if !reader.notice.is_empty() {
        row(frame, data, 0, reader.notice.clone());
        data = after(data, 1);
    }
    let lines = reader.matching();
    if !lines.is_empty() {
        let end = lines.len().saturating_sub(reader.offset);
        let start = end.saturating_sub(data.height.into());
        for (index, line) in lines[start..end].iter().enumerate() {
            row(frame, data, index as u16, clean(line));
        }
    } else if !reader.lines.is_empty() {
        row(frame, data, 0, "没有匹配的日志");
    } else if reader.notice.is_empty() {
        row(frame, data, 0, "暂无记录");
    }
    if reader.editing {
        return "Enter 应用筛选   Esc 结束输入".into();
    }
    let mut hint = String::from("↑↓ 翻阅   / 筛选");
    if reader.live() || reader.paused {
        hint.push_str(if reader.paused {
            "   空格 恢复"
        } else {
            "   空格 暂停"
        });
    }
    match reader.kernel {
        Some(false) => hint.push_str("   l 内核日志"),
        Some(true) => hint.push_str("   l 服务日志"),
        None => {}
    }
    hint.push_str("   Esc 返回");
    hint
}
