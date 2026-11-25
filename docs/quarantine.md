# macOS 第三方 App Quarantine 排障

通过 Homebrew Cask 安装的 App 提示“已损坏，无法打开”时，不要把提示直接当成误报。以下以 EasyTier 为例；把 `app` 设成 Finder 中确认过的实际路径，再执行检查。

```zsh
app="/Applications/easytier-gui.app"
ls -ld "$app"
xattr -l "$app"
codesign --verify --deep --strict --verbose=2 "$app"
spctl --assess --type execute -vv "$app"
```

- **路径不对**：同时检查 `~/Applications`。不要用通配符批量处理应用。
- **签名无效、来源不明，或无法解释 Gatekeeper 拒绝原因**：不要移除隔离标记。核对发布者和 cask；必要时从可信来源重新安装（例如 `brew reinstall --cask easytier-gui`），再检查。仍失败时向发布者报告。
- **已核实来源、签名和评估结果，确需移除隔离标记**：仅对该 App 执行 `xattr -rd com.apple.quarantine "$app"`。已激活本仓库配置的 Zsh 可用 `unq "$app"`。再用 `xattr -l "$app"` 确认标记已移除；这不等于应用通过安全验证。

不要为单个 App 关闭系统 Gatekeeper，也不需要用 `xattr -cr` 清空其他扩展属性。
