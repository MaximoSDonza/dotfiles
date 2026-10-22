# Cybersigil — fzf. Generado por cybersigil-apply; se carga desde ~/.bashrc
command -v fzf >/dev/null || return 0

export FZF_DEFAULT_OPTS="--height=45% --layout=reverse --border=sharp --info=inline-right \
--prompt='⸸ ' --pointer='⛧' --marker='✠' --separator='─' \
--color=bg:-1,bg+:@@SURFACE_HI@@,fg:@@CHROME@@,fg+:@@CHROME_HI@@,hl:@@ACCENT_HI@@,hl+:@@ACCENT_HI@@ \
--color=border:@@CHROME_DIM@@,prompt:@@ACCENT_HI@@,pointer:@@ACCENT_HI@@,marker:@@ACCENT_HI@@ \
--color=info:@@CHROME_DIM@@,spinner:@@CHROME@@,header:@@CHROME@@,gutter:-1,separator:@@CHROME_DIM@@"

# Ctrl+T usa ripgrep: respeta .gitignore y salta node_modules, .git, etc.
if command -v rg >/dev/null; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi
# vista previa: texto con head; binarios (imágenes, pdf...) solo su tipo, sin basura en pantalla
export FZF_CTRL_T_OPTS='--preview "[[ $(file -bL --mime-encoding {}) == binary ]] && file -bL {} || head -n 80 {}" --preview-window=right,55%,border-left'
export FZF_ALT_C_OPTS="--preview 'ls -la --color=always {} | head -n 40'"

# Ctrl+R historial · Ctrl+T archivos · Alt+C saltar a carpeta · **<Tab> autocompletar
eval "$(fzf --bash)"
