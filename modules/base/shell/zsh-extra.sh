# --- ZSH Autosuggestions configuration ---
# manual rebind to avoid conflicts with fzf-tab
export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
# limit the size of the suggestion buffer to improve performance
export ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# --- FZF-TAB configuration ---
# disable menu completion to let fzf-tab handle it
zstyle ':completion:*' menu no
# set ls colors for completion listings
zstyle ':completion:*:*' list-colors "${(s.:.)LS_COLORS}"
# cd command preview with eza
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons --group-directories-first $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always --icons --group-directories-first $realpath'
# environment variable preview
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
	fzf-preview 'echo ${(P)word}'
# default file preview with bat
zstyle ':fzf-tab:complete:*' fzf-preview 'bat --color=always --style=numbers,changes --line-range=:500 $realpath'
# bind autosuggest accept to Ctrl+Space
bindkey '^ ' autosuggest-accept

# --- YSU (You Should Use) configuration ---
# positions the message after the command line
export YSU_MESSAGE_POSITION="after"
# show suggestions for all commands
# export YSU_MODE="ALL"
