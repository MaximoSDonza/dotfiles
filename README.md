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
| **Apps con la paleta** | Brave · VS Code · IntelliJ · inicio de sesión (GDM) |
| **Arranque** | menú de GRUB y animación de Plymouth con el sigilo |

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

La sesión arranca en el escritorio, con los widgets, y no en la vista general. GNOME 51 la abre antes de
cargar las extensiones; si quedaba abierta, lo primero que se escribía en una ventana nueva iba a su buscador.

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
Cambia un color y ejecuta `cybersigil-apply`: se regeneran el tema de GNOME Shell, GTK, kitty, neovim, starship, fastfetch, btop, fzf, el wallpaper (SVG generado por código), los temas de las apps y el del arranque (ver abajo).

## Apps con la paleta

`cybersigil-apply` también arma los temas de estas apps, en `~/.config/cybersigil/generated/`:

| App | Cómo se aplica |
|---|---|
| **Neovim** | solo: `colors/cybersigil.lua`, con los mismos colores de código y sin fondo propio |
| **VS Code** | solo: instala la extensión `cybersigil.cybersigil-theme` y `settings.json` ya la elige |
| **IntelliJ** (y los demás IDE de JetBrains) | se copia sola a cada IDE instalado. Reinicia el IDE y elige *Settings → Appearance & Behavior → Appearance → Theme → Cybersigil*; el esquema del editor cambia con el tema |
| **Brave** | una vez: `brave://extensions` → *Developer mode* → *Load unpacked* → `~/.config/cybersigil/generated/brave-theme`. Si cambias la paleta, recárgala (↻) desde esa página |
| **Páginas web** (opcional) | con la extensión Dark Reader de Brave: los colores para cargarle están en `generated/brave-darkreader.txt` |
| **Inicio de sesión (GDM)** | `sudo bash ~/.config/cybersigil/gdm-theme.sh` (y otra vez si cambias la paleta). Se ve al cerrar sesión; para deshacerlo, `--revert` |

**Imagen de fondo** (opcional): kitty, neovim dentro de kitty (`~/.config/nvim/init.lua` lo deja sin
fondo propio) e IntelliJ muestran una imagen tenue sobre el negro, pegada a la derecha y desvanecida
hacia el texto. Se elige en `local.sh` con `APPS_BG_IMAGE="/ruta/a/la/imagen"`. Cuánto se ve
(`APPS_BG_ALPHA`) y la transparencia de kitty (`APPS_OPACITY`) se cambian en `palette.sh`. IntelliJ toma
el cambio la próxima vez que se ejecute `cybersigil-apply` con el IDE cerrado.

El código usa colores propios de la paleta (`ACCENT_SOFT` y `SYN_*`), todos con un contraste de al menos
4,5:1 sobre el fondo, para leer cómodo.

GDM no se toca: `gdm-theme.sh` instala una extensión del sistema (`gdm/cybersigil-gdm@donza`) que solo
corre en la pantalla de inicio, y la activa en la configuración de GDM (`/etc/dconf`). Así las
actualizaciones de GNOME no la pisan. El logo de la distribución que aparece abajo pasa a los colores
de la paleta (en Arch: el triángulo y "linux" en rojo, "arch" en blanco). Si el logo no es un SVG,
se quita.

Las ventanas GTK y libadwaita tienen esquinas rectas, como la barra y los widgets. Interruptores, casillas
y botones redondos conservan su forma.

## Arranque (GRUB y Plymouth)

| Pantalla | Cómo se ve |
|---|---|
| **GRUB** | "Bootmenu" en gótica cromada sobre el sigilo oscurecido, menú en un panel con la línea roja de los widgets y cuenta regresiva que se llena de rojo |
| **Plymouth** | fondo negro, el sigilo con un resplandor rojo que late, una línea de progreso fina y el nombre del sistema. También pide la clave si el disco está cifrado |
| **Logo del kernel (UKI)** | si los kernels arrancan como imágenes unificadas con logo, el de la distribución en rojo y blanco (en Arch reemplaza al azul), el mismo de GDM |

`cybersigil-apply` los arma en `~/.config/cybersigil/generated/boot/` (solo cuando cambia la paleta).
Para instalarlos o actualizarlos:

```bash
sudo bash ~/.config/cybersigil/boot-theme.sh            # se ve al reiniciar
sudo bash ~/.config/cybersigil/boot-theme.sh --revert   # vuelve al arranque de antes
```

Qué hace, con cuidado porque es el arranque:

- La primera vez guarda `/etc/default/grub`, `/boot/grub/grub.cfg` y el tema de Plymouth en
  `/var/lib/cybersigil-boot/`. `--revert` los devuelve.
- Respeta cómo arranca Linux el equipo:
  - **Kernel + initramfs** (lo común): conserva las opciones del kernel con las que arranca hoy,
    aunque no estén en `/etc/default/grub`, y agrega `splash` para que se vea Plymouth.
  - **Imágenes unificadas (UKI**, como deja archinstall): GRUB las arranca con el comando `uki` y
    las opciones del kernel van dentro de cada imagen, desde `/etc/kernel/cmdline`. No toca esas
    opciones; solo avisa si falta `splash`.
- Arma el `grub.cfg` nuevo aparte y solo reemplaza al actual si es válido (`grub-script-check`), tiene
  el tema y arranca Linux igual que el actual. Si algo falla, deja todo como estaba, dice qué faltó y
  guarda el descartado en `/var/lib/cybersigil-boot/grub.cfg.rechazado`.
- El menú tiene lugar para 7 entradas (kernels, configuración UEFI y otros sistemas); si hay más,
  aparece una barra de desplazamiento.
- Usa la resolución nativa de la pantalla en GRUB y rehace el initramfs (`mkinitcpio -P`) solo si el
  tema de Plymouth cambió.
- El logo de las UKI: cambia solo la ruta de `--splash` en los presets de `/etc/mkinitcpio.d` (los
  guarda antes) y rehace las imágenes una sola vez junto con Plymouth. Una imagen rota no impide
  arrancar: systemd-stub la ignora y sigue.
- Si el equipo no arranca con GRUB, o Plymouth no está en el initramfs (`HOOKS` de
  `/etc/mkinitcpio.conf`), omite esa parte y avisa.

## Estructura

```
home/            → se enlaza tal cual dentro de ~ (misma estructura que $HOME)
  .config/cybersigil/   palette.sh, apply.sh, system-tune.sh, gdm-theme.sh, boot-theme.sh y plantillas
gdm/             → extensión que pinta la pantalla de inicio de sesión (la instala gdm-theme.sh)
firefox/user.js  → Firefox sin telemetría
dconf/           → ajustes de GNOME: tema.ini (siempre) y personal.ini (con --personal)
lib/             → dconf_sync.py: separa, respalda y restaura esos ajustes
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
./install.sh                                     # o ./install.sh --personal (ver "Ajustes de GNOME")

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
| `exclude.txt` | lo que nunca entra en las listas de apps: kernel, firmware, drivers (los pone `system-tune.sh` según el equipo) y otros escritorios (Hyprland, restos de KDE) | a mano |
| `gnome-extensions.txt` | extensiones que descarga `install.sh` | solas, con `backup.sh` |

## Ajustes de GNOME

| `dconf/tema.ini`: se aplica siempre | `dconf/personal.ini`: solo con `./install.sh --personal` |
|---|---|
| ajustes de Blur my Shell, Just Perfection, Tiling Shell y User Themes | favoritos y orden de las apps |
| activar las extensiones del rice, **sumándolas** a las que ya tengas | otras extensiones activadas, relojes mundiales |
| optimizaciones: GNOME Software sin actualizaciones automáticas, indexador sin trabajar a batería, **cierre automático de Xwayland** (libera ~250 MB cuando no hay apps X11 abiertas) | touchpad, tamaño del cursor, proveedores de búsqueda, privacidad |
| | atajos personalizados (Ctrl+Alt+T → kitty) |

Fuentes, iconos, cursor y colores no están en ninguno: los aplica `cybersigil-apply` desde la paleta.
Tampoco se guarda el estado interno de GNOME (historial de Alt+F2, versión de su configuración…).

## Desinstalación

```bash
~/dotfiles/uninstall.sh
sudo bash ~/dotfiles/home/.config/cybersigil/system-tune.sh --revert   # si ejecutaste system-tune.sh
sudo bash ~/dotfiles/home/.config/cybersigil/gdm-theme.sh --revert     # si ejecutaste gdm-theme.sh
sudo bash ~/dotfiles/home/.config/cybersigil/boot-theme.sh --revert    # si ejecutaste boot-theme.sh
```

`uninstall.sh` quita los enlaces y restaura los archivos que había antes, borra lo que generó el tema,
desactiva las extensiones, devuelve a sus valores por defecto los ajustes del tema y reactiva los servicios
que se habían apagado. También quita los temas de VS Code e IntelliJ. El de Brave se quita desde el
navegador (`brave://settings/appearance` → *Reset to default*). Tus ajustes personales quedan como están. Antes guarda tus ajustes de GNOME en `~/.dotfiles-backup/antes-de-desinstalar-*/dconf.ini`.
No desinstala paquetes.

## Ajustes de sistema (`system-tune.sh`)

Detecta el hardware y aplica solo lo que corresponde a cada equipo:

| Ajuste | Cuándo |
|---|---|
| Región WiFi (canales y potencia legales del país) | si `WIFI_REGDOM` está en `~/.config/cybersigil/local.sh` |
| Sin ahorro de energía del WiFi ni ASPM (evita pérdida de paquetes) | chips MediaTek `mt7921e` (MT7921/7922/7902) o `mt7925e` |
| `intel-ucode` + `thermald` (control térmico) / `amd-ucode` | según el procesador |
| `intel-media-driver` + `vulkan-intel` / `vulkan-radeon` | según la gráfica (NVIDIA: solo avisa) |
| Bluetooth apagado al arrancar (BlueZ `AutoEnable=false`); se prende desde el menú de arriba | si hay Bluetooth |
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
