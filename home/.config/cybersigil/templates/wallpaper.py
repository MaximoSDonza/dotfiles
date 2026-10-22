#!/usr/bin/env python3
"""Genera el fondo cibersigilista (SVG simétrico). Uso: wallpaper.py ANCHO ALTO > out.svg
Los colores vienen de variables de entorno (palette.sh)."""
import math
import os
import sys

W, H = (int(a) for a in sys.argv[1:3]) if len(sys.argv) >= 3 else (3072, 1728)
C = {k: os.environ.get(k, d) for k, d in {
    "BG": "#000000", "CHROME": "#9a9aa2", "CHROME_DIM": "#4a4a50",
    "CHROME_HI": "#f0f0f4", "ACCENT": "#8b0a14", "ACCENT_HI": "#b3121f"}.items()}
U = H / 1728  # unidad relativa a la altura


def thorn(bx, by, ang, length, bend, width, n=40, taper=1.15):
    """Espina curva que se afila hasta la punta. ang en grados, bend = curvatura lateral."""
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    left, right = [], []
    for i in range(n + 1):
        s = i / n
        px = bx + length * s * dx + bend * length * s * s * nx
        py = by + length * s * dy + bend * length * s * s * ny
        # normal local de la curva
        tx = dx + 2 * bend * s * nx
        ty = dy + 2 * bend * s * ny
        tl = math.hypot(tx, ty)
        lx, ly = -ty / tl, tx / tl
        w = width * (1 - s) ** taper
        left.append((px + lx * w, py + ly * w))
        right.append((px - lx * w, py - ly * w))
    pts = left + right[::-1]
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + "Z"


def half():
    """Mitad derecha del sigilo, coordenadas relativas al centro."""
    p = []
    # espina central (estrella alargada)
    p.append(f"M0,{-760*U:.1f} Q{10*U:.1f},{-90*U:.1f} {120*U:.1f},0 Q{10*U:.1f},{90*U:.1f} 0,{760*U:.1f} Z")
    # alas principales: barridas hacia afuera, puntas que se enroscan
    wings = [  # by, ang, len, bend, width
        (-60, -28, 820, -0.32, 26), (60, 28, 820, 0.32, 26),
        (-200, -62, 640, -0.45, 18), (200, 62, 640, 0.45, 18),
        (-20, -8, 1080, 0.18, 14), (20, 8, 1080, -0.18, 14),
        (-380, -82, 420, 0.55, 12), (380, 82, 420, -0.55, 12),
    ]
    for by, ang, ln, bend, wd in wings:
        p.append(thorn(12 * U, by * U, ang, ln * U, bend, wd * U))
        # púas secundarias a lo largo de cada ala
        a = math.radians(ang)
        for s, off, sl, sb in ((0.38, 50, 0.34, 0.5), (0.62, 38, 0.22, 0.6)):
            sx = 12 * U + ln * U * s * math.cos(a) - bend * ln * U * s * s * math.sin(a)
            sy = by * U + ln * U * s * math.sin(a) + bend * ln * U * s * s * math.cos(a)
            sign = -1 if ang < 0 else 1
            p.append(thorn(sx, sy, ang + sign * off, ln * U * sl, sign * sb, wd * U * 0.45))
    # garras inferiores/superiores cerca de la espina
    for sgn in (-1, 1):
        p.append(thorn(4 * U, sgn * 520 * U, sgn * 70, 300 * U, -sgn * 0.7, 9 * U))
        p.append(thorn(4 * U, sgn * 640 * U, sgn * 40, 180 * U, -sgn * 0.9, 6 * U))
    return p


def main():
    cx, cy = W / 2, H / 2
    paths = "\n".join(f'    <path d="{d}"/>' for d in half())
    print(f'''<!-- Cybersigil: fondo generado por cybersigil-apply desde palette.sh -->
<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <linearGradient id="chrome" x1="0" y1="0" x2="0.35" y2="1">
      <stop offset="0" stop-color="{C['CHROME_HI']}"/>
      <stop offset="0.28" stop-color="{C['CHROME']}"/>
      <stop offset="0.5" stop-color="{C['CHROME_DIM']}"/>
      <stop offset="0.62" stop-color="{C['CHROME_HI']}"/>
      <stop offset="1" stop-color="{C['CHROME_DIM']}"/>
    </linearGradient>
    <radialGradient id="glow">
      <stop offset="0" stop-color="{C['ACCENT_HI']}" stop-opacity="0.55"/>
      <stop offset="0.4" stop-color="{C['ACCENT']}" stop-opacity="0.18"/>
      <stop offset="1" stop-color="{C['ACCENT']}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="vignette" cx="0.5" cy="0.5" r="0.75">
      <stop offset="0.55" stop-color="#000" stop-opacity="0"/>
      <stop offset="1" stop-color="#000" stop-opacity="0.85"/>
    </radialGradient>
    <g id="half" fill="url(#chrome)">
{paths}
    </g>
  </defs>
  <rect width="100%" height="100%" fill="{C['BG']}"/>
  <ellipse cx="{cx}" cy="{cy}" rx="{520*U:.0f}" ry="{700*U:.0f}" fill="url(#glow)"/>
  <g fill="none" stroke="{C['CHROME_DIM']}" stroke-width="{1.2*U:.2f}" opacity="0.45">
    <circle cx="{cx}" cy="{cy}" r="{780*U:.0f}"/>
    <circle cx="{cx}" cy="{cy}" r="{800*U:.0f}" stroke-dasharray="{2*U:.1f} {14*U:.1f}"/>
  </g>
  <g transform="translate({cx},{cy})">
    <use href="#half"/>
    <use href="#half" transform="scale(-1,1)"/>
    <path d="M0,{-46*U:.1f} L{14*U:.1f},0 L0,{46*U:.1f} L{-14*U:.1f},0 Z" fill="{C['ACCENT_HI']}"/>
  </g>
  <rect width="100%" height="100%" fill="url(#vignette)"/>
</svg>''')


main()
