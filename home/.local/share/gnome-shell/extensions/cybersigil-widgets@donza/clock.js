// Reloj grande: hora gótica, fecha y semana del año.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GnomeDesktop from 'gi://GnomeDesktop?version=4.0';

import {box, label, ornament, panel, setSpaced} from './common.js';

const DIAS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

export class ClockWidget {
    constructor() {
        let content;
        [this.actor, content] = panel('csw-clock');
        const timeRow = box('csw-time-row');
        this._time = label('csw-time');
        this._ampm = label('csw-ampm', '', {y_align: Clutter.ActorAlign.END});
        timeRow.add_child(this._time);
        timeRow.add_child(this._ampm);
        this._date = label('csw-date');
        this._sub = label('csw-sub');
        content.add_child(timeRow);
        content.add_child(ornament());
        content.add_child(this._date);
        content.add_child(this._sub);

        // mismo formato que el reloj del panel (12 o 24 horas, en Ajustes → Fecha y hora)
        this._interface = new Gio.Settings({schema_id: 'org.gnome.desktop.interface'});
        this._formatId = this._interface.connect('changed::clock-format', () => this._update());

        // WallClock avisa en cada cambio de minuto, y también tras suspender o cambiar la hora
        this._wallClock = new GnomeDesktop.WallClock({time_only: true});
        this._clockId = this._wallClock.connect('notify::clock', () => this._update());
        this._update();
    }

    _update() {
        const now = GLib.DateTime.new_now_local();
        const h12 = this._interface.get_string('clock-format') === '12h';
        this._time.text = h12 ? now.format('%l:%M').trim() : now.format('%H:%M');
        this._ampm.text = h12 ? (now.get_hour() < 12 ? 'AM' : 'PM') : '';
        this._ampm.visible = h12;
        setSpaced(this._date, `${DIAS[now.get_day_of_week() % 7]} ${now.get_day_of_month()} de ${MESES[now.get_month() - 1]}`.toUpperCase(), 2);
        setSpaced(this._sub, `${now.get_year()} · SEMANA ${now.get_week_of_year()}`, 1);
    }

    destroy() {
        this._wallClock.disconnect(this._clockId);
        this._interface.disconnect(this._formatId);
        this._wallClock = this._interface = null;
        this.actor.destroy();
    }
}
