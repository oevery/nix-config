use super::*;
use serde::Deserialize;

#[derive(Deserialize)]
pub(super) struct Entry {
    pub id: u64,
    pub name: String,
}
#[derive(Deserialize)]
pub(super) struct Panel {
    pub active_id: Option<u64>,
    pub subscriptions: Vec<Entry>,
    #[serde(skip)]
    pub focus: usize,
    #[serde(skip)]
    pub mode: Mode,
    #[serde(skip)]
    pub notice: String,
}
#[derive(Default)]
pub(super) enum Mode {
    #[default]
    List,
    Name(String),
    Confirm {
        remove: bool,
        id: u64,
    },
}
pub(super) enum Effect {
    Stay,
    Close,
    Changed,
}

pub(super) fn terminal<T>(
    display: &mut Display,
    work: impl FnOnce() -> Reply<T>,
) -> Reply<Reply<T>> {
    leave().map_err(|err| err.to_string())?;
    let result = work();
    if let Err(reason) = &result {
        eprintln!("{reason}\n按 Enter 返回控制台。");
        let _ = io::stdin().read_line(&mut String::new());
    }
    *display = enter()?;
    Ok(result)
}

fn invoke(args: &[&str], input: Option<&str>) -> Reply<Vec<u8>> {
    let mut child = Command::new("mihomoctl")
        .args(args)
        .stdin(if input.is_some() {
            Stdio::piped()
        } else {
            Stdio::inherit()
        })
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .map_err(|err| err.to_string())?;
    let written = input.map(|value| writeln!(child.stdin.take().unwrap(), "{value}"));
    let result = child.wait_with_output().map_err(|err| err.to_string())?;
    if !result.status.success() {
        return Err(format!("控制器操作未成功（{}）", result.status));
    }
    if let Some(Err(_)) = written {
        return Err("未能发送订阅地址".into());
    }
    Ok(result.stdout)
}

pub(super) fn apply_message(args: &[&str]) -> Reply<String> {
    let data: Value =
        serde_json::from_slice(&invoke(args, None)?).map_err(|_| "配置回执不是 JSON")?;
    data["message"]
        .as_str()
        .map(clean)
        .ok_or_else(|| "配置回执缺少说明".into())
}

impl Panel {
    pub fn load() -> Reply<Self> {
        serde_json::from_slice(&invoke(&["subscription", "list", "--json"], None)?)
            .map_err(|_| "无法解析订阅列表，请检查控制器版本".into())
    }

    pub fn key(&mut self, code: KeyCode, display: &mut Display) -> Reply<Effect> {
        let selected = self.subscriptions.get(self.focus).map(|entry| entry.id);
        let result = match (&mut self.mode, code) {
            (Mode::List, KeyCode::Esc) => return Ok(Effect::Close),
            (_, KeyCode::Esc) => {
                self.mode = Mode::List;
                return Ok(Effect::Stay);
            }
            (Mode::List, KeyCode::Down | KeyCode::Up) => {
                self.focus = shift(
                    self.focus,
                    if code == KeyCode::Down { 1 } else { -1 },
                    self.subscriptions.len(),
                );
                return Ok(Effect::Stay);
            }
            (Mode::List, KeyCode::Char('a')) => {
                self.mode = Mode::Name(String::new());
                return Ok(Effect::Stay);
            }
            (Mode::List, KeyCode::Char('d') | KeyCode::Enter) => {
                if let Some(id) = selected {
                    let remove = code == KeyCode::Char('d');
                    if self.active_id == Some(id) {
                        self.notice = if remove {
                            "不能移除当前订阅"
                        } else {
                            "已是当前订阅；刷新请用「更新当前配置」"
                        }
                        .into();
                    } else {
                        self.mode = Mode::Confirm { remove, id };
                    }
                }
                return Ok(Effect::Stay);
            }
            (Mode::Name(name), KeyCode::Backspace) => {
                name.pop();
                return Ok(Effect::Stay);
            }
            (Mode::Name(name), KeyCode::Char(ch)) if !ch.is_control() && name.len() < 128 => {
                name.push(ch);
                return Ok(Effect::Stay);
            }
            (Mode::Name(name), KeyCode::Enter) if !name.trim().is_empty() => {
                terminal(display, || {
                    let url =
                        rpassword::prompt_password("完整配置 HTTPS 地址（不回显；留空取消）：")
                            .map_err(|err| err.to_string())?;
                    if url.is_empty() {
                        return Ok("已取消添加".into());
                    }
                    invoke(
                        &["subscription", "add", "--stdin", "--", name.trim()],
                        Some(&url),
                    )?;
                    Ok("已添加订阅，未应用或切换".into())
                })?
            }
            (Mode::Confirm { remove, id }, KeyCode::Char('y')) => terminal(display, || {
                if *remove {
                    invoke(&["subscription", "remove", "--id", &id.to_string()], None)?;
                    Ok("已移除订阅".into())
                } else {
                    apply_message(&["subscription", "use", "--id", &id.to_string(), "--json"])
                }
            })?,
            _ => return Ok(Effect::Stay),
        };
        let notice = result.unwrap_or_else(|reason| format!("× {reason}"));
        match terminal(display, Self::load)? {
            Ok(mut fresh) => {
                fresh.focus = selected
                    .and_then(|id| fresh.subscriptions.iter().position(|entry| entry.id == id))
                    .unwrap_or(0);
                *self = fresh;
                self.notice = notice;
            }
            Err(reason) => {
                self.subscriptions.clear();
                self.active_id = None;
                self.focus = 0;
                self.mode = Mode::List;
                self.notice = format!("{notice}；列表未刷新：{reason}");
            }
        }
        Ok(Effect::Changed)
    }
}
