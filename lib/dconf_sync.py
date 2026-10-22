#!/usr/bin/env python3
"""Respalda y restaura los ajustes de GNOME (dconf) separados en dos grupos:

  dconf/tema.ini      lo que necesita el rice para verse y funcionar: los ajustes de sus extensiones,
                      activarlas y las optimizaciones (GNOME Software, indexador, Xwayland).
                      install.sh lo aplica siempre.
  dconf/personal.ini  preferencias de quien lo usa: favoritos, orden de las apps, touchpad, atajos,
                      proveedores de búsqueda, privacidad... install.sh lo aplica solo con --personal.

Fuentes, iconos, cursor, tema GTK y colores no se guardan en ninguno: los pone cybersigil-apply
desde palette.sh. Al restaurar, las extensiones activadas se SUMAN a las que ya haya.

Uso:  dconf_sync.py backup <repo>
      dconf_sync.py restore <archivo.ini>
"""
import ast
import os
import subprocess
import sys
import tempfile

# Extensiones del rice: se activan siempre y sus ajustes son parte del tema
THEME_UUIDS = {
    "cybersigil-widgets@donza",
    "tilingshell@ferrarodomenico.com",
    "blur-my-shell@aunetx",
    "just-perfection-desktop@just-perfection",
    "user-theme@gnome-shell-extensions.gcampax.github.com",
}
THEME_EXT_SETTINGS = ("blur-my-shell", "just-perfection", "tilingshell", "user-theme")

# Claves sueltas del tema (optimizaciones)
THEME_KEYS = {
    "org/gnome/shell": ["disable-user-extensions"],
    "org/gnome/mutter/experimental": ["autoclose-xwayland"],
    "org/freedesktop/tracker/miner/files": ["index-on-battery"],
    "org/gnome/software": ["allow-updates", "download-updates", "download-updates-notify"],
}

# Rutas cuyo contenido (recursivo) se reparte entre tema y personal
DIRS = [
    "org/gnome/shell",
    "org/gnome/desktop/interface",
    "org/gnome/desktop/wm/preferences",
    "org/gnome/desktop/wm/keybindings",
    "org/gnome/desktop/peripherals/touchpad",
    "org/gnome/desktop/search-providers",
    "org/gnome/desktop/privacy",
    "org/gnome/settings-daemon/plugins/media-keys",
]

# Nunca se guardan:
SKIP = {
    # estado interno que cambia solo; settings-version en otra versión de GNOME rompería sus migraciones
    "command-history", "welcome-dialog-last-shown-version", "check-timestamp", "first-run",
    "last-selected-power-profile", "last-version-name-installed", "settings-version",
    # Tiling Shell vacía estos atajos mientras está activa (los originales quedan en overridden-settings):
    # restaurarlos dejaría Super+↑/↓ sin función si Tiling Shell no está activa
    "overridden-settings", "maximize", "unmaximize",
}
# Los pone cybersigil-apply desde palette.sh
APPLY_MANAGED = {
    "org/gnome/desktop/interface": {"gtk-theme", "icon-theme", "cursor-theme", "font-name", "document-font-name",
                                    "monospace-font-name", "color-scheme", "accent-color"},
    "org/gnome/desktop/wm/preferences": {"titlebar-font"},
}


def dconf(*args, stdin=None):
    return subprocess.run(["dconf", *args], input=stdin, capture_output=True, text=True, check=True).stdout


def parse_ini(text, base=""):
    """Formato de 'dconf dump': [sección] y clave=valor (GVariant en una línea). Devuelve {ruta: {clave: valor}}."""
    sections, current = {}, None
    for line in text.splitlines():
        if line.startswith("[") and line.endswith("]"):
            rel = line[1:-1].strip("/")
            current = "/".join(p for p in (base, rel) if p)
            sections.setdefault(current, {})
        elif "=" in line and current is not None:
            key, value = line.split("=", 1)
            sections[current][key] = value
    return sections


def to_ini(sections):
    out = []
    for path in sorted(sections):
        if sections[path]:
            out.append(f"[{path}]")
            out += [f"{k}={v}" for k, v in sorted(sections[path].items())]
            out.append("")
    return "\n".join(out)


def gvariant_list(value):
    return ast.literal_eval(value.removeprefix("@as ")) if value else []


def classify(path, key):
    """'tema', 'personal' o None (no se guarda)."""
    if key in SKIP or key in APPLY_MANAGED.get(path, ()):
        return None
    if key in THEME_KEYS.get(path, ()):
        return "tema"
    parts = path.split("/")
    if parts[:4] == ["org", "gnome", "shell", "extensions"] and len(parts) > 4:
        return "tema" if parts[4] in THEME_EXT_SETTINGS else "personal"
    return "personal"


def backup(repo):
    groups = {"tema": {}, "personal": {}}
    for d in DIRS:
        for path, keys in parse_ini(dconf("dump", f"/{d}/"), d).items():
            for key, value in keys.items():
                if (path, key) == ("org/gnome/shell", "enabled-extensions"):
                    enabled = gvariant_list(value)
                    for group, items in (("tema", [e for e in enabled if e in THEME_UUIDS]),
                                         ("personal", [e for e in enabled if e not in THEME_UUIDS])):
                        if items:
                            groups[group].setdefault(path, {})[key] = str(items)
                    continue
                group = classify(path, key)
                if group:
                    groups[group].setdefault(path, {})[key] = value
    for path, keys in THEME_KEYS.items():
        if path in DIRS:
            continue
        for key in keys:
            value = dconf("read", f"/{path}/{key}").strip()
            if value:
                groups["tema"].setdefault(path, {})[key] = value
    os.makedirs(f"{repo}/dconf", exist_ok=True)
    for group, sections in groups.items():
        with open(f"{repo}/dconf/{group}.ini", "w") as f:
            f.write(to_ini(sections))


def restore(ini):
    with open(ini) as f:
        sections = parse_ini(f.read())
    shell = sections.get("org/gnome/shell", {})
    extra = gvariant_list(shell.pop("enabled-extensions", ""))
    with tempfile.NamedTemporaryFile("w", suffix=".ini") as tmp:
        tmp.write(to_ini(sections))
        tmp.flush()
        with open(tmp.name) as f:
            dconf("load", "/", stdin=f.read())
    if extra:
        current = gvariant_list(dconf("read", "/org/gnome/shell/enabled-extensions").strip())
        merged = current + [e for e in extra if e not in current]
        dconf("write", "/org/gnome/shell/enabled-extensions", str(merged))
    print(f"  ↳ {sum(len(k) for k in sections.values()) + bool(extra)} ajustes de {os.path.basename(ini)}")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("backup", "restore"):
        sys.exit(__doc__)
    backup(sys.argv[2]) if sys.argv[1] == "backup" else restore(sys.argv[2])
