use crossterm::event::{Event, KeyCode, KeyModifiers};
use ratatui::layout::Rect;
use std::{
    env,
    io::{self, Write},
    time::{Duration, Instant},
};
pub(super) struct Badge {
    enabled: bool,
    data: &'static str,
    placed: [Option<Rect>; 2],
    id: u32,
    probe: Option<Instant>,
    receipt: Option<(Instant, String)>,
}
impl Badge {
    pub fn new(system: &str) -> Self {
        let id = std::process::id() * 2;
        let direct = env::var("TERM").as_deref() != Ok("dumb")
            && ["TMUX", "STY", "SSH_CONNECTION", "NO_COLOR"]
                .iter()
                .all(|name| env::var_os(name).is_none());
        let probe = direct
            .then(|| {
                let mut output = io::stdout().lock();
                write!(output, "\x1b_Ga=q,i={id},s=1,v=1,f=24;AAAA\x1b\\")
                    .and_then(|_| output.flush())
                    .ok()
                    .map(|()| Instant::now())
            })
            .flatten();
        Self {
            enabled: false,
            data: if system == "macOS" {
                include_str!("badges/mac.b64")
            } else if system.contains("Debian") {
                include_str!("badges/debian.b64")
            } else {
                include_str!("badges/linux.b64")
            },
            placed: [None; 2],
            id,
            probe,
            receipt: None,
        }
    }
    pub fn consume_reply(&mut self, event: &Event) -> bool {
        let Event::Key(key) = event else { return false };
        let Some(start) = self.probe else {
            return false;
        };
        let alt = key.modifiers.contains(KeyModifiers::ALT);
        if alt && key.code == KeyCode::Char('_') {
            self.receipt = Some((Instant::now(), String::new()));
            return true;
        }
        let Some((opened, body)) = &mut self.receipt else {
            return false;
        };
        if alt && key.code == KeyCode::Char('\\') {
            self.enabled = start.elapsed() < Duration::from_millis(500)
                && *body == format!("Gi={};OK", self.id);
            self.receipt = None;
            self.probe = None;
            return true;
        }
        if let KeyCode::Char(ch) = key.code {
            if !alt
                && (ch.is_ascii_graphic() || ch == ' ')
                && opened.elapsed() < Duration::from_millis(120)
                && body.len() < 256
            {
                body.push(ch);
                return true;
            }
        }
        self.receipt = None;
        false
    }
    pub fn visible_candidate(&self, show: bool) -> bool {
        self.enabled && show
    }
    pub fn sync(&mut self, slots: [Option<Rect>; 2]) -> io::Result<()> {
        if self.placed != slots {
            let mut out = io::stdout().lock();
            for (index, slot) in slots.into_iter().enumerate() {
                if self.placed[index] == slot {
                    continue;
                }
                let id = self.id + index as u32;
                if self.placed[index].take().is_some() {
                    write!(out, "\x1b_Ga=d,d=I,i={id},q=2\x1b\\")?;
                }
                let Some(slot) = slot else {
                    continue;
                };
                let data = if index == 0 {
                    self.data
                } else {
                    include_str!("badges/wordmark.b64")
                };
                let (row, col) = (slot.y + 1, slot.x + 1);
                write!(
                    out,
                    "\x1b7\x1b[{row};{col}H\x1b_Ga=T,f=100,t=d,i={},c={},r={},C=1,",
                    id, slot.width, slot.height
                )?;
                let mut chunks = data.trim().as_bytes().chunks(4096).peekable();
                while let Some(chunk) = chunks.next() {
                    let more = chunks.peek().is_some();
                    write!(out, "q=2,m={};", u8::from(more))?;
                    out.write_all(chunk)?;
                    out.write_all(b"\x1b\\")?;
                    if more {
                        out.write_all(b"\x1b_G")?;
                    }
                }
                out.write_all(b"\x1b8")?;
                self.placed[index] = Some(slot);
            }
            out.flush()?;
        }
        Ok(())
    }
}
impl Drop for Badge {
    fn drop(&mut self) {
        let _ = self.sync([None, None]);
    }
}
