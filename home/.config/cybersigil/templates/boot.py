#!/usr/bin/env python3
"""Cybersigil — temas de arranque: menú de GRUB, animación de Plymouth y el logo que muestra cada
imagen unificada del kernel (UKI) al arrancar, desde palette.sh.
Uso: boot.py CARPETA [LOGO.svg] (lo llama cybersigil-apply con la paleta en el entorno). Escribe
CARPETA/grub, CARPETA/plymouth y CARPETA/uki-splash.bmp (este solo si recibe el logo); los instala
sudo bash boot-theme.sh. Sin grub-mkfont arma solo lo de Plymouth y el logo."""
import math
import os
import re
import shutil
import struct
import subprocess
import sys

import cairo
import gi

gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
gi.require_version("Rsvg", "2.0")
from gi.repository import Pango, PangoCairo, Rsvg  # noqa: E402

WALLPAPER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wallpaper.py")
C = {k: os.environ[k] for k in ("BG", "BG_ALT", "SURFACE", "TEXT", "CHROME", "CHROME_DIM",
                                "CHROME_HI", "ACCENT", "ACCENT_HI", "ACCENT_SOFT")}
W, H = 1920, 1080   # el fondo de GRUB; en otras resoluciones GRUB lo estira
K = 0.26            # tamaño del sigilo en Plymouth respecto del fondo de pantalla (1728 px de alto)
MONO = "JetBrainsMono Nerd Font"
TITULO = "Bootmenu"
PLY_DIR = "/usr/share/plymouth/themes/cybersigil"   # donde lo instala boot-theme.sh

# GRUB: menú centrado (los mismos números van a theme.txt). Entran 7 entradas (los kernels, la
# configuración UEFI y otros sistemas); si hay más, aparece una barra de desplazamiento roja
MENU = dict(ancho=680, filas=7, arriba=0.34, relleno=16, item=44, separacion=6, sangria=18)
MENU["alto"] = 2 + 1 + 2 * MENU["relleno"] + MENU["filas"] * MENU["item"] + (MENU["filas"] - 1) * MENU["separacion"]

# Cajas de GRUB (styled box): pieza -> (ancho, alto, color). Las que faltan no se dibujan
CAJAS = {
    # panel oscuro con borde cromado tenue y la línea roja arriba, como los widgets
    "menu": {"c": (8, 8, ("BG_ALT", 0.82)), "n": (8, 2, ("ACCENT_HI", 1)),
             "nw": (1, 2, ("ACCENT_HI", 1)), "ne": (1, 2, ("ACCENT_HI", 1)),
             "w": (1, 8, ("CHROME_DIM", 0.8)), "e": (1, 8, ("CHROME_DIM", 0.8)),
             "s": (8, 1, ("CHROME_DIM", 0.8)), "sw": (1, 1, ("CHROME_DIM", 0.8)),
             "se": (1, 1, ("CHROME_DIM", 0.8))},
    # entrada elegida: velo rojo con una barra roja a la izquierda
    "select": {"c": (8, 8, ("ACCENT", 0.32)), "w": (3, 8, ("ACCENT_HI", 1))},
    # barra de desplazamiento (solo si hay más entradas de las que entran)
    "scroll_frame": {"c": (3, 8, ("CHROME_DIM", 0.5))},
    "scroll_thumb": {"c": (3, 8, ("ACCENT_HI", 1))},
    # cuenta regresiva: pista tenue que se llena de rojo
    "barra": {"c": (4, 2, ("CHROME_DIM", 0.6))},
    "avance": {"c": (4, 2, ("ACCENT_HI", 1))},
    # consola de GRUB (tecla c)
    "terminal": {"c": (8, 8, ("BG", 1))},
}

# recorte del sigilo dentro del fondo de 2400×1728 (incluye los anillos) y tamaño del resplandor
SIG_X, SIG_Y, SIG_W, SIG_H = 90, 54, 2220, 1620
BRILLO_RX, BRILLO_RY = 640, 780


def rgb(nombre, a=1.0):
    h = C[nombre]
    return int(h[1:3], 16) / 255, int(h[3:5], 16) / 255, int(h[5:7], 16) / 255, a


def sistema():
    """Nombre del sistema para las leyendas (ARCH LINUX)."""
    try:
        for linea in open("/etc/os-release"):
            if linea.startswith("NAME="):
                return linea.split("=", 1)[1].strip().strip('"').upper()
    except OSError:
        pass
    return "LINUX"


def svg_fondo(w, h, solo_sigilo=False):
    """El fondo de pantalla de cybersigil-apply. solo_sigilo lo deja sin fondo, viñeta ni resplandor."""
    s = subprocess.run([sys.executable, "-I", WALLPAPER, str(w), str(h)], capture_output=True,
                       text=True, check=True).stdout
    if solo_sigilo:
        s = re.sub(r'\s*<rect width="100%" height="100%"[^>]*/>', "", s)
        s = re.sub(r"\s*<ellipse[^>]*/>", "", s)
    return s


def dibujar_svg(cr, svg, x, y, w, h):
    vp = Rsvg.Rectangle()
    vp.x, vp.y, vp.width, vp.height = x, y, w, h
    Rsvg.Handle.new_from_data(svg.encode()).render_document(cr, vp)


def capa(cr, txt, fuente, espaciado=0, suave=True):
    """Texto listo para dibujar. suave=False imita a GRUB, que dibuja las letras sin suavizado."""
    c = PangoCairo.create_layout(cr)
    c.set_font_description(Pango.FontDescription.from_string(fuente))
    c.set_text(txt, -1)
    if espaciado:
        attrs = Pango.AttrList()
        attrs.insert(Pango.attr_letter_spacing_new(int(espaciado * Pango.SCALE)))
        c.set_attributes(attrs)
    fo = cairo.FontOptions()
    fo.set_antialias(cairo.ANTIALIAS_GRAY if suave else cairo.ANTIALIAS_NONE)
    fo.set_hint_style(cairo.HINT_STYLE_SLIGHT if suave else cairo.HINT_STYLE_FULL)
    PangoCairo.context_set_font_options(c.get_context(), fo)
    c.context_changed()
    return c


def texto(cr, txt, fuente, color, x, y, centro=False, **kw):
    """Escribe txt con su borde superior en y (centro=True: x es el centro). Devuelve (ancho, alto)."""
    c = capa(cr, txt, fuente, **kw)
    _, log = c.get_pixel_extents()
    cr.set_source_rgba(*color)
    cr.move_to(round(x - log.width / 2 if centro else x), round(y))
    PangoCairo.show_layout(cr, c)
    return log.width, log.height


def png_liso(ruta, w, h, color):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    cr = cairo.Context(s)
    cr.set_source_rgba(*color)
    cr.paint()
    s.write_to_png(ruta)


def nombre_pf2(ruta):
    """Nombre interno de una fuente de GRUB (theme.txt la pide por ese nombre)."""
    datos = open(ruta, "rb").read(512)
    i = 0
    while i + 8 <= len(datos):
        seccion, largo = datos[i:i + 4], struct.unpack(">I", datos[i + 4:i + 8])[0]
        if seccion == b"NAME":
            return datos[i + 8:i + 8 + largo].rstrip(b"\0").decode()
        i += 8 + largo
    raise SystemExit(f"{ruta}: no es una fuente de GRUB")


def cromado(y0, y1):
    """Degradé metálico vertical, el mismo del sigilo."""
    g = cairo.LinearGradient(0, y0, 0, y1)
    for pos, nombre in ((0, "CHROME_HI"), (0.42, "CHROME"), (0.55, "CHROME_DIM"), (0.66, "CHROME_HI"), (1, "CHROME")):
        g.add_color_stop_rgba(pos, *rgb(nombre))
    return g


def ornamento(cr, cx, y, largo=170):
    """──────── ⸸ ──────── como en los widgets."""
    cr.set_source_rgba(*rgb("CHROME_DIM"))
    cr.set_line_width(1)
    for x0, x1 in ((cx - largo, cx - 22), (cx + 22, cx + largo)):
        cr.move_to(x0, y + 0.5)
        cr.line_to(x1, y + 0.5)
    cr.stroke()
    c = capa(cr, "⸸", "Space Grotesk 26px")
    _, log = c.get_pixel_extents()
    cr.set_source_rgba(*rgb("ACCENT_HI"))
    cr.move_to(round(cx - log.width / 2), round(y - log.height / 2 - 3))
    PangoCairo.show_layout(cr, c)


# ───────────────────────────── GRUB ─────────────────────────────

def grub_fondo(dest):
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, W, H)
    cr = cairo.Context(s)
    cr.set_source_rgba(*rgb("BG"))
    cr.paint()
    # el fondo de pantalla, oscurecido para que el menú se lea encima
    cr.push_group()
    dibujar_svg(cr, svg_fondo(W, H), 0, 0, W, H)
    cr.pop_group_to_source()
    cr.paint_with_alpha(0.30)
    # título gótico cromado con resplandor rojo y la leyenda debajo, como los widgets
    # (van en la imagen: GRUB dibuja las letras sin suavizado)
    c = capa(cr, TITULO, "UnifrakturMaguntia 104px")
    _, log = c.get_pixel_extents()
    x, y = (W - log.width) / 2, 128
    cr.move_to(x, y)
    PangoCairo.layout_path(cr, c)
    trazo = cr.copy_path()
    cr.set_line_join(cairo.LINE_JOIN_ROUND)
    for ancho, a in ((28, 0.04), (18, 0.07), (9, 0.12)):
        cr.new_path()
        cr.append_path(trazo)
        cr.set_source_rgba(*rgb("ACCENT_HI", a))
        cr.set_line_width(ancho)
        cr.stroke()
    cr.new_path()
    cr.append_path(trazo)
    cr.set_source(cromado(y + log.height * 0.2, y + log.height * 0.85))
    cr.fill()
    ornamento(cr, W / 2, y + log.height + 14)
    texto(cr, sistema(), "Space Grotesk 14px", rgb("CHROME"), W / 2, y + log.height + 40, centro=True, espaciado=7)
    s.write_to_png(os.path.join(dest, "background.png"))


def grub_tema(dest):
    fuente = subprocess.run(["fc-match", "-f", "%{file}", f"{MONO}:style=Regular"],
                            capture_output=True, text=True, check=True).stdout
    # solo latín + flechas y viñetas, para que las fuentes pesen poco
    rango = "0x20-0x7e,0xa0-0x17f,0x2190-0x2193,0x2022-0x2022,0x2e38-0x2e38"
    for t in (16, 22):
        subprocess.run(["grub-mkfont", "-n", "Cybersigil Mono", "-s", str(t), "-r", rango,
                        "-o", os.path.join(dest, f"mono-{t}.pf2"), fuente], check=True, capture_output=True)
    for nombre, piezas in CAJAS.items():
        for pieza, (w, h, (col, a)) in piezas.items():
            png_liso(os.path.join(dest, f"{nombre}_{pieza}.png"), w, h, rgb(col, a))
    f16, f22 = (nombre_pf2(os.path.join(dest, f"mono-{t}.pf2")) for t in (16, 22))
    m = MENU
    arriba = f"{round(m['arriba'] * 100)}%"
    debajo = m["alto"] + 24
    tema = f"""# Cybersigil — tema de GRUB generado por cybersigil-apply desde palette.sh (lo instala boot-theme.sh)
# El título, el sigilo y el ornamento están dibujados en background.png
title-text: ""
desktop-image: "background.png"
desktop-image-scale-method: "stretch"
desktop-color: "{C['BG']}"
terminal-font: "{f16}"
terminal-box: "terminal_*.png"
terminal-left: "8%"
terminal-top: "8%"
terminal-width: "84%"
terminal-height: "84%"
terminal-border: "0"

+ boot_menu {{
  left = 50%-{m['ancho'] // 2}
  top = {arriba}
  width = {m['ancho']}
  height = {m['alto']}
  item_font = "{f22}"
  item_color = "{C['CHROME']}"
  selected_item_color = "{C['CHROME_HI']}"
  item_height = {m['item']}
  item_padding = {m['relleno']}
  item_spacing = {m['separacion']}
  icon_width = 0
  icon_height = 0
  item_icon_space = {m['sangria']}
  menu_pixmap_style = "menu_*.png"
  selected_item_pixmap_style = "select_*.png"
  scrollbar = true
  scrollbar_width = 3
  scrollbar_frame = "scroll_frame_*.png"
  scrollbar_thumb = "scroll_thumb_*.png"
}}

# cuenta regresiva: una línea que se llena de rojo y el texto con los segundos
+ progress_bar {{
  id = "__timeout__"
  left = 50%-{m['ancho'] // 2}
  top = {arriba}+{debajo}
  width = {m['ancho']}
  height = 2
  bar_style = "barra_*.png"
  highlight_style = "avance_*.png"
}}
+ label {{
  id = "__timeout__"
  left = 0
  top = {arriba}+{debajo + 18}
  width = 100%
  height = 24
  align = "center"
  font = "{f16}"
  color = "{C['ACCENT_SOFT']}"
  text = "arranque automático en %d s"
}}

+ label {{
  left = 0
  top = 100%-64
  width = 100%
  height = 24
  align = "center"
  font = "{f16}"
  color = "{C['CHROME']}"
  text = "↑ ↓ elegir   ·   enter arrancar   ·   e editar   ·   c consola"
}}
"""
    open(os.path.join(dest, "theme.txt"), "w").write(tema)


# ─────────────────────────── Plymouth ───────────────────────────

def ply_imagenes(dest):
    sw, sh = round(SIG_W * K), round(SIG_H * K)
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, sw, sh)
    cr = cairo.Context(s)
    dibujar_svg(cr, svg_fondo(2400, 1728, solo_sigilo=True), -SIG_X * K, -SIG_Y * K, 2400 * K, 1728 * K)
    s.write_to_png(os.path.join(dest, "sigilo.png"))

    # resplandor rojo que late detrás del sigilo
    rx, ry = round(BRILLO_RX * K), round(BRILLO_RY * K)
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 2 * rx, 2 * ry)
    cr = cairo.Context(s)
    cr.translate(rx, ry)
    cr.scale(1, ry / rx)
    g = cairo.RadialGradient(0, 0, 0, 0, 0, rx)
    g.add_color_stop_rgba(0, *rgb("ACCENT_HI", 0.65))
    g.add_color_stop_rgba(0.4, *rgb("ACCENT", 0.22))
    g.add_color_stop_rgba(1, *rgb("ACCENT", 0))
    cr.set_source(g)
    cr.arc(0, 0, rx, 0, 2 * math.pi)
    cr.fill()
    s.write_to_png(os.path.join(dest, "brillo.png"))

    # leyenda (va como imagen: así no depende de las fuentes que haya en el initramfs)
    nombre = sistema()
    medida = cairo.Context(cairo.ImageSurface(cairo.FORMAT_ARGB32, 1, 1))
    _, log = capa(medida, nombre, "Space Grotesk 15px", espaciado=8).get_pixel_extents()
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, log.width + 4, log.height + 4)
    texto(cairo.Context(s), nombre, "Space Grotesk 15px", rgb("CHROME"), 2, 2, espaciado=8)
    s.write_to_png(os.path.join(dest, "texto.png"))

    png_liso(os.path.join(dest, "linea.png"), 1, 1, rgb("CHROME_DIM"))
    png_liso(os.path.join(dest, "relleno.png"), 1, 1, rgb("ACCENT_HI"))
    # rombo de la clave (si el disco está cifrado)
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 12, 12)
    cr = cairo.Context(s)
    cr.move_to(6, 0)
    cr.line_to(12, 6)
    cr.line_to(6, 12)
    cr.line_to(0, 6)
    cr.close_path()
    cr.set_source_rgba(*rgb("CHROME_HI"))
    cr.fill()
    s.write_to_png(os.path.join(dest, "punto.png"))


def ply_tema(dest):
    tr, tg, tb, _ = rgb("TEXT")
    open(os.path.join(dest, "cybersigil.plymouth"), "w").write(f"""[Plymouth Theme]
Name=Cybersigil
Description=Sigilo cromado con un pulso rojo
ModuleName=script

[script]
ImageDir={PLY_DIR}
ScriptFile={PLY_DIR}/cybersigil.script
""")
    open(os.path.join(dest, "cybersigil.script"), "w").write(f"""# Cybersigil — tema de Plymouth generado por cybersigil-apply desde palette.sh
# Fondo negro, el sigilo del fondo de pantalla con un resplandor rojo que late detrás
# y una línea de progreso fina debajo.

Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

ancho = Window.GetWidth();
alto = Window.GetHeight();
escala = alto / 1080;
centro.x = Window.GetX() + ancho / 2;

fun escalar(imagen) {{
  return imagen.Scale(Math.Int(imagen.GetWidth() * escala), Math.Int(imagen.GetHeight() * escala));
}}

sigilo.imagen = escalar(Image("sigilo.png"));
sigilo.sprite = Sprite(sigilo.imagen);
sigilo.y = Window.GetY() + alto / 2 - sigilo.imagen.GetHeight() / 2 - 60 * escala;
sigilo.sprite.SetPosition(centro.x - sigilo.imagen.GetWidth() / 2, sigilo.y, 2);
centro.y = sigilo.y + sigilo.imagen.GetHeight() / 2;

brillo.imagen = escalar(Image("brillo.png"));
brillo.sprite = Sprite(brillo.imagen);
brillo.sprite.SetPosition(centro.x - brillo.imagen.GetWidth() / 2, centro.y - brillo.imagen.GetHeight() / 2, 1);

# línea de progreso: pista de 1 px y avance rojo de 3 px
barra.ancho = Math.Int(360 * escala);
barra.x = centro.x - barra.ancho / 2;
barra.y = sigilo.y + sigilo.imagen.GetHeight() + 56 * escala;
pista = Sprite(Image("linea.png").Scale(barra.ancho, 1));
pista.SetPosition(barra.x, barra.y, 3);
avance.imagen = Image("relleno.png");
avance.sprite = Sprite();
avance.sprite.SetPosition(barra.x, barra.y - 1, 4);

leyenda.imagen = escalar(Image("texto.png"));
leyenda.sprite = Sprite(leyenda.imagen);
leyenda.y = barra.y + 28 * escala;
leyenda.sprite.SetPosition(centro.x - leyenda.imagen.GetWidth() / 2, leyenda.y, 3);

# al apagar o reiniciar no hay progreso que mostrar
modo = Plymouth.GetMode();
if (modo == "shutdown" || modo == "reboot") {{
  pista.SetOpacity(0);
}}

# el pulso: el resplandor sube y baja (50 cuadros por segundo, un latido cada 2,4 s)
cuadro = 0;
fun refrescar() {{
  cuadro++;
  pulso = (Math.Sin(cuadro * Math.Pi / 60) + 1) / 2;
  brillo.sprite.SetOpacity(0.3 + 0.7 * pulso);
}}
Plymouth.SetRefreshFunction(refrescar);

fun progreso(duracion, avanzado) {{
  largo = Math.Int(barra.ancho * avanzado);
  if (largo > 0) {{
    avance.sprite.SetImage(avance.imagen.Scale(largo, 3));
  }}
}}
Plymouth.SetBootProgressFunction(progreso);

# clave del disco (solo aparece si está cifrado)
punto.imagen = escalar(Image("punto.png"));
paso = punto.imagen.GetWidth() * 2;
pregunta = Sprite();
i = 0;
while (i < 24) {{
  puntos[i] = Sprite(punto.imagen);
  puntos[i].SetOpacity(0);
  i++;
}}

fun mostrar_clave(texto, cantidad) {{
  imagen = Image.Text(texto, {tr:.3f}, {tg:.3f}, {tb:.3f});
  pregunta.SetImage(imagen);
  pregunta.SetPosition(centro.x - imagen.GetWidth() / 2, leyenda.y + 44 * escala, 5);
  pregunta.SetOpacity(1);
  visibles = Math.Min(cantidad, 24);
  inicio = centro.x - visibles * paso / 2;
  j = 0;
  while (j < 24) {{
    puntos[j].SetPosition(inicio + j * paso, leyenda.y + 76 * escala, 5);
    if (j < visibles) {{
      puntos[j].SetOpacity(1);
    }} else {{
      puntos[j].SetOpacity(0);
    }}
    j++;
  }}
}}
Plymouth.SetDisplayPasswordFunction(mostrar_clave);

fun modo_normal() {{
  pregunta.SetOpacity(0);
  j = 0;
  while (j < 24) {{
    puntos[j].SetOpacity(0);
    j++;
  }}
}}
Plymouth.SetDisplayNormalFunction(modo_normal);

# mensajes del sistema (por ejemplo, la revisión del disco)
mensaje = Sprite();
fun mostrar_mensaje(texto) {{
  imagen = Image.Text(texto, {tr:.3f}, {tg:.3f}, {tb:.3f});
  mensaje.SetImage(imagen);
  mensaje.SetPosition(centro.x - imagen.GetWidth() / 2, Window.GetY() + alto - 60 * escala, 5);
}}
Plymouth.SetMessageFunction(mostrar_mensaje);
""")


# ───────────────────────── logo de la UKI ─────────────────────────

SPLASH_ANCHO = 566   # el mismo ancho que el logo de Arch que traen las UKI (splash-arch.bmp)


def bmp24(ruta, s):
    """Guarda una superficie RGB24 de cairo como BMP de 24 bits sin compresión: el formato más simple
    que entiende el arranque de la UKI (systemd-stub)."""
    s.flush()
    w, h, stride, datos = s.get_width(), s.get_height(), s.get_stride(), bytes(s.get_data())
    relleno = b"\0" * ((4 - w * 3 % 4) % 4)   # cada fila ocupa un múltiplo de 4 bytes
    filas = []
    for y in range(h - 1, -1, -1):           # en BMP la primera fila es la de abajo
        linea = datos[y * stride:y * stride + w * 4]   # cairo: azul, verde, rojo, (sin uso)
        filas.append(b"".join(linea[i:i + 3] for i in range(0, w * 4, 4)) + relleno)
    cuerpo = b"".join(filas)
    cabecera = struct.pack("<2sIHHI", b"BM", 14 + 40 + len(cuerpo), 0, 0, 14 + 40)
    dib = struct.pack("<IiiHHIIiiII", 40, w, h, 1, 24, 0, len(cuerpo), 2835, 2835, 0, 0)
    open(ruta, "wb").write(cabecera + dib + cuerpo)


def uki_splash(dest, logo):
    """El logo de la distribución (ya con los colores de la paleta) sobre el fondo, como BMP."""
    svg = open(logo).read()
    caja = re.search(r'viewBox="\s*[-\d.]+[\s,]+[-\d.]+[\s,]+([\d.]+)[\s,]+([\d.]+)', svg)
    proporcion = float(caja.group(2)) / float(caja.group(1)) if caja else 1 / 3
    w, h = SPLASH_ANCHO, round(SPLASH_ANCHO * proporcion)
    s = cairo.ImageSurface(cairo.FORMAT_RGB24, w, h)
    cr = cairo.Context(s)
    cr.set_source_rgba(*rgb("BG"))
    cr.paint()
    dibujar_svg(cr, svg, 0, 0, w, h)
    bmp24(os.path.join(dest, "uki-splash.bmp"), s)


def generar(salida, logo=None):
    ply = os.path.join(salida, "plymouth")
    os.makedirs(ply, exist_ok=True)
    ply_imagenes(ply)
    ply_tema(ply)
    if logo and os.path.exists(logo):
        uki_splash(salida, logo)
    if shutil.which("grub-mkfont"):
        grub = os.path.join(salida, "grub")
        os.makedirs(grub, exist_ok=True)
        grub_fondo(grub)
        grub_tema(grub)


if __name__ == "__main__":
    generar(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
