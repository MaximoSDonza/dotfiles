// Piezas compartidas por los widgets: panel de cristal, encabezado, adorno, barras y gráfico.

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export function box(styleClass, vertical = false, props = {}) {
    return new St.BoxLayout({
        style_class: styleClass,
        orientation: vertical ? Clutter.Orientation.VERTICAL : Clutter.Orientation.HORIZONTAL,
        ...props,
    });
}

export function label(styleClass, text = '', props = {}) {
    return new St.Label({style_class: styleClass, text, ...props});
}

// Texto con espaciado entre letras: intercala espacios finos (U+2009). Ni letter-spacing en CSS
// ni el atributo de Pango sirven: St no los cuenta al medir el ancho y el texto queda cortado con "…"
export function setSpaced(lbl, text, thinSpaces) {
    setText(lbl, [...text].join(' '.repeat(thinSpaces)));
}

// Cambia el texto solo si es distinto: asignar el mismo valor también provoca relayout y redibujado
export function setText(lbl, text) {
    if (lbl.text !== text)
        lbl.text = text;
}

export function setClass(actor, styleClass, on) {
    if (actor.has_style_class_name(styleClass) === on)
        return;  // sin cambios: evita recalcular estilos y redibujar
    if (on)
        actor.add_style_class_name(styleClass);
    else
        actor.remove_style_class_name(styleClass);
}

// Panel de cristal: línea roja arriba (de borde a borde) y el contenido debajo
export function panel(styleClass) {
    const outer = box(`csw-panel ${styleClass}`, true);
    outer.add_child(new St.Widget({style_class: 'csw-accent', x_expand: true}));
    const content = box('csw-content', true);
    outer.add_child(content);
    return [outer, content];
}

// ──────── ⸸ ────────
export function ornament() {
    const row = box('csw-ornament');
    const rule = () => new St.Widget({style_class: 'csw-rule', x_expand: true, y_align: Clutter.ActorAlign.CENTER});
    row.add_child(rule());
    row.add_child(label('csw-sigil', '⸸', {y_align: Clutter.ActorAlign.CENTER}));
    row.add_child(rule());
    return row;
}

// Título gótico a la izquierda y un rótulo chico a la derecha; devuelve [fila, rótulo]
export function header(title) {
    const row = box('csw-header');
    row.add_child(label('csw-title', title, {y_align: Clutter.ActorAlign.END}));
    const caption = label('csw-caption', '', {x_expand: true, x_align: Clutter.ActorAlign.END, y_align: Clutter.ActorAlign.END});
    row.add_child(caption);
    return [row, caption];
}

// Barra horizontal. El relleno ocupa todo el ancho y se achica con scale_x, así cambiar
// el valor no fuerza a recalcular el layout. Se pone roja (csw-hot) cuando se le indica.
export class Bar {
    constructor() {
        this.actor = new St.Widget({
            style_class: 'csw-track',
            layout_manager: new Clutter.BinLayout(),
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._fill = new St.Widget({style_class: 'csw-fill', x_expand: true, y_expand: true});
        this._fill.set_pivot_point(0, 0);
        this._fill.scale_x = 0;
        this.actor.add_child(this._fill);
    }

    set(fraction, hot = false) {
        // menos de medio punto no se nota en una barra de ~100 px: no redibujar por eso
        const value = Math.round(Math.min(1, Math.max(0, fraction)) * 200) / 200;
        if (value !== this._fill.scale_x)
            this._fill.scale_x = value;
        if (hot !== this._fill.has_style_class_name('csw-hot'))
            setClass(this._fill, 'csw-hot', hot);
    }
}

// Gráfico de barras verticales con las últimas N muestras (la más reciente a la derecha)
export class Sparkline {
    constructor(samples, floor) {
        this.actor = box('csw-spark');
        this._floor = floor;  // escala mínima: así el ruido de fondo no parece actividad
        this._values = new Array(samples).fill(0);
        this._bars = this._values.map(() => {
            const bar = new St.Widget({style_class: 'csw-spark-bar', x_expand: true, y_expand: true});
            bar.set_pivot_point(0, 1);
            bar.scale_y = 0.04;
            this.actor.add_child(bar);
            return bar;
        });
        this._bars.at(-1).add_style_class_name('csw-spark-now');
    }

    push(value) {
        this._values.shift();
        this._values.push(value);
        const max = Math.max(this._floor, ...this._values);
        this._bars.forEach((bar, i) => {
            const scale = Math.round(Math.max(0.04, this._values[i] / max) * 100) / 100;
            if (bar.scale_y !== scale)  // sin tráfico no cambia nada y no se redibuja
                bar.scale_y = scale;
        });
    }
}

export function readText(path) {
    try {
        return new TextDecoder().decode(GLib.file_get_contents(path)[1]).trim();
    } catch {
        return null;
    }
}

// Nombres de un directorio de /sys o /proc
export function listDir(path) {
    const names = [];
    try {
        const dir = GLib.Dir.open(path, 0);
        for (let name = dir.read_name(); name !== null; name = dir.read_name())
            names.push(name);
        dir.close();
    } catch {}
    return names.sort();
}

export const deg = v => `${Math.round(v)}°`;

export function formatRate(bytesPerSecond) {
    const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    let v = bytesPerSecond;
    let i = 0;
    while (v >= 1000 && i < units.length - 1) {
        v /= 1024;
        i++;
    }
    return `${v < 10 && i > 0 ? v.toFixed(1) : Math.round(v)} ${units[i]}`;
}

export function formatClock(seconds) {
    seconds = Math.max(0, Math.floor(seconds));
    const h = Math.floor(seconds / 3600);
    const m = Math.floor(seconds / 60) % 60;
    const s = String(seconds % 60).padStart(2, '0');
    return h ? `${h}:${String(m).padStart(2, '0')}:${s}` : `${m}:${s}`;
}

// 3h10 · 22m
export function formatHours(hours) {
    const total = Math.round(hours * 60);
    const h = Math.floor(total / 60);
    return h ? `${h}h${String(total % 60).padStart(2, '0')}` : `${total}m`;
}

// No vale la pena actualizar datos que nadie ve: el widget está tapado por una ventana
// (la extensión lo oculta y deja de estar "mapped") o la vista general está abierta
export function onScreen(actor) {
    return actor.mapped && !Main.overview.visible;
}
