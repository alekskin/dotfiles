#
# ~/.bash_profile
#

# Login-shell PATH: SDDM starts sway through a non-interactive login shell,
# so anything after .bashrc's interactive guard never reaches sway or wofi.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$PATH:$HOME/.local/bin" ;; esac

[[ -f ~/.bashrc ]] && . ~/.bashrc
