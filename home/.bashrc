#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
# SSH en kitty: los servidores no conocen TERM=xterm-kitty (nano, htop y clear fallan con
# "unknown terminal type"). `kitten ssh` copia esa definición al servidor la primera vez y
# activa la integración de kitty allá; con -T/-N/-f/-G/-n se comporta como ssh común.
# Para equipos sin shell (routers, switches) o si algo falla: ssh-plain
if [[ $TERM == xterm-kitty ]]; then
  alias ssh='kitten ssh'
  alias ssh-plain='TERM=xterm-256color command ssh'
fi
PS1='[\u@\h \W]\$ '
[[ :$PATH: == *:$HOME/.local/bin:* ]] || export PATH="$HOME/.local/bin:$PATH"

# historial más largo y compartido entre terminales (lo aprovecha fzf con Ctrl+R)
HISTSIZE=50000; HISTFILESIZE=100000; HISTCONTROL=ignoreboth:erasedups
shopt -s histappend; PROMPT_COMMAND+=('history -a')

# Cybersigil. starship va después de tocar PROMPT_COMMAND: así lee primero el código
# de salida del último comando (si no, el prompt nunca se pone rojo en un error)
[[ $TERM != dumb ]] && command -v starship >/dev/null && eval "$(starship init bash)"
[[ -f ~/.config/cybersigil/generated/fzf.sh ]] && . ~/.config/cybersigil/generated/fzf.sh

# Variables secretas (API keys, tokens) y ajustes de esta máquina: ~/.bashrc.local
# Ese archivo NO está en el repo; ~/.bashrc sí (es público).
[[ -f ~/.bashrc.local ]] && . ~/.bashrc.local
