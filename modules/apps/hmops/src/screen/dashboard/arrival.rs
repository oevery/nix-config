use super::*;

fn sweep(col: u16, row: u16, size: Rect) -> f64 {
    0.13 + 0.38 * f64::from(col) / f64::from(size.width)
        + 0.41 * f64::from(row) / f64::from(size.height)
}

pub(in crate::screen) fn reveal(frame: &mut Frame, progress: f64, reduced: bool) {
    let size = frame.area();
    let buffer = frame.buffer_mut();
    let mut particles = Vec::new();
    for (index, cell) in buffer.content.iter_mut().enumerate() {
        let col = (index % usize::from(size.width)) as u16;
        let row = (index / usize::from(size.width)) as u16;
        let landing = sweep(col, row, size);
        if progress >= landing {
            continue;
        }
        let seed = (index as u32).wrapping_mul(2654435761).rotate_left(9);
        if cell.symbol() != " " && seed.is_multiple_of(if reduced { 4 } else { 3 }) {
            let distance = ((landing - progress) / landing).powi(2);
            let origin = |dest: u16, limit: u16, bits: u32| {
                let offset = f64::from((bits % u32::from(limit)) as u16) - f64::from(dest);
                (f64::from(dest) + offset * distance * if reduced { 0.12 } else { 1. }).round()
                    as u16
            };
            let pos = (
                origin(col, size.width, seed),
                origin(row, size.height, seed.rotate_left(13)),
            );
            if progress < sweep(pos.0.saturating_sub(2), pos.1, size) {
                particles.push((pos, landing - progress < 0.14));
            }
        }
        cell.reset();
    }
    for (pos, near) in particles {
        buffer[pos]
            .set_char(if near { '⠒' } else { '⠂' })
            .set_style(if near {
                ink()
            } else {
                theme::brand().add_modifier(Modifier::DIM)
            });
    }
}

pub(super) fn badge_ready(layout: &Layout, progress: f64) -> bool {
    sweep(layout.badge.right() + 2, layout.badge.bottom(), layout.area) <= progress
}
