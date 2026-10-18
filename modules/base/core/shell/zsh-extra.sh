# --- ZSH Autosuggestions configuration ---
# 手动重新绑定，避免与 fzf-tab 冲突
export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
# 长命令也提供建议，并清除旧 shell 可能继承的长度限制。
unset ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE

# --- FZF-TAB 配置 ---
# 关闭菜单式补全，交由 fzf-tab 接管
zstyle ':completion:*' menu no
# 为补全列表设置 LS_COLORS 颜色
zstyle ':completion:*:*' list-colors "${(s.:.)LS_COLORS}"
# 使用 eza 预览 cd 目标目录
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons --group-directories-first $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always --icons --group-directories-first $realpath'
# 变量补全不预览内容，避免展开敏感值或回退到文件预览。
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
	fzf-preview ''
# 默认文件预览使用 bat
zstyle ':fzf-tab:complete:*' fzf-preview 'bat --paging=never --decorations=always --color=always --style=numbers,changes --line-range=:500 $realpath'
# 将接受自动建议绑定到 Ctrl+Space
bindkey '^ ' autosuggest-accept
