// Recursos del equipo: CPU, RAM, temperatura, disco y batería. Lee /proc y /sys, sin permisos extra.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import {Bar, box, formatHours, header, label, listDir, onScreen, ornament, panel, readText, setSpaced, setText} from './common.js';

const TICK_S = 2;
const DISK_TICK_S = 60;
const GiB = 1024 ** 3;

// Umbrales a partir de los cuales la barra se pone roja
const HOT = {cpu: 0.85, ram: 0.85, temp: 80, disk: 0.90, battery: 0.20};

// 2D 3H · 3H 25M · 12M
function formatUptime(seconds) {
    const mins = Math.floor(seconds / 60);
    const [d, h, m] = [Math.floor(mins / 1440), Math.floor(mins / 60) % 24, mins % 60];
    return d ? `${d}D ${h}H` : h ? `${h}H ${m}M` : `${m}M`;
}

function findTempSensor() {
    for (const zone of listDir('/sys/class/thermal').filter(n => n.startsWith('thermal_zone'))) {
        if (readText(`/sys/class/thermal/${zone}/type`) === 'x86_pkg_temp')
            return `/sys/class/thermal/${zone}/temp`;
    }
    // AMD u otros: el sensor de CPU de hwmon
    for (const hw of listDir('/sys/class/hwmon')) {
        if (['coretemp', 'k10temp', 'zenpower', 'cpu_thermal'].includes(readText(`/sys/class/hwmon/${hw}/name`)))
            return `/sys/class/hwmon/${hw}/temp1_input`;
    }
    return null;
}

function findBattery() {
    for (const name of listDir('/sys/class/power_supply')) {
        const dir = `/sys/class/power_supply/${name}`;
        // scope=Device son baterías de mouse o auriculares, no la de la laptop
        if (readText(`${dir}/type`) === 'Battery' && readText(`${dir}/scope`) !== 'Device')
            return dir;
    }
    return null;
}

export class SystemWidget {
    constructor() {
        let content;
        [this.actor, content] = panel('csw-system');
        let head;
        [head, this._uptime] = header('Sistema');
        content.add_child(head);
        content.add_child(ornament());

        this._rows = {};
        for (const [key, name] of [['cpu', 'CPU'], ['ram', 'RAM'], ['temp', 'TEMP'], ['disk', 'DISCO'], ['battery', 'BAT']]) {
            const row = box('csw-row');
            const bar = new Bar();
            const value = label('csw-row-value', '', {y_align: Clutter.ActorAlign.CENTER});
            row.add_child(label('csw-row-name', name, {y_align: Clutter.ActorAlign.CENTER}));
            row.add_child(bar.actor);
            row.add_child(value);
            content.add_child(row);
            this._rows[key] = {row, bar, value};
        }

        this._tempPath = findTempSensor();
        this._battery = findBattery();
        this._rows.temp.row.visible = this._tempPath !== null;
        this._rows.battery.row.visible = this._battery !== null;
        this._prevCpu = null;

        this._tick(true);
        this._updateDisk();
        this._tickId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, TICK_S, () => {
            this._tick();
            return GLib.SOURCE_CONTINUE;
        });
        this._diskId = GLib.timeout_add_seconds(GLib.PRIORITY_LOW, DISK_TICK_S, () => {
            this._updateDisk();
            return GLib.SOURCE_CONTINUE;
        });
    }

    wake() {
        this._tick(true);
    }

    _set(key, fraction, text, hot) {
        const r = this._rows[key];
        r.bar.set(fraction, hot);
        setText(r.value, text);
    }

    _tick(force = false) {
        if (!force && !onScreen(this.actor))
            return;
        this._updateCpu();
        this._updateRam();
        this._updateTemp();
        this._updateBattery();
        setSpaced(this._uptime, `ACTIVO ${formatUptime(parseFloat(readText('/proc/uptime') ?? '0'))}`, 1);
    }

    _updateCpu() {
        // /proc/stat: cpu user nice system idle iowait irq softirq steal
        const fields = (readText('/proc/stat') ?? '').split('\n')[0].trim().split(/\s+/).slice(1, 9).map(Number);
        const idle = fields[3] + fields[4];
        const total = fields.reduce((a, b) => a + b, 0);
        if (this._prevCpu) {
            const dTotal = total - this._prevCpu.total;
            const usage = dTotal > 0 ? 1 - (idle - this._prevCpu.idle) / dTotal : 0;
            this._set('cpu', usage, `${Math.round(usage * 100)}%`, usage >= HOT.cpu);
        } else {
            this._set('cpu', 0, '…', false);
        }
        this._prevCpu = {idle, total};
    }

    _updateRam() {
        const info = {};
        for (const line of (readText('/proc/meminfo') ?? '').split('\n')) {
            const [k, v] = line.split(':');
            if (v)
                info[k] = parseInt(v) * 1024;
        }
        const used = info.MemTotal - info.MemAvailable;
        const frac = used / info.MemTotal;
        this._set('ram', frac, `${(used / GiB).toFixed(1)}/${Math.round(info.MemTotal / GiB)} GB`, frac >= HOT.ram);
    }

    _updateTemp() {
        if (!this._tempPath)
            return;
        const celsius = parseInt(readText(this._tempPath) ?? '0') / 1000;
        // la barra va de 30 °C (vacía) a 100 °C (llena)
        this._set('temp', (celsius - 30) / 70, `${Math.round(celsius)}°C`, celsius >= HOT.temp);
    }

    _updateBattery() {
        if (!this._battery)
            return;
        const read = f => parseInt(readText(`${this._battery}/${f}`) ?? 'NaN');
        const capacity = read('capacity');
        const status = readText(`${this._battery}/status`);
        // energy_* (µWh, µW) o charge_* (µAh, µA), según el fabricante
        const now = read('energy_now') || read('charge_now');
        const full = read('energy_full') || read('charge_full');
        const rate = Math.abs(read('power_now') || read('current_now'));
        let extra = '';
        if (status === 'Charging')
            extra = rate > 0 ? ` · ⚡${formatHours((full - now) / rate)}` : ' · ⚡';
        else if (status === 'Discharging' && rate > 0)
            extra = ` · ${formatHours(now / rate)}`;
        else if (status === 'Full' || status === 'Not charging')
            extra = ' · ⚡';
        const frac = capacity / 100;
        this._set('battery', frac, `${capacity}%${extra}`, status === 'Discharging' && frac <= HOT.battery);
    }

    _updateDisk() {
        try {
            const info = Gio.File.new_for_path('/').query_filesystem_info('filesystem::size,filesystem::free', null);
            const size = info.get_attribute_uint64('filesystem::size');
            const free = info.get_attribute_uint64('filesystem::free');
            const frac = (size - free) / size;
            this._set('disk', frac, `${Math.round(free / GiB)} GB libres`, frac >= HOT.disk);
        } catch (e) {
            this._rows.disk.row.visible = false;
        }
    }

    destroy() {
        GLib.source_remove(this._tickId);
        GLib.source_remove(this._diskId);
        this.actor.destroy();
    }
}
