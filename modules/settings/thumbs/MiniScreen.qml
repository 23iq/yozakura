import QtQuick
import qs.modules.theme
import qs.modules.globals
import qs.modules.components.kit
import qs.modules.settings.store
import qs.modules.settings.previews

// The ground of a card picture: a plain raised fill with its corners
// rounded like the card's preview area, so the option's object is the
// subject. `desktop: true` (only where the wallpaper is the subject: the
// wallpaper's fit and transition) shows your wallpaper instead. Thumbs draw
// on top; `u` is one hundredth of the width, so shapes keep their
// proportions at any card size.
Item {
    id: root

    readonly property real u: width / 100
    // The bar surface is drawn at least this opaque (see Stage.barOpacity).
    readonly property real barOpacity: Math.max(Number(SettingsStore.get("theme.srBarBg.opacity") ?? 1), 0.82)
    readonly property string wallpaper: {
        const m = GlobalStates.wallpaperManager;
        if (!m)
            return "";
        const path = m.effectiveWallpaper ?? m.currentWallpaper ?? "";
        const shown = path && m.getDisplaySource ? m.getDisplaySource(path) : path;
        return shown ? (String(shown).startsWith("/") ? "file://" + shown : String(shown)) : "";
    }
    property bool desktop: false
    default property alias content: area.data

    clip: true

    Mark {
        anchors.fill: parent
        visible: !root.desktop
        radius: Space.smallRadius
        color: Look.raisedFill(false)
    }
    ScreenBackdrop {
        anchors.fill: parent
        visible: root.desktop
        radius: Space.smallRadius
    }
    Image {
        anchors.fill: parent
        visible: root.desktop && status === Image.Ready
        source: root.desktop ? root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: 320
    }
    Item {
        id: area
        anchors.fill: parent
    }
}
