use super::*;

#[derive(Clone, Copy)]
enum Tone {
    Mint,
    Gold,
    Red,
}
fn usage_tone(ratio: f64) -> Tone {
    if ratio >= 0.90 {
        Tone::Red
    } else if ratio >= 0.70 {
        Tone::Gold
    } else {
        Tone::Mint
    }
}
pub(super) fn capacity(bytes: u64) -> String {
    if bytes == 0 {
        return "0 B".into();
    }
    if bytes < 1 << 20 {
        return format!("{} KiB", bytes.div_ceil(1024));
    }
    if bytes < 1 << 30 {
        return format!("{:.0} MiB", bytes as f64 / 1048576.);
    }
    format!("{:.1} GiB", bytes as f64 / 1073741824.)
}
struct Palette {
    rgb: bool,
    plain: bool,
}
impl Palette {
    fn new() -> Self {
        Self {
            rgb: *theme::RGB,
            plain: *theme::PLAIN,
        }
    }
    fn mint(&self) -> Color {
        if self.rgb {
            Color::Rgb(113, 181, 141)
        } else {
            Color::Green
        }
    }
    fn gauge(&self, value: f64, width: usize, tone: Tone) -> Vec<Span<'static>> {
        let count = (width as f64 * value).round() as usize;
        let (fill, track) = match (self.rgb, tone) {
            (true, Tone::Mint) => (self.mint(), Color::Rgb(197, 218, 206)),
            (true, Tone::Gold) => (Color::Rgb(225, 178, 81), Color::Rgb(235, 219, 179)),
            (false, Tone::Mint) => (self.mint(), Color::Green),
            (false, Tone::Gold) => (Color::Yellow, Color::Yellow),
            (true, Tone::Red) => (Color::Rgb(223, 98, 99), Color::Rgb(239, 207, 207)),
            (false, Tone::Red) => (Color::Red, Color::Red),
        };
        let (solid, rest) = if self.plain {
            (Style::default(), Style::default())
        } else {
            (Style::default().fg(fill), Style::default().fg(track))
        };
        vec![
            Span::styled("█".repeat(count), solid),
            Span::styled(
                if self.rgb && !self.plain {
                    "█"
                } else {
                    "░"
                }
                .repeat(width - count),
                rest,
            ),
        ]
    }
}
fn label(name: &str) -> Span<'static> {
    Span::raw(format!(
        "{name}{}",
        " ".repeat(8usize.saturating_sub(Line::raw(name).width()))
    ))
}
pub(in crate::screen) fn usage_bar(percent: u8, width: usize) -> Vec<Span<'static>> {
    let ratio = f64::from(percent.min(100)) / 100.0;
    Palette::new().gauge(ratio, width, usage_tone(ratio))
}
fn bar_width(area: Rect) -> usize {
    if area.width < 54 {
        10
    } else {
        16
    }
}
fn measure(
    frame: &mut Frame,
    area: Rect,
    offset: u16,
    name: &str,
    fraction: Option<(u64, u64)>,
    palette: &Palette,
    suffix: String,
) {
    let mut spans = vec![label(name)];
    match fraction {
        Some((value, total)) if total > 0 && value <= total => {
            let ratio = value as f64 / total as f64;
            let tone = if name == "可用" {
                Tone::Mint
            } else {
                usage_tone(ratio)
            };
            spans.extend(palette.gauge(ratio, bar_width(area), tone));
            spans.push(Span::raw(format!("  {:>5.1}%  {suffix}", ratio * 100.)));
        }
        Some((0, 0)) => spans.push(Span::raw("无已分配空间")),
        _ => spans.push(Span::raw("未读取")),
    }
    line(
        frame,
        area.x,
        area.y + offset,
        area.width,
        Line::from(spans),
    );
}
pub(super) fn draw(frame: &mut Frame, layout: &Layout, overview: &overview::Overview) {
    let palette = Palette::new();
    let data = &overview.resources;
    let cpu = layout.cpu;
    section(frame, cpu, "◎ CPU");
    if let Some(value) = data.cpu {
        measure(
            frame,
            cpu,
            1,
            "占用",
            Some(((value * 100.).round() as u64, 10000)),
            &palette,
            String::new(),
        );
    } else {
        line(frame, cpu.x, cpu.y + 1, cpu.width, "占用  采样中");
    }
    for (rank, (core, value)) in data
        .busy
        .iter()
        .take(usize::from(cpu.height - 3))
        .enumerate()
    {
        measure(
            frame,
            cpu,
            2 + rank as u16,
            &format!("核心{core}"),
            Some(((value * 100.).round() as u64, 10000)),
            &palette,
            String::new(),
        );
    }
    if layout.wide {
        if let Some(load) = &data.load {
            line(
                frame,
                cpu.x,
                cpu.bottom() - 1,
                cpu.width,
                format!(
                    "负载    {:.2} / {:.2} / {:.2}",
                    load.one, load.five, load.fifteen
                ),
            );
        }
    } else if let Some(info) = &overview.identity {
        line(
            frame,
            cpu.x,
            cpu.bottom() - 1,
            cpu.width,
            info.processor.clone(),
        );
    }
    let mem = layout.memory;
    section(frame, mem, "▥ 内存");
    measure(frame, mem, 1, "已用", data.memory, &palette, String::new());
    let headroom = data
        .memory
        .and_then(|(_, total)| data.headroom.map(|bytes| (bytes, total)));
    measure(
        frame,
        mem,
        2,
        "可用",
        headroom,
        &palette,
        if layout.wide {
            String::new()
        } else {
            data.headroom.map(capacity).unwrap_or_default()
        },
    );
    let swap = data
        .swap
        .map(|(used, total)| pair(used, total))
        .unwrap_or_default();
    if layout.wide {
        measure(frame, mem, 3, "交换", data.swap, &palette, swap);
    }
    if let Some((used, total)) = data.memory {
        line(
            frame,
            mem.x,
            mem.y + if layout.wide { 4 } else { 3 },
            mem.width,
            if layout.wide {
                format!(
                    "总览  {} · 可用 {}",
                    pair(used, total),
                    capacity(total - used)
                )
            } else {
                format!("已用  {}", pair(used, total))
            },
        );
    }
    let disk = layout.disk;
    section(frame, disk, "▤ 存储");
    if let Some(volume) = &data.volume {
        let figures = pair(volume.used, volume.total);
        let mut spans = vec![label("占用")];
        let ratio = volume.used as f64 / volume.total as f64;
        spans.extend(palette.gauge(ratio, bar_width(disk), usage_tone(ratio)));
        spans.push(Span::raw(format!("  {:>5.1}%", ratio * 100.)));
        let mut gauge = Line::from(spans);
        let inline = gauge.width() + 2 + Line::raw(&*figures).width() <= usize::from(disk.width);
        if inline {
            gauge.spans.push(Span::raw(format!("  {figures}")));
        }
        line(frame, disk.x, disk.y + 1, disk.width, gauge);
        let filesystem = overview
            .identity
            .as_ref()
            .and_then(|v| v.filesystem.as_ref())
            .map(|s| format!(" · {s}"))
            .unwrap_or_default();
        line(
            frame,
            disk.x,
            disk.y + 2,
            disk.width,
            if inline {
                format!("可用  {}{filesystem}", capacity(volume.available))
            } else {
                format!("容量  {figures}{filesystem}")
            },
        );
        if let Some((read, write)) = data.disk_rates {
            line(
                frame,
                disk.x,
                disk.y + 3,
                disk.width,
                format!(
                    "读 {}  写 {}",
                    speed(read).trim_start(),
                    speed(write).trim_start()
                ),
            );
        }
    } else {
        line(frame, disk.x, disk.y + 1, disk.width, "占用  未读取");
    }
    let net = layout.network;
    let interface = data.interface.as_deref().unwrap_or("接口未读取");
    let address = data
        .address
        .map(|ip| ip.to_string())
        .unwrap_or_else(|| "地址未读取".into());
    let summary = format!("{address} · {interface}");
    let compact_address = Line::raw(&*summary).width() > usize::from(net.width);
    if compact_address {
        section(frame, net, &format!("⇅ 网络 · {interface}"));
    } else {
        section(frame, net, "⇅ 网络");
    }
    let history: Vec<_> = overview.traffic.iter().rev().take(bar_width(net)).collect();
    let peak = history
        .iter()
        .fold(0_f64, |max, point| max.max(point.0).max(point.1));
    let decade = 10_f64.powf(peak.max(1.).log10().floor());
    let scale = [1., 2., 5., 10.]
        .map(|step| step * decade)
        .into_iter()
        .find(|limit| *limit >= peak)
        .unwrap_or(10. * decade);
    for (offset, name, rate) in [
        (1, "下载", data.rates.map(|v| v.0)),
        (2, "上传", data.rates.map(|v| v.1)),
    ] {
        let value = rate.map(speed).unwrap_or_else(|| "—".into());
        let mut trace = "▁".repeat(bar_width(net) - history.len());
        for point in history.iter().rev() {
            let sample = if offset == 1 { point.0 } else { point.1 };
            trace.push(if sample == 0. {
                '▁'
            } else {
                ['▂', '▃', '▄', '▅', '▆', '▇', '█']
                    [(sample / scale * 7.).round().clamp(1., 7.) as usize - 1]
            });
        }
        line(
            frame,
            net.x,
            net.y + offset,
            net.width,
            Line::from(vec![
                label(name),
                Span::styled(
                    trace,
                    if palette.plain {
                        Style::default()
                    } else {
                        Style::default().fg(palette.mint())
                    },
                ),
                Span::raw(format!("  {value}")),
            ]),
        );
    }
    let extra = if compact_address {
        (address.len() as u16)
            .saturating_sub(net.width)
            .min(net.x - layout.disk.right())
    } else {
        0
    };
    line(
        frame,
        net.x - extra,
        net.y + 3,
        net.width + extra,
        if compact_address { address } else { summary },
    );
}
fn pair(used: u64, total: u64) -> String {
    let (used, total) = (capacity(used), capacity(total));
    if let (Some((value, unit)), Some((_, total_unit))) =
        (used.split_once(' '), total.split_once(' '))
    {
        if unit == total_unit {
            return format!("{value} / {total}");
        }
    }
    format!("{used} / {total}")
}
fn speed(bytes: f64) -> String {
    let (value, unit) = if bytes >= 1_000_000_000. {
        (bytes / 1_000_000_000., "GB/s")
    } else if bytes >= 1_000_000. {
        (bytes / 1_000_000., "MB/s")
    } else if bytes >= 1000. {
        (bytes / 1000., "kB/s")
    } else {
        (bytes, "B/s")
    };
    format!("{value:>6.2} {unit}")
}
