use super::{actions::Module, LogOrigin};
use std::{
    collections::VecDeque,
    io::Read,
    process::{Child, Command, Stdio},
    sync::{Arc, Mutex},
    thread,
};

const LIMIT: usize = 256;
const LINE_BYTES: usize = 2048;
const DENIED: &str = "当前用户无权读取此日志";
const LIMITED: &str = "权限受限，仅显示当前用户可见的日志";
#[derive(Default)]
struct Feed {
    lines: VecDeque<String>,
    notice: String,
    version: u64,
}
impl Feed {
    fn append(&mut self, text: String) {
        if self.lines.len() == LIMIT {
            self.lines.pop_front();
        }
        self.lines.push_back(text);
        self.version += 1;
    }
}
pub(super) struct Reader {
    pub origin: Option<Box<LogOrigin>>,
    pub kernel: Option<bool>,
    pub title: String,
    pub filter: String,
    pub editing: bool,
    pub paused: bool,
    pub offset: usize,
    pub tail_view: bool,
    shared: Arc<Mutex<Feed>>,
    pub lines: Vec<String>,
    pub notice: String,
    version: u64,
    child: Option<Child>,
}
impl Reader {
    pub fn text(title: String, text: String) -> Self {
        let mut reader = Self::new(title);
        reader.lines = text.lines().map(str::to_owned).collect();
        reader.paused = true;
        reader
    }
    fn new(title: String) -> Self {
        Self {
            origin: None,
            kernel: None,
            title,
            filter: String::new(),
            editing: false,
            paused: false,
            offset: 0,
            tail_view: false,
            shared: Default::default(),
            lines: vec![],
            notice: String::new(),
            version: 0,
            child: None,
        }
    }
    pub fn live(&self) -> bool {
        self.child.is_some()
    }
    pub fn logs(origin: LogOrigin) -> Self {
        let mut reader = Self::new(String::new());
        reader.tail_view = true;
        reader.kernel = (origin.module == Module::Mihomo).then_some(false);
        reader.origin = Some(Box::new(origin));
        reader.connect();
        reader
    }
    pub fn connect(&mut self) {
        let Some(origin) = &self.origin else { return };
        let module = origin.module;
        let kernel = self.kernel == Some(true);
        let mode = if kernel {
            "内核实时日志"
        } else {
            "服务日志"
        };
        self.title = format!("{} / {mode}", origin.breadcrumb);
        self.shared = Default::default();
        self.version = 0;
        self.notice.clear();
        let mut cmd = if module == Module::Mihomo {
            let mut cmd = Command::new("mihomoctl");
            if kernel {
                cmd.args(["logs", "--live", "--level", "info"]);
            } else {
                cmd.args(["logs", "-n", "100", "-f"]);
            }
            cmd
        } else {
            let mut cmd = Command::new("journalctl");
            cmd.arg("--user");
            cmd.args([
                "--no-pager",
                "-n",
                "100",
                "-f",
                "-o",
                "short-iso",
                "-u",
                module.unit(),
            ])
            .env("LC_ALL", "C");
            cmd
        };
        match cmd
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
        {
            Ok(mut child) => {
                drain(child.stdout.take().unwrap(), self.shared.clone(), false);
                drain(child.stderr.take().unwrap(), self.shared.clone(), true);
                self.child = Some(child);
            }
            Err(err) => self.notice = format!("无法启动日志读取器：{err}"),
        }
    }
    pub fn stop(&mut self) -> bool {
        if let Some(mut child) = self.child.take() {
            let _ = child.kill();
            let _ = child.wait();
            true
        } else {
            false
        }
    }
    pub fn poll(&mut self) -> bool {
        let mut changed = false;
        if let Some(child) = &mut self.child {
            if let Ok(Some(status)) = child.try_wait() {
                self.child = None;
                let mut feed = self.shared.lock().unwrap();
                if !status.success() && feed.notice.is_empty() {
                    feed.notice = format!("日志读取失败（{status}）");
                    feed.version += 1;
                }
                changed = true;
            }
        }
        let feed = self.shared.lock().unwrap();
        if !feed.notice.is_empty() && self.notice != feed.notice {
            self.notice.clone_from(&feed.notice);
            changed = true;
        }
        if !self.paused && self.version != feed.version {
            self.lines = feed.lines.iter().cloned().collect();
            self.version = feed.version;
            changed = true;
        }
        changed
    }
    pub fn matching(&self) -> Vec<&str> {
        self.lines
            .iter()
            .map(String::as_str)
            .filter(|line| line.contains(&self.filter))
            .collect()
    }
}
impl Drop for Reader {
    fn drop(&mut self) {
        self.stop();
    }
}
fn drain(mut stream: impl Read + Send + 'static, shared: Arc<Mutex<Feed>>, diagnostic: bool) {
    thread::spawn(move || {
        let mut buf = [0u8; 4096];
        let mut line = Vec::new();
        let publish = |bytes: &[u8]| {
            let text: String = String::from_utf8_lossy(bytes)
                .chars()
                .filter(|ch| !ch.is_control())
                .collect();
            let mut feed = shared.lock().unwrap();
            if diagnostic {
                if text.is_empty() {
                    return;
                }
                let lower = text.to_ascii_lowercase();
                if lower.contains("permission denied")
                    || lower.contains("insufficient permissions")
                    || lower.contains("access denied")
                    || text.contains("无权读取")
                    || text.contains("没有读取日志或控制器的权限")
                {
                    feed.notice = DENIED.into();
                } else if feed.notice == DENIED {
                    return;
                } else if lower.contains("not seeing") {
                    feed.notice = LIMITED.into();
                } else if text.contains("尚无服务日志；") {
                    feed.notice = "暂无记录：尚无服务日志文件".into();
                } else if feed.notice != LIMITED {
                    feed.notice = format!("日志读取提示：{text}");
                }
                feed.version += 1;
            } else if text != "-- No entries --" {
                feed.append(text);
            }
        };
        while let Ok(size) = stream.read(&mut buf) {
            if size == 0 {
                break;
            }
            for byte in &buf[..size] {
                if *byte == b'\n' {
                    publish(&line);
                    line.clear();
                } else if line.len() < LINE_BYTES {
                    line.push(*byte);
                }
            }
        }
        if !line.is_empty() {
            publish(&line);
        }
    });
}
