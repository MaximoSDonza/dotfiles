// Cybersigil GDM: los colores van en stylesheet.css, que GNOME Shell carga al activar la extensión.
// Corre solo en la pantalla de inicio de sesión (session-modes: gdm). La instala gdm-theme.sh.
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class CybersigilGdm extends Extension {
    enable() {}
    disable() {}
}
