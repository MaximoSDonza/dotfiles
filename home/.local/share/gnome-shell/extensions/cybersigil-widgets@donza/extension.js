// Cybersigil Widgets: widgets de escritorio con el tema Cybersigil.
// stylesheet.css y ~/.config/cybersigil/generated/widgets.json los genera cybersigil-apply
// desde palette.sh; no editarlos a mano.
//
// Los widgets con el mismo ancla forman una columna: se apilan en el orden de la lista
// (de arriba hacia abajo) y comparten el ancho del más ancho.
//
// Consumo: un widget tapado por completo por una ventana se oculta (no se pinta ni mide nada),
// porque si no se repintaría con su desenfoque cada vez que esa ventana se redibuja (videos, scroll).

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

import {ClockWidget} from './clock.js';
import {MusicWidget} from './music.js';
import {NetworkWidget} from './network.js';
import {SystemWidget} from './system.js';
import {WeatherWidget} from './weather.js';

const FACTORIES = {
    clock: () => new ClockWidget(),
    weather: config => new WeatherWidget(config),
    system: () => new SystemWidget(),
    network: () => new NetworkWidget(),
    music: () => new MusicWidget(),
};

const DEFAULTS = {
    widgets: ['clock', 'system', 'weather', 'network', 'music'],
    anchors: {clock: 'top-left', system: 'top-left', weather: 'top-right', network: 'top-right', music: 'bottom-left'},
    city: 'Buenos Aires',
    region: 'Argentina',
    latitude: -34.6037,
    longitude: -58.3816,
    margin: 48,
    gap: 18,
    blur: 24,
};

// ventanas que pueden tapar a un widget (no el escritorio ni menús emergentes)
const COVERING_TYPES = [Meta.WindowType.NORMAL, Meta.WindowType.DIALOG, Meta.WindowType.MODAL_DIALOG, Meta.WindowType.UTILITY];

function loadConfig() {
    const path = GLib.build_filenamev([GLib.get_user_config_dir(), 'cybersigil', 'generated', 'widgets.json']);
    try {
        const [, bytes] = GLib.file_get_contents(path);
        const config = {...DEFAULTS, ...JSON.parse(new TextDecoder().decode(bytes))};
        config.anchors = {...DEFAULTS.anchors, ...config.anchors};
        return config;
    } catch (e) {
        console.warn(`cybersigil-widgets: usando valores por defecto (${e.message})`);
        return {...DEFAULTS};
    }
}

export default class CybersigilWidgets extends Extension {
    enable() {
        this._config = loadConfig();
        this._bg = Main.layoutManager._backgroundGroup;
        this._laters = {};
        this._widgets = [];
        this._windowSignals = new Map();

        for (const name of this._config.widgets) {
            const factory = FACTORIES[name];
            if (!factory) {
                console.warn(`cybersigil-widgets: widget desconocido "${name}"`);
                continue;
            }
            let widget;
            try {
                widget = factory(this._config);
            } catch (e) {
                // un widget roto no debe impedir que se muestren los demás
                console.error(`cybersigil-widgets: no se pudo crear "${name}": ${e.message}\n${e.stack}`);
                continue;
            }
            const actor = widget.actor;
            actor.reactive = false;  // los clics pasan al escritorio (salvo los botones de música)
            if (this._config.blur > 0)  // WIDGET_BLUR=0 en palette.sh desactiva el desenfoque
                actor.add_effect_with_name('csw-blur', this._blurEffect());
            // El contenedor es lo que se mueve y se oculta cuando una ventana tapa al widget.
            // actor.visible queda para el propio widget (la música se oculta si no suena nada).
            const slot = new Clutter.Actor({reactive: false});
            slot.add_child(actor);
            this._bg.add_child(slot);
            // Recolocar cuando cambia el contenido (textos, filas que aparecen) o la visibilidad.
            // No se escucha notify::width del panel: lo fija _place y se formaría un bucle que
            // redibuja la pantalla 60 veces por segundo
            const content = actor.get_last_child();  // panel(): [línea roja, contenido]
            content.connect('queue-relayout', () => this._queue('place'));
            actor.connect('notify::visible', () => this._queue('place'));
            this._widgets.push({widget, actor, slot, content, anchor: this._config.anchors[name] ?? 'top-left', width: -1});
        }

        const wm = global.workspace_manager;
        this._signals = [
            // al cambiar de fondo se agregan actores nuevos al grupo: los widgets vuelven arriba
            [this._bg, this._bg.connect('child-added', () => this._raise())],
            [Main.layoutManager, Main.layoutManager.connect('monitors-changed', () => this._queue('place'))],
            [global.display, global.display.connect('workareas-changed', () => this._queue('place'))],
            [Main.overview, Main.overview.connect('showing', () => this._fade(0))],
            [Main.overview, Main.overview.connect('hiding', () => {
                this._fade(255);
                this._wake();
            })],
            // ventanas que aparecen, se cierran, cambian de orden o de escritorio
            [global.display, global.display.connect('window-created', (_d, win) => this._trackWindow(win))],
            [global.display, global.display.connect('restacked', () => this._queue('occlusion'))],
            [wm, wm.connect('active-workspace-changed', () => this._queue('occlusion'))],
            [global.window_manager, global.window_manager.connect('minimize', () => this._queue('occlusion'))],
            [global.window_manager, global.window_manager.connect('unminimize', () => this._queue('occlusion'))],
        ];
        for (const actor of global.get_window_actors())
            this._trackWindow(actor.meta_window);

        this._raise();
        this._place();
        this._updateOcclusion();
        if (Main.overview.visible)
            this._fade(0);
    }

    _blurEffect() {
        const effect = new Shell.BlurEffect({mode: Shell.BlurMode.BACKGROUND, brightness: 1});
        if ('radius' in effect)
            effect.radius = this._config.blur * 2;
        else
            effect.sigma = this._config.blur;
        return effect;
    }

    _raise() {
        for (const {slot} of this._widgets)
            this._bg.set_child_above_sibling(slot, null);
    }

    // varios cambios seguidos (p. ej. al arrastrar una ventana) → un solo cálculo antes de dibujar
    _queue(what) {
        if (this._laters[what])
            return;
        this._laters[what] = global.compositor.get_laters().add(Meta.LaterType.BEFORE_REDRAW, () => {
            this._laters[what] = 0;
            if (what === 'place')
                this._place();
            else
                this._updateOcclusion();
            return GLib.SOURCE_REMOVE;
        });
    }

    _trackWindow(win) {
        if (this._windowSignals.has(win))
            return;
        const ids = ['position-changed', 'size-changed', 'notify::minimized'].map(
            s => win.connect(s, () => this._queue('occlusion')));
        ids.push(win.connect('unmanaged', () => {
            this._untrackWindow(win);
            this._queue('occlusion');
        }));
        this._windowSignals.set(win, ids);
        this._queue('occlusion');
    }

    _untrackWindow(win) {
        for (const id of this._windowSignals.get(win) ?? [])
            win.disconnect(id);
        this._windowSignals.delete(win);
    }

    // oculta los widgets tapados por completo por alguna ventana del escritorio actual
    _updateOcclusion() {
        const workspace = global.workspace_manager.get_active_workspace();
        const rects = workspace.list_windows()
            .filter(w => !w.minimized && w.showing_on_its_workspace() && COVERING_TYPES.includes(w.get_window_type()))
            .map(w => w.get_frame_rect());
        let revealed = false;
        for (const w of this._widgets) {
            const [x, y] = [w.slot.x, w.slot.y];
            const [width, height] = w.actor.get_size();
            const covered = width > 0 && rects.some(r =>
                r.x <= x && r.y <= y && r.x + r.width >= x + width && r.y + r.height >= y + height);
            if (covered === !w.slot.visible)
                continue;
            w.slot.visible = !covered;
            if (!covered) {
                revealed = true;
                w.widget.wake?.();
            }
        }
        if (revealed)
            this._queue('place');
    }

    // los widgets en vivo pausan mientras no se ven: que vuelvan con datos frescos
    _wake() {
        for (const {widget, slot} of this._widgets) {
            if (slot.visible)
                widget.wake?.();
        }
    }

    _place() {
        const monitor = Main.layoutManager.primaryIndex;
        if (monitor < 0)
            return;
        const area = Main.layoutManager.getWorkAreaForMonitor(monitor);
        const {margin, gap} = this._config;

        // actor.visible es la decisión del widget; slot.visible (tapado o no) no cambia el layout
        const columns = new Map();
        for (const w of this._widgets) {
            if (!w.actor.visible)
                continue;
            if (!columns.has(w.anchor))
                columns.set(w.anchor, []);
            columns.get(w.anchor).push(w);
        }

        for (const [anchor, widgets] of columns) {
            // ancho común: el natural del más ancho de la columna. Se mide el contenido (más el
            // borde y el min-width/width del CSS del panel), que no depende del ancho ya fijado
            const width = Math.ceil(Math.max(...widgets.map(({actor, content}) =>
                actor.get_theme_node().adjust_preferred_width(0, content.get_preferred_width(-1)[1])[1])));
            const heights = widgets.map(w => w.actor.get_preferred_height(width)[1]);
            const total = heights.reduce((a, b) => a + b, 0) + gap * (widgets.length - 1);

            let x = area.x + (area.width - width) / 2;
            if (anchor.endsWith('left'))
                x = area.x + margin;
            else if (anchor.endsWith('right'))
                x = area.x + area.width - width - margin;
            let y = anchor.startsWith('bottom') ? area.y + area.height - margin - total : area.y + margin;

            widgets.forEach((w, i) => {
                // solo si cambia: fijar el mismo valor también pide un relayout y un redibujado
                if (w.width !== width) {
                    w.width = width;
                    w.actor.set_width(width);
                }
                const [px, py] = [Math.round(x), Math.round(y)];
                if (w.slot.x !== px || w.slot.y !== py)
                    w.slot.set_position(px, py);
                y += heights[i] + gap;
            });
        }
        // con otra posición o tamaño, lo que tapa a cada widget puede haber cambiado
        this._queue('occlusion');
    }

    _fade(opacity) {
        for (const {slot} of this._widgets)
            slot.ease({opacity, duration: 200, mode: Clutter.AnimationMode.EASE_OUT_QUAD});
    }

    disable() {
        for (const id of Object.values(this._laters)) {
            if (id)
                global.compositor.get_laters().remove(id);
        }
        for (const [obj, id] of this._signals)
            obj.disconnect(id);
        for (const win of [...this._windowSignals.keys()])
            this._untrackWindow(win);
        for (const {widget, slot} of this._widgets) {
            widget.destroy();
            slot.destroy();
        }
        this._signals = this._widgets = this._windowSignals = this._laters = this._bg = this._config = null;
    }
}
