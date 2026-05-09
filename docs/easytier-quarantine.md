easytier-quarantine.md

当通过 Homebrew Cask 安装 easytier-gui 后，macOS 可能会报错：
“"easytier-gui.app" 已损坏，无法打开。你应该将它移到废纸篓。”

原因
- macOS Gatekeeper 对从网络下载的应用会打上 quarantine（隔离）标记，或要求应用通过代码签名/公证。Homebrew cask 安装的第三方 appbundle 在某些情况下会带有 quarantine 标记或签名问题，导致打开时报上述错误。

解决（安全优先，按顺序执行）
1) 首先确认应用的实际安装位置（Homebrew 常见位置）：

   /Applications/easytier-gui.app
   或
   ~/Applications/easytier-gui.app

   可在终端用 mdfind 或 ls 确认：

   mdfind "kMDItemFSName == 'easytier-gui.app'"
   ls -ld /Applications/*easytier*

2) 检查是否存在 quarantine 标记：

   xattr -l "/Applications/easytier-gui.app"

   如果输出包含 com.apple.quarantine，说明被隔离。

3) （仅当你信任该应用）移除 quarantine 标记：

   sudo xattr -r -d com.apple.quarantine "/Applications/easytier-gui.app"

   说明：此命令会递归删除 com.apple.quarantine 扩展属性，使 macOS 不再将该应用视为隔离状态。

4) 如果问题仍然存在，请检查签名与 Gatekeeper 评估：

   codesign --verify --deep --strict --verbose=2 "/Applications/easytier-gui.app"
   spctl --assess --type execute -vv "/Applications/easytier-gui.app"

5) 推荐操作（更安全）：重新安装 Cask

   brew reinstall --cask easytier-gui
   或
   brew uninstall --cask easytier-gui && brew install --cask easytier-gui

6) 仅在确定来源可信且其他方法无效时，才考虑临时关闭 Gatekeeper（有风险）：

   sudo spctl --master-disable
   open -a "/Applications/easytier-gui.app"
   sudo spctl --master-enable

注意
- 不要对不可信的二进制执行移除 quarantine 或关闭 Gatekeeper。
- 如果上述方法都无法解决，可能包本身未被开发者正确签名/公证，需要向软件发布者或 Homebrew Cask 仓库报告 issue。

此文档由系统自动生成并放置于项目 docs/ 目录，目的是记录常见 macOS Gatekeeper 问题与修复命令。
