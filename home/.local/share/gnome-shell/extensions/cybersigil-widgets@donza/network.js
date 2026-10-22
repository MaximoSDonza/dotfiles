// Red: conexión de NetworkManager (WiFi o cable), señal, IP y tráfico en vivo con gráfico.

import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import NM from 'gi://NM';

import {Bar, Sparkline, box, formatRate, header, label, onScreen, ornament, panel, readText, setClass, setSpaced, setText} from './common.js';

const TICK_S = 2;
const SAMPLES = 32;                 // 32 muestras × 2 s ≈ el último minuto
const SPARK_FLOOR = 64 * 1024;      // escala mínima del gráfico: 64 KB/s

function band(mhz) {
    if (mhz >= 5925)
        return '6 GHz';
    return mhz >= 4900 ? '5 GHz' : '2.4 GHz';
}

export class NetworkWidget {
    constructor() {
        let content;
        [this.actor, content] = panel('csw-network');
        let head;
        [head, this._caption] = header('Red');
        content.add_child(head);
        content.add_child(ornament());

        this._status = label('csw-cond csw-error');
        setSpaced(this._status, 'SIN CONEXIÓN', 1);
        content.add_child(this._status);

        this._signalRow = box('csw-row');
        this._signal = new Bar();
        this._signalValue = label('csw-row-value', '', {y_align: Clutter.ActorAlign.CENTER});
        this._signalRow.add_child(label('csw-row-name', 'SEÑAL', {y_align: Clutter.ActorAlign.CENTER}));
        this._signalRow.add_child(this._signal.actor);
        this._signalRow.add_child(this._signalValue);
        content.add_child(this._signalRow);

        this._info = label('csw-detail');
        content.add_child(this._info);

        this._spark = new Sparkline(SAMPLES, SPARK_FLOOR);
        content.add_child(this._spark.actor);
        const rates = box('csw-range');
        this._down = label('csw-down', '↓ …');
        this._up = label('csw-up', '↑ …');
        rates.add_child(this._down);
        rates.add_child(this._up);
        content.add_child(rates);

        this._iface = null;
        this._prev = null;
        this._client = null;
        this._clientIds = [];
        this._destroyed = false;
        this._refresh();

        NM.Client.new_async(null, (_o, res) => {
            let client;
            try {
                client = NM.Client.new_finish(res);
            } catch (e) {
                console.warn(`cybersigil-widgets: NetworkManager no disponible: ${e.message}`);
                return;
            }
            if (this._destroyed)
                return;
            this._client = client;
            for (const signal of ['notify::primary-connection', 'notify::state', 'active-connection-added', 'active-connection-removed'])
                this._clientIds.push(client.connect(signal, () => this._refresh()));
            this._refresh();
        });

        this._tickId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, TICK_S, () => {
            if (onScreen(this.actor)) {
                this._refresh();  // la señal y la velocidad del enlace cambian sin aviso
                this._sampleTraffic();
            }
            return GLib.SOURCE_CONTINUE;
        });
    }

    wake() {
        this._prev = null;  // la próxima muestra vuelve a medir desde ahora, no desde antes de la pausa
        this._refresh();
        this._sampleTraffic();
    }

    _refresh() {
        const conn = this._client?.get_primary_connection();
        const device = conn?.get_devices()?.[0];
        const connected = Boolean(conn && device);
        this._status.visible = !connected;
        this._info.visible = connected;
        if (!connected) {
            setSpaced(this._caption, 'DESCONECTADO', 2);
            this._signalRow.visible = false;
            this._setIface(null);
            return;
        }
        this._setIface(device.get_iface());

        const parts = [];
        const ap = device instanceof NM.DeviceWifi ? device.get_active_access_point() : null;
        this._signalRow.visible = ap !== null;
        if (ap) {
            const ssid = ap.get_ssid();
            setSpaced(this._caption, (ssid ? NM.utils_ssid_to_utf8(ssid.get_data()) : conn.get_id()).toUpperCase(), 1);
            const strength = ap.get_strength();
            this._signal.set(strength / 100, strength < 35);
            setText(this._signalValue, `${strength}%`);
            parts.push(band(ap.get_frequency()));
            const mbps = Math.round(device.get_bitrate() / 1000);
            if (mbps > 0)
                parts.push(`${mbps} Mb/s`);
        } else {
            setSpaced(this._caption, device instanceof NM.DeviceEthernet ? 'CABLE' : conn.get_id().toUpperCase(), 2);
            if (device instanceof NM.DeviceEthernet && device.get_speed() > 0)
                parts.push(`${device.get_speed()} Mb/s`);
        }
        const ip = conn.get_ip4_config()?.get_addresses()?.[0]?.get_address();
        if (ip)
            parts.push(ip);
        setText(this._info, parts.join('  ·  '));
    }

    _setIface(iface) {
        if (iface !== this._iface) {
            this._iface = iface;
            this._prev = null;  // otra interfaz: los contadores no son comparables
        }
    }

    _sampleTraffic() {
        if (!this._iface) {
            this._spark.push(0);
            setText(this._down, '');
            setText(this._up, '');
            return;
        }
        const stat = n => parseInt(readText(`/sys/class/net/${this._iface}/statistics/${n}_bytes`) ?? '0');
        const now = {rx: stat('rx'), tx: stat('tx'), t: GLib.get_monotonic_time() / 1e6};
        if (this._prev) {
            const dt = now.t - this._prev.t;
            const down = Math.max(0, (now.rx - this._prev.rx) / dt);
            const up = Math.max(0, (now.tx - this._prev.tx) / dt);
            this._spark.push(down);
            setText(this._down, `↓ ${formatRate(down)}`);
            setText(this._up, `↑ ${formatRate(up)}`);
            setClass(this._spark.actor, 'csw-spark-busy', down > 1024 * 1024);
        }
        this._prev = now;
    }

    destroy() {
        this._destroyed = true;
        GLib.source_remove(this._tickId);
        for (const id of this._clientIds)
            this._client.disconnect(id);
        this._client = null;
        this.actor.destroy();
    }
}
