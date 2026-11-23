import QtQuick
import Quickshell.Wayland
import qs.modules.keybinds

// While a shortcut is recorded (KeyRecorder, KeybindsStore.recorders), the
// compositor skips its own binds for the focused window through
// keyboard-shortcuts-inhibit (niri, MangoWC, Hyprland), so a combo it
// already binds (Super+E, Super+Q) reaches the capture pad instead of
// running. Binds a niri config marks allow-inhibiting=false still fire.
ShortcutInhibitor {
    enabled: KeybindsStore.recorders > 0
}
