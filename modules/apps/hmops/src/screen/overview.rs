use super::{clean, poll, repo, spawn, Reply};
use std::{
    collections::VecDeque,
    env, fs,
    path::{Path, PathBuf},
    process::Command,
    sync::mpsc::Receiver,
    time::{Duration, Instant},
};
use sysinfo::{Networks, System};
mod disk_io;
fn field(value: Option<String>) -> String {
    value
        .map(|s| clean(s.trim()))
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "未读取".into())
}
#[cfg(target_os = "macos")]
fn model() -> Option<String> {
    let tree = super::output(
        "/usr/sbin/ioreg",
        &["-p", "IODeviceTree", "-r", "-n", "product", "-d1"],
    )
    .ok()?;
    tree.lines().find_map(|line| {
        line.split_once("\"product-name\" = <\"")?
            .1
            .strip_suffix("\">")
            .map(clean)
    })
}
#[cfg(not(target_os = "macos"))]
fn model() -> Option<String> {
    [
        "/sys/class/dmi/id/product_name",
        "/sys/firmware/devicetree/base/model",
    ]
    .iter()
    .find_map(|p| fs::read_to_string(p).ok())
}
pub(super) struct Identity {
    pub os: String,
    pub model: Option<String>,
    pub processor: String,
    pub boot_age: Option<Duration>,
    pub sampled: Instant,
    pub generation: String,
    pub filesystem: Option<String>,
    pub repository: String,
    pub changes: Option<String>,
}
fn generation() -> Option<String> {
    let (profile, active) = if cfg!(target_os = "macos") {
        (
            PathBuf::from("/nix/var/nix/profiles/system"),
            PathBuf::from("/run/current-system"),
        )
    } else {
        let home = PathBuf::from(env::var_os("HOME")?);
        let state = env::var_os("XDG_STATE_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/state"));
        (
            state.join("nix/profiles/home-manager"),
            state.join("home-manager/gcroots/current-home"),
        )
    };
    active_generation(&profile, &active)
}
fn active_generation(profile: &Path, active: &Path) -> Option<String> {
    let link = fs::read_link(profile).ok()?;
    let root = fs::canonicalize(profile.parent()?.join(&link)).ok()?;
    if root != fs::canonicalize(active).ok()? {
        return None;
    }
    let name = link
        .file_name()?
        .to_str()?
        .strip_suffix("-link")?
        .rsplit('-')
        .next()?
        .parse::<u64>()
        .ok()?;
    let revision = if cfg!(target_os = "macos") {
        fs::read(root.join("darwin-version.json"))
            .ok()
            .and_then(|data| serde_json::from_slice::<serde_json::Value>(&data).ok())
            .and_then(|meta| meta["configurationRevision"].as_str().map(str::to_owned))
    } else {
        fs::read_to_string(root.join("hmops-revision")).ok()
    };
    let revision = revision.as_deref().unwrap_or_default().trim();
    let hash = revision.strip_suffix("-dirty").unwrap_or(revision);
    if !matches!(hash.len(), 40 | 64) || !hash.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Some(format!("#{name} · 未记录来源提交"));
    }
    let subject = repo().ok().and_then(|dir| {
        let output = Command::new("git")
            .current_dir(dir)
            .env("GIT_NO_LAZY_FETCH", "1")
            .args([
                "--no-replace-objects",
                "show",
                "-s",
                "--no-show-signature",
                "--format=%s",
                hash,
                "--",
            ])
            .output()
            .ok()?;
        output
            .status
            .success()
            .then(|| clean(String::from_utf8_lossy(&output.stdout).trim()))
    });
    let dirty = if revision != hash {
        "（含未提交改动）"
    } else {
        ""
    };
    Some(format!(
        "#{name} · {}{dirty} · {}",
        &hash[..8],
        subject
            .filter(|s| !s.is_empty())
            .as_deref()
            .unwrap_or("标题不可用")
    ))
}
fn repository() -> Option<(String, Option<String>)> {
    let output = Command::new("git")
        .current_dir(repo().ok()?)
        .args([
            "--no-optional-locks",
            "status",
            "--porcelain=v1",
            "--branch",
            "--untracked-files=normal",
        ])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let raw = String::from_utf8_lossy(&output.stdout);
    let mut lines = raw.lines();
    let branch = clean(lines.next()?.strip_prefix("## ")?.split("...").next()?);
    let changes = lines.map(clean).collect::<Vec<_>>();
    let dirty = !changes.is_empty();
    Some((
        format!(
            "{branch}  ·  {}",
            if dirty {
                "有未提交的更改"
            } else {
                "工作区干净"
            }
        ),
        dirty.then(|| changes.join("\n")),
    ))
}
impl Identity {
    fn collect() -> Self {
        let mut sys = System::new();
        sys.refresh_cpu_usage();
        let (repository, changes) = repository().unwrap_or_else(|| ("未读取".into(), None));
        let cores = core_groups().unwrap_or_else(|| format!("{} 逻辑核", sys.cpus().len()));
        let processor = sys
            .cpus()
            .first()
            .map(|cpu| format!("{} · {cores}", cpu.brand().trim()));
        Self {
            os: field(System::long_os_version()),
            model: model().map(|v| clean(v.trim())).filter(|v| !v.is_empty()),
            processor: field(processor),
            boot_age: Some(Duration::from_secs(System::uptime())),
            sampled: Instant::now(),
            generation: generation().unwrap_or_else(|| "未读取".into()),
            filesystem: filesystem(),
            repository,
            changes,
        }
    }
}
#[cfg(target_os = "macos")]
fn core_groups() -> Option<String> {
    let fields = super::output(
        "/usr/sbin/sysctl",
        &[
            "-n",
            "hw.perflevel0.name",
            "hw.perflevel0.physicalcpu",
            "hw.perflevel1.name",
            "hw.perflevel1.physicalcpu",
        ],
    )
    .ok()?;
    let mut values = fields.lines();
    let mut groups = (None, None);
    for _ in 0..2 {
        let name = values.next()?;
        let count = values.next()?.parse::<u32>().ok().filter(|n| *n > 0)?;
        match name {
            "Performance" | "Super" => groups.0 = Some(count),
            "Efficiency" => groups.1 = Some(count),
            _ => return None,
        }
    }
    Some(format!("{}P + {}E", groups.0?, groups.1?))
}
#[cfg(not(target_os = "macos"))]
fn core_groups() -> Option<String> {
    None
}
fn volume_path() -> &'static str {
    #[cfg(target_os = "macos")]
    if std::path::Path::new("/System/Volumes/Data").is_dir() {
        return "/System/Volumes/Data";
    }
    "/"
}
#[cfg(target_os = "macos")]
fn filesystem() -> Option<String> {
    let stats = rustix::fs::statfs(volume_path()).ok()?;
    let bytes: Vec<u8> = stats
        .f_fstypename
        .iter()
        .take_while(|c| **c != 0)
        .map(|c| *c as u8)
        .collect();
    Some(String::from_utf8(bytes).ok()?.to_ascii_uppercase())
}
#[cfg(not(target_os = "macos"))]
fn filesystem() -> Option<String> {
    fs::read_to_string("/proc/self/mountinfo")
        .ok()?
        .lines()
        .find_map(|line| {
            let (mount, fs) = line.split_once(" - ")?;
            (mount.split_whitespace().nth(4)? == "/")
                .then(|| fs.split_whitespace().next().map(str::to_ascii_uppercase))?
        })
}
pub(super) struct Volume {
    pub used: u64,
    pub available: u64,
    pub total: u64,
}
fn volume() -> Option<Volume> {
    let stats = rustix::fs::statvfs(volume_path()).ok()?;
    let total = stats.f_blocks.checked_mul(stats.f_frsize)?;
    let used = stats
        .f_blocks
        .checked_sub(stats.f_bfree)?
        .checked_mul(stats.f_frsize)?;
    let available = stats.f_bavail.checked_mul(stats.f_frsize)?;
    (total > 0 && available <= total).then_some(Volume {
        used,
        available,
        total,
    })
}
#[derive(Default)]
pub(super) struct Resources {
    pub cpu: Option<f64>,
    pub load: Option<sysinfo::LoadAvg>,
    pub busy: Vec<(usize, f32)>,
    pub interface: Option<String>,
    pub address: Option<std::net::IpAddr>,
    pub disk_rates: Option<(f64, f64)>,
    pub rates: Option<(f64, f64)>,
    pub memory: Option<(u64, u64)>,
    pub headroom: Option<u64>,
    pub swap: Option<(u64, u64)>,
    pub volume: Option<Volume>,
}
#[cfg(target_os = "macos")]
fn available_memory(_: &System) -> Option<u64> {
    let vm = super::output("/usr/bin/vm_stat", &[]).ok()?;
    let pagesize = vm
        .lines()
        .next()?
        .split("page size of ")
        .nth(1)?
        .split_whitespace()
        .next()?
        .parse::<u64>()
        .ok()?;
    let pages = |key: &str| {
        vm.lines()
            .find_map(|line| line.strip_prefix(key))?
            .trim()
            .trim_end_matches('.')
            .parse::<u64>()
            .ok()
    };
    pages("Pages free:")?
        .checked_add(pages("Pages inactive:")?)?
        .checked_mul(pagesize)
}
#[cfg(not(target_os = "macos"))]
fn available_memory(system: &System) -> Option<u64> {
    Some(system.available_memory())
}

#[cfg(target_os = "macos")]
fn interface() -> Option<String> {
    ["-inet", "-inet6"].iter().find_map(|family| {
        super::output("/sbin/route", &["-n", "get", family, "default"])
            .ok()?
            .lines()
            .find_map(|line| {
                line.trim()
                    .strip_prefix("interface:")
                    .map(|name| clean(name.trim()))
            })
    })
}
#[cfg(not(target_os = "macos"))]
fn interface() -> Option<String> {
    let routes = fs::read_to_string("/proc/net/route").ok();
    routes
        .as_deref()
        .unwrap_or("")
        .lines()
        .filter_map(|line| {
            let cols: Vec<_> = line.split_whitespace().collect();
            let flags = u32::from_str_radix(cols.get(3)?, 16).ok()?;
            (*cols.get(1)? == "00000000"
                && *cols.get(7)? == "00000000"
                && flags & 1 != 0
                && flags & 0x200 == 0)
                .then_some((cols.get(6)?.parse::<u32>().ok()?, cols[0]))
        })
        .min()
        .map(|(_, iface)| iface.to_owned())
        .or_else(|| {
            fs::read_to_string("/proc/net/ipv6_route")
                .ok()?
                .lines()
                .filter_map(|line| {
                    let cols: Vec<_> = line.split_whitespace().collect();
                    let flags = u32::from_str_radix(cols.get(8)?, 16).ok()?;
                    (*cols.first()? == "00000000000000000000000000000000"
                        && *cols.get(1)? == "00"
                        && flags & 1 != 0
                        && flags & 0x200 == 0)
                        .then_some((
                            u32::from_str_radix(cols.get(5)?, 16).ok()?,
                            cols.get(9)?.to_string(),
                        ))
                })
                .min()
                .map(|(_, iface)| iface)
        })
}

#[derive(Default)]
struct Sampler {
    system: System,
    networks: Networks,
    previous: Option<Instant>,
    counters: Option<(String, u64, u64)>,
    disk_counters: Option<(String, u64, u64)>,
}
type Counters = (String, u64, u64);
fn rates(
    previous: Option<&Counters>,
    current: Option<&Counters>,
    elapsed: Option<Duration>,
) -> Option<(f64, f64)> {
    let (before, read, write) = previous?;
    let (after, next_read, next_write) = current?;
    let seconds = elapsed?.as_secs_f64();
    if before != after {
        return None;
    }
    Some((
        next_read.checked_sub(*read)? as f64 / seconds,
        next_write.checked_sub(*write)? as f64 / seconds,
    ))
}
impl Sampler {
    fn sample(&mut self) -> Resources {
        self.system.refresh_cpu_usage();
        self.system
            .refresh_memory_specifics(sysinfo::MemoryRefreshKind::nothing().with_ram().with_swap());
        let total = self.system.total_memory();
        let headroom = available_memory(&self.system).filter(|n| total > 0 && *n <= total);
        let swap = (self.system.used_swap(), self.system.total_swap());
        let interface = interface();
        self.networks.refresh(true);
        let net = interface.as_ref().and_then(|name| self.networks.get(name));
        let counters = interface
            .clone()
            .zip(net)
            .map(|(name, net)| (name, net.total_received(), net.total_transmitted()));
        let address = net.and_then(|net| {
            net.ip_networks()
                .iter()
                .map(|network| network.addr)
                .filter(|ip| !ip.is_unspecified() && !ip.is_loopback() && !ip.is_multicast())
                .min_by_key(|ip| match ip {
                    std::net::IpAddr::V4(_) => 0,
                    std::net::IpAddr::V6(v6) if v6.is_unicast_link_local() => 2,
                    _ => 1,
                })
        });
        let disk = disk_io::counters();
        let now = Instant::now();
        let elapsed = self
            .previous
            .replace(now)
            .map(|prev| now.duration_since(prev))
            .filter(|d| *d >= sysinfo::MINIMUM_CPU_UPDATE_INTERVAL && *d < Duration::from_secs(8));
        let disk_rates = rates(self.disk_counters.as_ref(), disk.as_ref(), elapsed);
        self.disk_counters = disk;
        let rates = rates(self.counters.as_ref(), counters.as_ref(), elapsed);
        self.counters = counters;
        let cpu = elapsed
            .filter(|_| !self.system.cpus().is_empty())
            .map(|_| f64::from(self.system.global_cpu_usage()))
            .filter(|n| (0.0..=100.0).contains(n));
        let mut busy = Vec::new();
        if cpu.is_some() {
            busy.extend(
                self.system
                    .cpus()
                    .iter()
                    .enumerate()
                    .map(|(index, core)| (index + 1, core.cpu_usage())),
            );
            busy.sort_by(|left, right| right.1.total_cmp(&left.1));
            busy.truncate(4);
        }
        Resources {
            cpu,
            load: Some(System::load_average()),
            busy,
            interface,
            address,
            disk_rates,
            rates,
            headroom,
            memory: headroom.map(|n| (total - n, total)),
            swap: (swap.0 <= swap.1).then_some(swap),
            volume: volume(),
        }
    }
}
pub(super) struct Overview {
    pub identity: Option<Identity>,
    pub resources: Resources,
    pub traffic: VecDeque<(f64, f64)>,
    identity_rx: Option<Receiver<Reply<Identity>>>,
    sampler: Option<Sampler>,
    reading: Option<Receiver<Reply<(Sampler, Resources)>>>,
    next: Instant,
}
impl Overview {
    pub fn new() -> Self {
        Self {
            identity: None,
            resources: Resources::default(),
            traffic: VecDeque::new(),
            identity_rx: Some(spawn(|| Ok(Identity::collect()))),
            sampler: Some(Sampler::default()),
            reading: None,
            next: Instant::now(),
        }
    }
    pub fn refresh(&mut self) {
        if self.identity_rx.is_none() {
            self.identity_rx = Some(spawn(|| Ok(Identity::collect())))
        }
    }
    pub fn tick(&mut self) -> bool {
        let mut dirty = false;
        if let Some(result) = self.identity_rx.as_ref().and_then(poll) {
            self.identity_rx = None;
            self.identity = result.ok();
            dirty = true
        }
        if let Some(result) = self.reading.as_ref().and_then(poll) {
            let (sampler, resources) = result.unwrap_or_default();
            if resources.rates.is_none() || resources.interface != self.resources.interface {
                self.traffic.clear();
            }
            if let Some(point) = resources.rates {
                if self.traffic.len() == 16 {
                    self.traffic.pop_front();
                }
                self.traffic.push_back(point);
            }
            self.resources = resources;
            self.sampler = Some(sampler);
            self.reading = None;
            self.next = Instant::now() + Duration::from_secs(3);
            dirty = true;
        }
        if Instant::now() >= self.next {
            if let Some(mut sampler) = self.sampler.take() {
                self.reading = Some(spawn(move || {
                    let resources = sampler.sample();
                    Ok((sampler, resources))
                }));
            }
        }
        dirty
    }
}
