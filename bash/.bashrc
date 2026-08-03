#
# ~/.bashrc
#

# Point ssh at the systemd --user ssh-agent (ssh-agent.service) so the key
# passphrase is cached once per login instead of asked on every push. The
# sway session doesn't propagate environment.d to shells, so set it here.
# Before the interactive guard so non-interactive git-over-ssh gets it too.
if [ -z "${SSH_AUTH_SOCK:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/ssh-agent.socket" ]; then
  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
fi

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Default editor (git, systemctl edit, etc.) — package: neovim
export EDITOR=nvim
export VISUAL=nvim

# Prompt (https://starship.rs) — package: starship
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# fzf key bindings + fuzzy completion (https://junegunn.github.io/fzf/installation/)
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi

PATH="$PATH:$HOME/.local/bin"

# opencode
[[ -d "$HOME/.opencode/bin" ]] && export PATH="$HOME/.opencode/bin:$PATH"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
[[ -r "$HOME/.grok/completions/bash/grok.bash" ]] && source "$HOME/.grok/completions/bash/grok.bash"
# <<< grok installer <<<
