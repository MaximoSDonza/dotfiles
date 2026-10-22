// Música: lo que suena en cualquier reproductor MPRIS (Spotify, YouTube en Brave o Firefox, VLC...).
// Prioriza el que está reproduciendo; si no suena nada, el widget se oculta.

import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Soup from 'gi://Soup?version=3.0';
import St from 'gi://St';

import {Bar, box, formatClock, header, label, onScreen, ornament, panel, setSpaced, setText} from './common.js';

const MPRIS_PREFIX = 'org.mpris.MediaPlayer2.';
const MPRIS_PATH = '/org/mpris/MediaPlayer2';
const PLAYER_IFACE = 'org.mpris.MediaPlayer2.Player';
const ART_DIR = GLib.build_filenamev([GLib.get_user_cache_dir(), 'cybersigil-widgets', 'art']);
const ART_MAX_AGE_S = 7 * 24 * 3600;
const RESYNC_US = 30 * 1e6;  // cada cuánto se corrige la posición calculada

function getProperty(busName, iface, prop, cancellable, callback) {
    Gio.DBus.session.call(busName, MPRIS_PATH, 'org.freedesktop.DBus.Properties', 'Get',
        new GLib.Variant('(ss)', [iface, prop]), new GLib.VariantType('(v)'),
        Gio.DBusCallFlags.NONE, 2000, cancellable, (conn, res) => {
            let value = null;
            try {
                value = conn.call_finish(res).deepUnpack()[0].recursiveUnpack();
            } catch {}
            callback(value);
        });
}

class Player {
    constructor(busName, {onChanged, onSeeked}) {
        this.busName = busName;
        // "spotify", "chromium.instance1234" → hasta que llegue el nombre real (Identity)
        this.identity = busName.slice(MPRIS_PREFIX.length).split('.')[0];
        this.lastActive = 0;
        this.status = 'Stopped';
        this.metadata = {};
        this.rate = 1;
        this._onChanged = onChanged;
        this._onSeeked = onSeeked;
        this._cancellable = new Gio.Cancellable();

        Gio.DBusProxy.new_for_bus(Gio.BusType.SESSION, Gio.DBusProxyFlags.GET_INVALIDATED_PROPERTIES, null,
            busName, MPRIS_PATH, PLAYER_IFACE, this._cancellable, (_o, res) => {
                try {
                    this._proxy = Gio.DBusProxy.new_for_bus_finish(res);
                } catch (e) {
                    if (!e.matches?.(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                        console.warn(`cybersigil-widgets: reproductor ${busName}: ${e.message}`);
                    return;
                }
                this._propsId = this._proxy.connect('g-properties-changed', () => this._changed());
                // al adelantar/retroceder el reproductor avisa la nueva posición (µs)
                this._signalId = this._proxy.connect('g-signal', (_p, _sender, signal, params) => {
                    if (signal === 'Seeked')
                        this._onSeeked(this, Number(params.deepUnpack()[0]));
                });
                this._changed();
            });
        getProperty(busName, 'org.mpris.MediaPlayer2', 'Identity', this._cancellable, identity => {
            if (identity) {
                this.identity = identity;
                this._onChanged();
            }
        });
    }

    _prop(name) {
        return this._proxy?.get_cached_property(name)?.recursiveUnpack();
    }

    // se desempaqueta una vez por cambio, no en cada consulta
    _changed() {
        this.status = this._prop('PlaybackStatus') ?? 'Stopped';
        this.metadata = this._prop('Metadata') ?? {};
        this.rate = this._prop('Rate') ?? 1;
        if (this.status === 'Playing')
            this.lastActive = GLib.get_monotonic_time();
        this._onChanged();
    }

    call(method) {
        this._proxy?.call(method, null, Gio.DBusCallFlags.NONE, -1, null, null);
    }

    position(callback) {
        getProperty(this.busName, PLAYER_IFACE, 'Position', this._cancellable, callback);
    }

    destroy() {
        this._cancellable.cancel();
        if (this._propsId) {
            this._proxy.disconnect(this._propsId);
            this._proxy.disconnect(this._signalId);
        }
        this._proxy = null;
    }
}

// borra portadas descargadas hace más de una semana
function pruneArtCache() {
    try {
        const dir = Gio.File.new_for_path(ART_DIR);
        const files = dir.enumerate_children('standard::name,time::modified', Gio.FileQueryInfoFlags.NONE, null);
        const limit = GLib.get_real_time() / 1e6 - ART_MAX_AGE_S;
        for (let info = files.next_file(null); info; info = files.next_file(null)) {
            if (info.get_modification_date_time().to_unix() < limit)
                dir.get_child(info.get_name()).delete(null);
        }
    } catch {}
}

export class MusicWidget {
    constructor() {
        this._players = new Map();
        this._player = null;
        this._artUrl = undefined;
        this._cancellable = new Gio.Cancellable();
        this._session = new Soup.Session({timeout: 15, user_agent: 'cybersigil-widgets'});
        GLib.mkdir_with_parents(ART_DIR, 0o700);
        pruneArtCache();

        let content;
        [this.actor, content] = panel('csw-music');
        let head;
        [head, this._caption] = header('Sonando');
        content.add_child(head);
        content.add_child(ornament());

        const body = box('csw-music-body');
        this._art = new St.Widget({style_class: 'csw-art', layout_manager: new Clutter.BinLayout()});
        this._artSigil = label('csw-art-sigil', '⸸', {x_expand: true, y_expand: true,
            x_align: Clutter.ActorAlign.CENTER, y_align: Clutter.ActorAlign.CENTER});
        this._art.add_child(this._artSigil);
        // portada en escala de grises, como el resto del tema
        this._art.add_effect_with_name('desaturate', new Clutter.DesaturateEffect({factor: 1}));
        body.add_child(this._art);

        const info = box('csw-music-info', true, {x_expand: true, y_align: Clutter.ActorAlign.CENTER});
        this._title = label('csw-track-title');
        this._artist = label('csw-track-artist');
        this._progress = new Bar();
        const bottom = box('csw-music-bottom');
        this._time = label('csw-music-time', '', {x_expand: true, y_align: Clutter.ActorAlign.CENTER});
        bottom.add_child(this._time);
        bottom.add_child(this._button('media-skip-backward-symbolic', 'Previous'));
        this._playIcon = new St.Icon({style_class: 'csw-btn-icon', icon_name: 'media-playback-start-symbolic'});
        bottom.add_child(this._button(this._playIcon, 'PlayPause'));
        bottom.add_child(this._button('media-skip-forward-symbolic', 'Next'));
        for (const a of [this._title, this._artist, this._progress.actor, bottom])
            info.add_child(a);
        body.add_child(info);
        content.add_child(body);
        this.actor.visible = false;

        // reproductores que aparecen y desaparecen del bus de sesión
        this._nameSub = Gio.DBus.session.signal_subscribe('org.freedesktop.DBus', 'org.freedesktop.DBus',
            'NameOwnerChanged', '/org/freedesktop/DBus', null, Gio.DBusSignalFlags.NONE,
            (_c, _s, _p, _i, _sig, params) => {
                const [name, oldOwner, newOwner] = params.deepUnpack();
                if (!name.startsWith(MPRIS_PREFIX))
                    return;
                if (oldOwner)
                    this._removePlayer(name);
                if (newOwner)
                    this._addPlayer(name);
            });
        Gio.DBus.session.call('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'ListNames',
            null, new GLib.VariantType('(as)'), Gio.DBusCallFlags.NONE, -1, this._cancellable, (conn, res) => {
                try {
                    const [names] = conn.call_finish(res).deepUnpack();
                    names.filter(n => n.startsWith(MPRIS_PREFIX)).forEach(n => this._addPlayer(n));
                } catch {}
            });

        // La posición no se notifica mientras suena. En vez de preguntarle al reproductor cada
        // segundo (lo despertaría 60 veces por minuto) se calcula desde la última conocida, y se
        // vuelve a consultar solo al cambiar de tema, pausar, adelantar o cada 30 s
        this._pos = null;          // {us, at}: posición en µs y cuándo se midió (reloj monótono)
        this._lastFetch = 0;
        this._trackKey = '';
        this._tickId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            if (this._player?.status === 'Playing' && onScreen(this.actor)) {
                if (GLib.get_monotonic_time() - this._lastFetch > RESYNC_US)
                    this._fetchPosition();
                else
                    this._renderPosition();
            }
            return GLib.SOURCE_CONTINUE;
        });
    }

    wake() {
        if (this._player)
            this._fetchPosition();
    }

    _button(icon, method) {
        const child = typeof icon === 'string' ? new St.Icon({style_class: 'csw-btn-icon', icon_name: icon}) : icon;
        const button = new St.Button({style_class: 'csw-btn', child, reactive: true, can_focus: false, track_hover: true});
        button.connect('clicked', () => this._player?.call(method));
        return button;
    }

    _addPlayer(name) {
        if (!this._players.has(name))
            this._players.set(name, new Player(name, {
                onChanged: () => this._sync(),
                onSeeked: (player, us) => {
                    if (player === this._player) {
                        this._pos = {us, at: GLib.get_monotonic_time()};
                        this._renderPosition();
                    }
                },
            }));
    }

    _removePlayer(name) {
        this._players.get(name)?.destroy();
        this._players.delete(name);
        this._sync();
    }

    // el que está sonando (el más reciente si hay varios); si no, el último en pausa
    _pickPlayer() {
        const withTrack = [...this._players.values()].filter(p => p.metadata['xesam:title']);
        const recent = list => list.sort((a, b) => b.lastActive - a.lastActive)[0];
        return recent(withTrack.filter(p => p.status === 'Playing')) ??
            recent(withTrack.filter(p => p.status === 'Paused')) ?? null;
    }

    _sync() {
        const player = this._pickPlayer();
        this._player = player;
        this.actor.visible = player !== null;
        if (!player)
            return;

        const meta = player.metadata;
        const playing = player.status === 'Playing';
        setSpaced(this._caption, `${player.identity.toUpperCase()}${playing ? '' : ' · PAUSA'}`, 2);
        setText(this._title, meta['xesam:title'] ?? '');
        const artist = meta['xesam:artist'];
        setText(this._artist, (Array.isArray(artist) ? artist.join(', ') : artist) || meta['xesam:album'] || '');
        this._artist.visible = this._artist.text !== '';
        this._playIcon.icon_name = playing ? 'media-playback-pause-symbolic' : 'media-playback-start-symbolic';
        this._setArt(meta['mpris:artUrl'] ?? null);

        // otro reproductor, otro tema o play/pausa: la posición calculada ya no sirve
        const key = `${player.busName}|${meta['mpris:trackid'] ?? meta['xesam:title']}|${player.status}`;
        if (key !== this._trackKey) {
            this._trackKey = key;
            this._fetchPosition();
        }
    }

    _fetchPosition() {
        const player = this._player;
        this._lastFetch = GLib.get_monotonic_time();
        player.position(position => {
            if (player !== this._player)
                return;
            this._pos = position === null ? null : {us: Number(position), at: GLib.get_monotonic_time()};
            this._renderPosition();
        });
    }

    _renderPosition() {
        const player = this._player;
        const length = Number(player.metadata['mpris:length'] ?? 0) / 1e6;
        if (!length || !this._pos) {
            // transmisión en vivo o reproductor que no informa la posición
            this._progress.set(0);
            setText(this._time, length ? formatClock(length) : '');
            return;
        }
        const elapsed = player.status === 'Playing' ? (GLib.get_monotonic_time() - this._pos.at) * player.rate : 0;
        const seconds = Math.min(length, (this._pos.us + elapsed) / 1e6);
        this._progress.set(seconds / length);
        setText(this._time, `${formatClock(seconds)} / ${formatClock(length)}`);
    }

    _setArt(url) {
        if (url === this._artUrl)
            return;
        this._artUrl = url;
        if (url?.startsWith('file://')) {
            this._showArt(url);
        } else if (/^https?:\/\//.test(url ?? '')) {
            // portadas remotas (Spotify): se descargan una vez a ~/.cache
            const path = GLib.build_filenamev([ART_DIR, GLib.compute_checksum_for_string(GLib.ChecksumType.SHA1, url, -1)]);
            if (GLib.file_test(path, GLib.FileTest.EXISTS)) {
                this._showArt(GLib.filename_to_uri(path, null));
                return;
            }
            this._showArt(null);
            const message = Soup.Message.new('GET', url);
            this._session.send_and_read_async(message, GLib.PRIORITY_LOW, this._cancellable, (session, res) => {
                try {
                    const bytes = session.send_and_read_finish(res);
                    if (message.get_status() !== Soup.Status.OK)
                        return;
                    GLib.file_set_contents(path, bytes.get_data());
                    if (this._artUrl === url)
                        this._showArt(GLib.filename_to_uri(path, null));
                } catch {}
            });
        } else {
            this._showArt(null);
        }
    }

    _showArt(uri) {
        this._artSigil.visible = !uri;
        this._art.style = uri ? `background-image: url("${uri}");` : null;
    }

    destroy() {
        this._cancellable.cancel();
        Gio.DBus.session.signal_unsubscribe(this._nameSub);
        GLib.source_remove(this._tickId);
        for (const player of this._players.values())
            player.destroy();
        this._players.clear();
        this._player = null;
        this._session.abort();
        this.actor.destroy();
    }
}
