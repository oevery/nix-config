# --- ZSH Autosuggestions configuration ---
# 手动重新绑定，避免与 fzf-tab 冲突
export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
# 限制建议缓冲区大小，提升性能
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# --- FZF-TAB 配置 ---
# 关闭菜单式补全，交由 fzf-tab 接管
zstyle ':completion:*' menu no
# 为补全列表设置 LS_COLORS 颜色
zstyle ':completion:*:*' list-colors "${(s.:.)LS_COLORS}"
# 使用 eza 预览 cd 目标目录
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons --group-directories-first $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always --icons --group-directories-first $realpath'
# 环境变量补全时显示变量值
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
	fzf-preview 'echo ${(P)word}'
# 默认文件预览使用 bat
zstyle ':fzf-tab:complete:*' fzf-preview 'bat --color=always --style=numbers,changes --line-range=:500 $realpath'
# 将接受自动建议绑定到 Ctrl+Space
bindkey '^ ' autosuggest-accept

# --- YSU (You Should Use) 配置 ---
# 提示信息显示在命令行之后
export YSU_MESSAGE_POSITION="after"
# 为所有命令显示建议
# export YSU_MODE="ALL"
