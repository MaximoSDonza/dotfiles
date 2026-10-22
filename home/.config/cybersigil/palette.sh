# Paleta cibersigilista — edita estos valores y ejecuta: cybersigil-apply
BG="#000000"          # fondo base
BG_ALT="#0b0b0c"      # fondo secundario
SURFACE="#141416"     # menús, tarjetas, diálogos
SURFACE_HI="#1e1e22"  # hover / elementos elevados
TEXT="#d8d8dc"        # texto principal
CHROME="#9a9aa2"      # bordes y líneas cromadas
CHROME_DIM="#4a4a50"  # bordes sutiles
CHROME_HI="#f0f0f4"   # brillo del cromo
ACCENT="#8b0a14"      # rojo sangre
ACCENT_HI="#b3121f"   # rojo sangre activo

# Código (VS Code, IntelliJ). Todos con contraste ≥ 4,5:1 sobre el fondo, para leer cómodo
ACCENT_SOFT="#e0485e"   # rojo legible como texto: palabras clave (ACCENT_HI da 3:1, no alcanza)
SYN_STRING="#b4b9b2"    # textos entre comillas
SYN_NUMBER="#cfc6b8"    # números y constantes
SYN_TYPE="#a7b0bb"      # clases y tipos
SYN_PROPERTY="#b8a6b4"  # propiedades y atributos
SYN_COMMENT="#7a7a84"   # comentarios

# Cristal oscuro: fondos de menús sobre el blur (Blur my Shell). Último valor = opacidad
GLASS="rgba(8, 8, 10, 0.55)"         # menús, calendario, ajustes rápidos
GLASS_CARD="rgba(30, 30, 34, 0.50)"  # tarjetas dentro de los menús
GLASS_HOVER="rgba(@@CHROME_RGB@@, 0.14)"  # @@X_RGB@@ = ese color de esta paleta
BLUR_SIGMA=30          # intensidad del blur
BLUR_BRIGHTNESS=0.45   # 0 = negro, 1 = sin oscurecer

# Tipografía
FONT_UI="Space Grotesk 11"
FONT_MONO="JetBrainsMono Nerd Font 11"
FONT_SIGIL="UnifrakturMaguntia"   # reloj y títulos góticos

# Widgets de escritorio (extensión Cybersigil Widgets)
WIDGETS="clock system weather network music"   # cuáles mostrar; quitar uno lo oculta
WIDGET_ALPHA=0.38                 # opacidad del cristal: 0 = invisible, 1 = negro sólido
WIDGET_BLUR=24                    # desenfoque del fondo detrás de los widgets
# Posición: top-left, top-right, top-center, bottom-left, bottom-right, bottom-center.
# Los que comparten posición se apilan en el orden de WIDGETS y toman el mismo ancho.
WIDGET_CLOCK_ANCHOR="top-left"
WIDGET_SYSTEM_ANCHOR="top-left"
WIDGET_WEATHER_ANCHOR="top-right"
WIDGET_NETWORK_ANCHOR="top-right"
WIDGET_MUSIC_ANCHOR="bottom-left" # solo aparece cuando suena algo (Spotify, YouTube...)
WIDGET_MARGIN=48                  # distancia al borde de la pantalla (px)
WIDGET_GAP=18                     # separación entre widgets apilados (px)
# Ciudad del clima. La tuya ponla en ~/.config/cybersigil/local.sh (no se sube al repo)
WEATHER_CITY="Buenos Aires"
WEATHER_REGION="Argentina"
WEATHER_LAT=-34.6037              # coordenadas: https://open-meteo.com/en/docs/geocoding-api
WEATHER_LON=-58.3816

# Imagen de fondo de kitty (se ve también en neovim) e IntelliJ, tenue sobre el negro.
# Vacía = sin imagen. La tuya ponla en local.sh, por ejemplo:
#   APPS_BG_IMAGE="$HOME/.local/share/cybersigil/mi-imagen.jpg"
APPS_BG_IMAGE=""
APPS_BG_ALPHA=0.16                # cuánto se ve la imagen (0–1): poco, para leer el texto encima
APPS_OPACITY=0.85                 # transparencia de la ventana de kitty (1 = opaca)
