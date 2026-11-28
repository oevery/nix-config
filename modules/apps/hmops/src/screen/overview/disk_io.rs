#[cfg(target_os = "macos")]
pub(super) fn counters() -> Option<super::Counters> {
    let mount = rustix::fs::statfs(super::volume_path()).ok()?;
    let name: Vec<_> = mount
        .f_mntfromname
        .iter()
        .take_while(|c| **c != 0)
        .map(|c| *c as u8)
        .collect();
    let device = std::str::from_utf8(&name).ok()?.strip_prefix("/dev/")?;
    let tree = super::super::output(
        "/usr/sbin/ioreg",
        &["-r", "-c", "AppleAPFSVolume", "-d1", "-w0"],
    )
    .ok()?;
    let property = format!("\"BSD Name\" = \"{device}\"");
    tree.split("+-o ").find_map(|entry| {
        if !entry.lines().any(|line| line.trim() == property) {
            return None;
        }
        let stats = entry
            .lines()
            .find_map(|line| line.trim().strip_prefix("\"Statistics\" = "))?;
        let bytes = |key| {
            stats
                .split_once(key)?
                .1
                .split([',', '}'])
                .next()?
                .parse::<u64>()
                .ok()
        };
        Some((
            entry
                .lines()
                .next()?
                .split_once("id ")?
                .1
                .split(',')
                .next()?
                .to_owned(),
            bytes("\"Bytes read from block device\"=")?,
            bytes("\"Bytes written to block device\"=")?,
        ))
    })
}

#[cfg(target_os = "linux")]
pub(super) fn counters() -> Option<super::Counters> {
    use std::os::unix::fs::MetadataExt;
    let dev = std::fs::metadata(super::volume_path()).ok()?.dev();
    let device = format!("{}:{}", rustix::fs::major(dev), rustix::fs::minor(dev));
    let path = std::fs::canonicalize(format!("/sys/dev/block/{device}")).ok()?;
    let stats = std::fs::read_to_string(path.join("stat")).ok()?;
    let mut fields = stats.split_whitespace();
    let read = fields.nth(2)?.parse::<u64>().ok()?.checked_mul(512)?;
    let write = fields.nth(3)?.parse::<u64>().ok()?.checked_mul(512)?;
    Some((path.to_str()?.into(), read, write))
}
