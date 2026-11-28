mod ops;
mod screen;

use ops::{Host, Mode};
use std::{
    env,
    io::{self, IsTerminal},
};

const HELP: &str = "hmops — 控制台\n  tui [--motion full|reduced|off]\n  modules [--json] | status [--json] | check\n  sync | update [--all]\n  sync / update 支持 --plan（只列步骤）、--non-interactive（不请求人工认证）";

fn run(args: &[&str]) -> Result<(), String> {
    if matches!(args, [] | ["help"] | ["--help"] | ["-h"]) {
        println!("{HELP}");
        return Ok(());
    }
    if rustix::process::geteuid().is_root() {
        return Err("请以普通用户运行 hmops；需要管理员权限时由具体操作授权".into());
    }
    let machine =
        matches!(args.first(), Some(&"sync" | &"update")) && args.last() == Some(&"--json");
    let args = if machine {
        &args[..args.len() - 1]
    } else {
        args
    };
    let unattended = args.last() == Some(&"--non-interactive");
    let args = if unattended && matches!(args.first(), Some(&"sync" | &"update")) {
        &args[..args.len() - 1]
    } else {
        args
    };
    let host = Host::load()?;
    match args {
        ["tui"] => screen::run(&host, None),
        ["tui", "--motion", mode @ ("full" | "reduced" | "off")] => screen::run(&host, Some(*mode)),
        ["modules", "--json"] => {
            println!("{}", serde_json::json!(host.modules));
            Ok(())
        }
        ["modules"] => {
            println!("{}", host.modules.join("\n"));
            Ok(())
        }
        ["status", "--json"] => {
            println!("{}", host.status());
            Ok(())
        }
        ["status"] => {
            println!("{}", ops::describe(&host.status()));
            Ok(())
        }
        ["check"] => ops::command("hc", &[]),
        ["sync"]
        | ["sync", "--plan"]
        | ["update"]
        | ["update", "--plan"]
        | ["update", "--all"]
        | ["update", "--all", "--plan"] => {
            let mode = if args[0] == "sync" {
                Mode::Sync
            } else if args.contains(&"--all") {
                Mode::All
            } else {
                Mode::Daily
            };
            if args.contains(&"--plan") {
                if machine {
                    println!(
                        "{}",
                        serde_json::json!({"steps":host.steps(mode).into_iter().map(|step|step.label).collect::<Vec<_>>() })
                    );
                    return Ok(());
                }
                for step in host.steps(mode) {
                    println!("{}", step.label)
                }
                return Ok(());
            }
            host.update(
                mode,
                !machine && !unattended && io::stdin().is_terminal() && io::stderr().is_terminal(),
                machine,
                |line| eprintln!("{line}"),
            )
        }
        _ => Err(HELP.into()),
    }
}
fn main() {
    let args: Vec<_> = env::args().skip(1).collect();
    if let Err(message) = run(&args.iter().map(String::as_str).collect::<Vec<_>>()) {
        eprintln!("hmops: {message}");
        std::process::exit(1)
    }
}
