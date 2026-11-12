pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// One wide status tile under the home bento: a plain system destination
// with its live value (the network you are on, the volume as a level, the
// power profile, the interface language and update state). The services
// are read only once home has shown its first frame (`live`).
Card {
    id: tile

    // a Categories.pills() entry: {id, icon, title}
    required property var destination
    property bool live: true
    readonly property string kind: destination.id
    readonly property string profile: tile.live && tile.kind === "power" ? String(PowerProfileClient.currentProfile || "") : ""
    // the big line: a value where there is one, else the name
    readonly property string value: {
        if (!tile.live)
            return I18n.t(tile.destination.title);
        switch (tile.kind) {
        case "network":
            return NetworkService.networkName || (NetworkService.ethernet ? "Ethernet" : I18n.t("prefs.home.offline"));
        case "power":
            return tile.profile ? I18n.t("prefs.home.profile." + tile.profile) : I18n.t(tile.destination.title);
        default:
            return I18n.t(tile.destination.title);
        }
    }
    // the small line: the destination's name under a value, else what it holds
    readonly property string caption: {
        if (tile.kind === "network" || (tile.kind === "power" && tile.profile))
            return I18n.t(tile.destination.title);
        if (tile.kind === "system") {
            const lang = (I18n.availableLanguages || {})[I18n.resolvedLanguage] || "";
            const upd = tile.live ? I18n.t(UpdateService.updateAvailable ? "prefs.home.update" : "prefs.home.uptodate") : "";
            return [lang, upd].filter(s => s).join(" · ");
        }
        if (tile.kind === "sound")
            return "";
        return I18n.t("prefs.home.sub." + tile.kind);
    }
    readonly property real volume: tile.live && tile.kind === "sound" ? Number(Audio.value ?? 0) : 0

    objectName: "homePill:" + destination.id
    interactive: true
    padding: Space.l
    Accessible.name: I18n.t(destination.title)

    Item {
        width: tile.contentWidth
        height: tile.height - tile.padding * 2

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons[tile.destination.icon] ?? ""
            role: "title"
            tone: "text"
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            x: glyph.width + Space.m
            width: parent.width - x
            spacing: Space.xs

            KitText {
                width: parent.width
                role: "body"
                font.weight: Font.DemiBold
                text: tile.value
                elide: Text.ElideRight
            }
            KitText {
                width: parent.width
                visible: tile.caption !== ""
                role: "secondary"
                text: tile.caption
                elide: Text.ElideRight
            }
            ProgressLine {
                visible: tile.kind === "sound"
                width: parent.width
                value: tile.volume
            }
        }
    }
}
