# macOS 第三方 App Quarantine 排障

通过 Homebrew Cask 安装第三方 GUI 应用后，macOS 可能报错：
`“<App>.app” 已损坏，无法打开。你应该将它移到废纸篓。`

常见场景：

- `easytier-gui`
- `TokenTrackerBar`

## 原因

- 应用带有 `com.apple.quarantine` 标记。
- 应用签名 / 公证状态不符合 Gatekeeper 要求。

## 排查步骤

1. 先确认应用位置：

   /Applications/<App>.app
   或
   ~/Applications/<App>.app

   可用以下命令确认：

   mdfind "kMDItemFSName == '<App>.app'"
   ls -ld /Applications/*<App>*

2. 检查是否存在 quarantine 标记：

   xattr -l "/Applications/<App>.app"

   若输出包含 `com.apple.quarantine`，说明被隔离。

3. 仅在信任该应用时移除 quarantine：

   sudo xattr -r -d com.apple.quarantine "/Applications/<App>.app"

   推荐优先使用上面的精确删除命令，不要一开始就用：

   sudo xattr -cr "/Applications/<App>.app"

   `xattr -cr` 会清空全部扩展属性，范围更大，仅在精确删除 `com.apple.quarantine` 无效时再使用。

4. 若仍失败，检查签名与 Gatekeeper 评估：

   codesign --verify --deep --strict --verbose=2 "/Applications/<App>.app"
   spctl --assess --type execute -vv "/Applications/<App>.app"

5. 可尝试重新安装：

   brew reinstall --cask <cask-name>
   或
   brew uninstall --cask <cask-name> && brew install --cask <cask-name>

   例如：

   brew reinstall --cask easytier-gui
   brew reinstall --cask mm7894215/tokentracker/tokentracker

6. 仅在确认来源可信且其他方法无效时，才考虑临时关闭 Gatekeeper：

   sudo spctl --master-disable
   open -a "/Applications/<App>.app"
   sudo spctl --master-enable

## 注意

- 不要对不可信的二进制执行移除 quarantine 或关闭 Gatekeeper。
- 如果上述方法都无法解决，可能包本身未被开发者正确签名/公证，需要向软件发布者或 Homebrew Cask 仓库报告 issue。
- `/Applications` 下通常需要 `sudo`，`~/Applications` 下通常不需要。
