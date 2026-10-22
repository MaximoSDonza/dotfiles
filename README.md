<div align="center">

# ⸸ dotfiles ⸸

**Arch Linux · GNOME 51 · Wayland** — rice cibersigilista en negro, cromo y rojo sangre

![escritorio](assets/escritorio.png)

</div>

## Detalles

| | |
|---|---|
| **Distro** | Arch Linux (kernel zen) |
| **Escritorio** | GNOME 51 (Wayland) + GDM |
| **Tema de shell** | Cybersigil (propio, vía User Themes) |
| **GTK** | adw-gtk3-dark + overrides de libadwaita |
| **Iconos / Cursor** | Papirus-Dark (carpetas negras) / Bibata Modern Classic |
| **Terminal** | kitty |
| **Shell / Prompt** | bash + starship + fzf |
| **Fuentes** | Space Grotesk · JetBrainsMono Nerd Font · UnifrakturMaguntia |
| **Monitor** | btop |
| **Extensiones** | Just Perfection · User Themes · Blur my Shell · Tiling Shell · Cybersigil Widgets (propia) |

## Widgets de escritorio

Extensión propia (`home/.local/share/gnome-shell/extensions/cybersigil-widgets@donza`), en cristal negro
semitransparente con desenfoque y la paleta del tema:

| Widget | Muestra |
|---|---|
| Reloj | hora gótica (12 o 24 h, según GNOME), fecha y semana |
| Sistema | CPU, RAM, temperatura, disco y batería; las barras se ponen rojas al pasar el umbral |
| Clima | tu ciudad (Open-Meteo, sin cuenta ni clave): temperatura, estado, mín./máx. y lluvia |
| Red | WiFi o cable, señal, banda, IP y tráfico en vivo con gráfico del último minuto |
| Música | lo que suena en Spotify, YouTube (Brave/Firefox) o cualquier reproductor MPRIS, con controles |

Cuáles se muestran, dónde, opacidad y desenfoque se cambian en `palette.sh` (sección *Widgets*). La ciudad
va en `~/.config/cybersigil/local.sh`, que no se sube al repo:

```bash
WEATHER_CITY="Rosario"; WEATHER_REGION="Santa Fe"; WEATHER_LAT=-32.95; WEATHER_LON=-60.65
```

Todo se aplica con `cybersigil-apply` y volviendo a iniciar sesión. Los widgets con la misma posición se
apilan y comparten el ancho.

Consumo medido: ~0,2 % de un núcleo en reposo. Un widget tapado por completo por una ventana se
oculta y deja de medir (si no, se repintaría con su desenfoque cada vez que esa ventana se redibuja),
y la posición de la música se calcula localmente en vez de consultarle al reproductor cada segundo.

## Paleta

| Token | Color | Uso |
|---|---|---|
| `BG` | `#000000` | fondo base |
| `SURFACE` | `#141416` | menús y tarjetas |
| `TEXT` | `#d8d8dc` | texto |
| `CHROME` | `#9a9aa2` | bordes y líneas |
| `CHROME_HI` | `#f0f0f4` | brillo del cromo |
| `ACCENT` | `#8b0a14` | rojo sangre |

Todo el tema sale de un solo archivo: [`palette.sh`](home/.config/cybersigil/palette.sh).
Cambia un color y ejecuta `cybersigil-apply`: se regeneran el tema de GNOME Shell, GTK, kitty, starship, fastfetch, btop, fzf y el wallpaper (SVG generado por código).

## Estructura

```
home/            → se enlaza tal cual dentro de ~ (misma estructura que $HOME)
  .config/cybersigil/   palette.sh, apply.sh, system-tune.sh y plantillas
firefox/user.js  → Firefox sin telemetría
dconf/           → ajustes de GNOME y de las extensiones
packages/        → listas de paquetes (ver "Paquetes")
fonts/           → fuentes que no están en los repos, con su licencia OFL
plantillas/      → plantillas de Nautilus (clic derecho → Nuevo documento); se copian, no se enlazan
assets/          → imágenes del README
install.sh       → instala todo para tu usuario
uninstall.sh     → lo desinstala y deja GNOME como estaba
backup.sh        → actualiza dconf/ y las listas de aplicaciones de packages/
```

## Requisitos

| | |
|---|---|
| **Sistema** | Arch Linux o una derivada que use `pacman` (EndeavourOS, CachyOS…) |
| **Escritorio** | GNOME **51** en Wayland (grupo `gnome`). El tema de GNOME Shell y la extensión de widgets están hechos para esa versión; en otra pueden verse mal o desactivarse |
| **AUR** | `yay` u otro ayudante de AUR, para `aur-base.txt` |
| **Permisos** | un usuario con `sudo` |
| **Red** | conexión a internet: las extensiones se descargan de extensions.gnome.org y el clima es de Open-Meteo |
| **Hardware** | cualquier PC o laptop. `system-tune.sh` detecta el procesador (Intel/AMD), la gráfica (Intel/AMD; con NVIDIA avisa y el driver lo eliges tú) y el chip WiFi, y aplica solo lo que corresponde |
| **Pantalla** | los widgets se ubican en el monitor principal |

## Instalación

```bash
sudo pacman -S --needed gnome                    # si todavía no tienes GNOME
git clone https://github.com/MaximoSDonza/dotfiles.git ~/dotfiles
cd ~/dotfiles

sudo pacman -S --needed - < packages/base.txt    # lo que necesita el tema
yay -S --needed - < packages/aur-base.txt
./install.sh

# Opcional: ajustes de sistema según tu hardware (ver abajo)
echo 'WIFI_REGDOM="AR"' >> ~/.config/cybersigil/local.sh   # código de tu país, para el WiFi
sudo bash ~/.config/cybersigil/system-tune.sh

# Opcional: mis aplicaciones
sudo pacman -S --needed - < packages/apps.txt
yay -S --needed - < packages/aur-apps.txt
```

Cierra sesión y vuelve a entrar. Los archivos que ya existían se mueven a `~/.dotfiles-backup/`
(también los que reemplaza `cybersigil-apply`, como un `starship.toml` propio).

## Paquetes

| Lista | Contenido | Se mantiene |
|---|---|---|
| `base.txt` / `aur-base.txt` | lo que necesita el tema: kitty, starship, fzf, btop, fuentes, iconos, cursor… | a mano |
| `apps.txt` / `aur-apps.txt` | mis aplicaciones (Brave, VS Code, Docker, Steam…). Opcionales | solas, con `backup.sh` |
| `exclude.txt` | lo que nunca entra en las listas de apps: kernel, firmware, drivers (los pone `system-tune.sh` según el equipo) y restos de KDE/Hyprland | a mano |
| `gnome-extensions.txt` | extensiones que descarga `install.sh` | solas, con `backup.sh` |

## Desinstalación

```bash
~/dotfiles/uninstall.sh
sudo bash ~/dotfiles/home/.config/cybersigil/system-tune.sh --revert   # si ejecutaste system-tune.sh
```

`uninstall.sh` quita los enlaces y restaura los archivos que había antes, borra lo que generó el tema,
desactiva las extensiones, devuelve GNOME a sus valores por defecto y reactiva los servicios que se habían
apagado. Antes guarda tus ajustes de GNOME en `~/.dotfiles-backup/antes-de-desinstalar-*/dconf.ini`.
No desinstala paquetes.

## Ajustes de sistema (`system-tune.sh`)

Detecta el hardware y aplica solo lo que corresponde a cada equipo:

| Ajuste | Cuándo |
|---|---|
| Región WiFi (canales y potencia legales del país) | si `WIFI_REGDOM` está en `~/.config/cybersigil/local.sh` |
| Sin ahorro de energía del WiFi ni ASPM (evita pérdida de paquetes) | chips MediaTek `mt7921e` (MT7921/7922/7902) o `mt7925e` |
| `intel-ucode` + `thermald` (control térmico) / `amd-ucode` | según el procesador |
| `intel-media-driver` + `vulkan-intel` / `vulkan-radeon` | según la gráfica (NVIDIA: solo avisa) |
| TCP BBR + fq, zram = RAM/2 con sus parámetros de memoria, `rtkit`, limpieza semanal de la caché de pacman | siempre |
| GDM como gestor de inicio de sesión (necesario para bloquear con Super+L) | si usas otro |

Antes de modificar un archivo de `/etc` guarda el original en `/var/lib/cybersigil/`, y anota lo que crea o
activa. Se puede ejecutar varias veces, y `sudo bash system-tune.sh --revert` deja todo como estaba
(no desinstala paquetes).

## Atajos

| Atajo | Acción |
|---|---|
| `Super + L` | bloquear |
| `Ctrl + Alt + T` | abrir kitty |
| `Super + ←/→/↑/↓` | mover ventana entre tiles |
| `Super + Ctrl + flechas` | cambiar el foco entre ventanas |
| `Ctrl + R` | buscar en el historial (fzf) |
| `Ctrl + T` | buscar archivos (fzf) |
| `Alt + C` | saltar a una carpeta (fzf) |

## SSH en kitty

En kitty, `ssh` es `kitten ssh`: la primera vez copia al servidor la definición de la terminal
(`xterm-kitty`), así nano, htop y clear funcionan con todos los colores. Para equipos sin shell
(routers, switches) usar `ssh-plain`, que conecta como `xterm-256color`.

## Herramientas

- `cybersigil-apply`: regenera el tema desde `palette.sh`
- `suspend-drain`: suspende la laptop y mide cuánta batería gasta por hora
- `jetbrains-update-check`: JetBrains Toolbox no arranca con la sesión (~500 MB y CPU en segundo plano);
  este script, con su temporizador de systemd, avisa una vez por versión cuando hay una actualización de
  un IDE, con un botón para abrir Toolbox. Los IDEs se abren directo, sin Toolbox

## Privacidad

Lo privado de cada máquina queda fuera del repo: `~/.config/cybersigil/local.sh` (ciudad y región WiFi), `~/.bashrc.local`
(variables secretas) y `~/.npmrc` (token de npm). Un hook de git (`.githooks/pre-commit`) frena commits
con tokens, claves o esos archivos.


Telemetría desactivada en VS Code, Firefox y CLIs de desarrollo (`gh`, Next.js, Astro, Angular, Turbo, Prisma...): ver [`90-no-telemetry.conf`](home/.config/environment.d/90-no-telemetry.conf).

## Mantener el respaldo

`backup.sh` actualiza los ajustes de GNOME y las listas de aplicaciones antes de cada commit:

```bash
cd ~/dotfiles && ./backup.sh && git add -A && git commit -m "update" && git push
```

## Licencia

[MIT](LICENSE): puedes usar, modificar y redistribuir estos dotfiles, manteniendo el aviso de copyright.
Excepciones: las fuentes de `fonts/` tienen su propia licencia [OFL](https://openfontlicense.org)
(Space Grotesk, UnifrakturMaguntia; texto en `fonts/`), y las extensiones que descarga `install.sh`
tienen las de sus autores.

Extensiones de terceros: [extensions.gnome.org](https://extensions.gnome.org).
