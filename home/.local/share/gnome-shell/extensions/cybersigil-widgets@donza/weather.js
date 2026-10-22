// Clima actual (Open-Meteo, sin cuenta ni clave): temperatura, estado, mínima/máxima y lluvia.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Soup from 'gi://Soup?version=3.0';
import St from 'gi://St';

import * as LoginManager from 'resource:///org/gnome/shell/misc/loginManager.js';

import {box, deg, header, label, ornament, panel, setSpaced} from './common.js';

const REFRESH_S = 15 * 60;    // cada 15 minutos
const RETRY_S = 60;           // si falla, reintenta al minuto
const CACHE_MAX_AGE_S = 10 * 60;

// Códigos WMO de Open-Meteo → [descripción, icono simbólico]
const WMO = {
    0: ['Despejado', 'weather-clear'],
    1: ['Mayormente despejado', 'weather-few-clouds'],
    2: ['Parcialmente nublado', 'weather-few-clouds'],
    3: ['Nublado', 'weather-overcast'],
    45: ['Niebla', 'weather-fog'],
    48: ['Niebla con escarcha', 'weather-fog'],
    51: ['Llovizna leve', 'weather-showers-scattered'],
    53: ['Llovizna', 'weather-showers-scattered'],
    55: ['Llovizna intensa', 'weather-showers-scattered'],
    56: ['Llovizna helada', 'weather-showers-scattered'],
    57: ['Llovizna helada intensa', 'weather-showers-scattered'],
    61: ['Lluvia leve', 'weather-showers-scattered'],
    63: ['Lluvia', 'weather-showers'],
    65: ['Lluvia intensa', 'weather-showers'],
    66: ['Lluvia helada', 'weather-showers'],
    67: ['Lluvia helada intensa', 'weather-showers'],
    71: ['Nevada leve', 'weather-snow'],
    73: ['Nevada', 'weather-snow'],
    75: ['Nevada intensa', 'weather-snow'],
    77: ['Granizo fino', 'weather-snow'],
    80: ['Chaparrones leves', 'weather-showers-scattered'],
    81: ['Chaparrones', 'weather-showers'],
    82: ['Chaparrones violentos', 'weather-showers'],
    85: ['Chaparrones de nieve', 'weather-snow'],
    86: ['Chaparrones de nieve intensos', 'weather-snow'],
    95: ['Tormenta', 'weather-storm'],
    96: ['Tormenta con granizo', 'weather-storm'],
    99: ['Tormenta fuerte con granizo', 'weather-storm'],
};
const NIGHT_ICON = {'weather-clear': 'weather-clear-night', 'weather-few-clouds': 'weather-few-clouds-night'};

// El clima sobrevive a disable/enable (la extensión se desactiva al bloquear la pantalla)
let weatherCache = null;  // {data, fetchedAt}

export class WeatherWidget {
    constructor(config) {
        this._config = config;
        this._failed = false;
        this._timeoutId = 0;
        this._cancellable = new Gio.Cancellable();
        this._session = new Soup.Session({timeout: 20, user_agent: 'cybersigil-widgets'});
        this._interface = new Gio.Settings({schema_id: 'org.gnome.desktop.interface'});

        let content;
        [this.actor, content] = panel('csw-weather');
        const [head, caption] = header(config.city);
        setSpaced(caption, config.region.toUpperCase(), 2);
        content.add_child(head);
        content.add_child(ornament());

        const main = box('csw-weather-main');
        this._icon = new St.Icon({style_class: 'csw-weather-icon', icon_name: 'weather-overcast-symbolic',
            y_align: Clutter.ActorAlign.CENTER});
        this._temp = label('csw-temp', '--°', {y_align: Clutter.ActorAlign.CENTER});
        main.add_child(this._icon);
        main.add_child(this._temp);
        content.add_child(main);

        this._cond = label('csw-cond');
        setSpaced(this._cond, 'CARGANDO…', 1);
        this._detail = label('csw-detail');
        const range = this._range = box('csw-range');
        this._lo = label('csw-lo');
        this._hi = label('csw-hi');
        this._rain = label('csw-rain');
        range.add_child(this._lo);
        range.add_child(this._hi);
        range.add_child(this._rain);
        this._updated = label('csw-updated');
        for (const a of [this._cond, this._detail, range, this._updated])
            content.add_child(a);
        this._hideEmptyRows();

        // tras suspender, o cuando vuelve la red después de un fallo, actualizar enseguida
        this._loginManager = LoginManager.getLoginManager();
        this._sleepId = this._loginManager.connect('prepare-for-sleep', (_lm, aboutToSuspend) => {
            if (!aboutToSuspend)
                this._schedule(10);
        });
        this._netMonitor = Gio.NetworkMonitor.get_default();
        this._netId = this._netMonitor.connect('network-changed', (_m, available) => {
            if (available && this._failed)
                this._schedule(3);
        });

        const age = weatherCache ? GLib.get_real_time() / 1e6 - weatherCache.fetchedAt : Infinity;
        if (weatherCache)
            this._render(weatherCache.data, weatherCache.fetchedAt);
        this._schedule(age < CACHE_MAX_AGE_S ? CACHE_MAX_AGE_S - age : 0);
    }

    _schedule(seconds) {
        if (this._timeoutId)
            GLib.source_remove(this._timeoutId);
        this._timeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, Math.max(1, Math.round(seconds)), () => {
            this._timeoutId = 0;
            this._fetch();
            return GLib.SOURCE_REMOVE;
        });
    }

    _fetch() {
        const {latitude, longitude} = this._config;
        const url = 'https://api.open-meteo.com/v1/forecast' +
            `?latitude=${latitude}&longitude=${longitude}` +
            '&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day' +
            '&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max' +
            '&timezone=auto&forecast_days=1';
        const message = Soup.Message.new('GET', url);
        this._session.send_and_read_async(message, GLib.PRIORITY_DEFAULT, this._cancellable, (session, result) => {
            if (!this._session)  // el widget ya se destruyó (p. ej. al bloquear la pantalla)
                return;
            let data;
            try {
                const bytes = session.send_and_read_finish(result);
                if (message.get_status() !== Soup.Status.OK)
                    throw new Error(`HTTP ${message.get_status()}`);
                data = JSON.parse(new TextDecoder().decode(bytes.get_data()));
                if (!data.current)
                    throw new Error('respuesta sin datos actuales');
            } catch (e) {
                if (e.matches?.(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                    return;
                console.warn(`cybersigil-widgets: no se pudo obtener el clima: ${e.message}`);
                this._failed = true;
                this._showError();
                this._schedule(RETRY_S);
                return;
            }
            this._failed = false;
            const fetchedAt = GLib.get_real_time() / 1e6;
            weatherCache = {data, fetchedAt};
            this._render(data, fetchedAt);
            this._schedule(REFRESH_S);
        });
    }

    _render(data, fetchedAt) {
        const c = data.current;
        const d = data.daily ?? {};
        const [text, icon] = WMO[c.weather_code] ?? ['Sin datos', 'weather-severe-alert'];
        this._icon.icon_name = `${c.is_day ? icon : NIGHT_ICON[icon] ?? icon}-symbolic`;
        this._temp.text = deg(c.temperature_2m);
        setSpaced(this._cond, text.toUpperCase(), 1);
        this._cond.remove_style_class_name('csw-error');
        this._detail.text = `ST ${deg(c.apparent_temperature)}  ·  HUM ${c.relative_humidity_2m}%  ·  ${Math.round(c.wind_speed_10m)} km/h`;
        this._lo.text = d.temperature_2m_min ? `↓ ${deg(d.temperature_2m_min[0])}` : '';
        this._hi.text = d.temperature_2m_max ? `↑ ${deg(d.temperature_2m_max[0])}` : '';
        const rain = d.precipitation_probability_max?.[0];
        this._rain.text = rain === null || rain === undefined ? '' : `LLUVIA ${rain}%`;
        // misma hora que el reloj del panel (12 o 24 h)
        const format = this._interface.get_string('clock-format') === '12h' ? '%l:%M %p' : '%H:%M';
        this._updated.text = `act. ${GLib.DateTime.new_from_unix_local(Math.floor(fetchedAt)).format(format).trim()}`;
        this._hideEmptyRows();
    }

    _showError() {
        setSpaced(this._cond, weatherCache ? 'SIN CONEXIÓN · DATOS ANTERIORES' : 'SIN CONEXIÓN', 1);
        this._cond.add_style_class_name('csw-error');
        if (!weatherCache)
            this._icon.icon_name = 'network-offline-symbolic';
        this._hideEmptyRows();
    }

    // las filas sin datos no deben dejar huecos en el panel
    _hideEmptyRows() {
        this._detail.visible = this._detail.text !== '';
        this._updated.visible = this._updated.text !== '';
        this._range.visible = [this._lo, this._hi, this._rain].some(l => l.text !== '');
    }

    destroy() {
        this._cancellable.cancel();
        if (this._timeoutId)
            GLib.source_remove(this._timeoutId);
        this._loginManager.disconnect(this._sleepId);
        this._netMonitor.disconnect(this._netId);
        this._session.abort();
        this._session = this._interface = null;
        this.actor.destroy();
    }
}
