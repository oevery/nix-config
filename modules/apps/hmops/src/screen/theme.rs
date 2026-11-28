use ratatui::style::{Color, Style};
use std::{env, sync::LazyLock};

pub(super) static RGB: LazyLock<bool> =
    LazyLock::new(|| matches!(env::var("COLORTERM").as_deref(), Ok("truecolor" | "24bit")));
pub(super) static PLAIN: LazyLock<bool> = LazyLock::new(|| env::var_os("NO_COLOR").is_some());

pub(super) fn brand() -> Style {
    if *PLAIN {
        Style::default()
    } else {
        Style::default().fg(if *RGB {
            Color::Rgb(67, 143, 144)
        } else {
            Color::Cyan
        })
    }
}
