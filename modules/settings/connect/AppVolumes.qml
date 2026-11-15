pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConnectModel.js" as ConnectModel

// Sound > the apps playing now, each its icon, its name and its own volume
// line (applied at once); the list scrolls inside its card. Rows sit on
// the card's row inset (the title's text edge).
Item {
    id: root

    // full-width rows with their own inset (SettingRow.fullBleed)
    readonly property bool rowInset: false

    property var entry
    property real fillHeight: 0
    readonly property var apps: Audio.outputAppNodes || []

    objectName: "appVolumes"
    implicitHeight: root.fillHeight > 0 ? root.fillHeight : Space.controlL * 3
    clip: true

    // app streams report their volume only while tracked
    PwObjectTracker {
        objects: root.apps
    }

    KitText {
        anchors.centerIn: parent
        visible: root.apps.length === 0
        role: "secondary"
        text: I18n.t("prefs.sound.no_apps")
    }

    ListView {
        id: list
        anchors.fill: parent
        model: root.apps
        boundsBehavior: Flickable.StopAtBounds
        spacing: Space.m
        delegate: Item {
            id: app
            required property var modelData
            readonly property real volume: Number(app.modelData?.audio?.volume ?? 0)
            readonly property string name: Audio.appNodeDisplayName(app.modelData)
            readonly property string iconName: String(app.modelData?.properties?.["application.icon_name"] ?? "")
            objectName: "appVolume:" + app.name
            width: list.width
            // a few apps share the card's height (up to a roomy row each)
            height: Space.controlL

            // the app's icon (a small round monogram while there is none),
            // at the size of the device rows' icons
            Avatar {
                id: face
                x: Look.rowInset
                anchors.verticalCenter: parent.verticalCenter
                width: Space.controlXS
                height: width
                name: app.name
                source: app.iconName !== "" ? "image://icon/" + app.iconName : ""
            }
            Column {
                anchors.left: face.right
                anchors.leftMargin: Space.m
                anchors.right: parent.right
                anchors.rightMargin: Look.rowInset
                anchors.verticalCenter: parent.verticalCenter
                spacing: Space.xs
                KitText {
                    width: parent.width
                    role: "body"
                    elide: Text.ElideRight
                    text: app.name
                }
                LineSlider {
                    id: line
                    width: parent.width
                    from: 0
                    to: 1.5
                    step: 0.05
                    value: app.volume
                    icon: app.modelData?.audio?.muted ? Icons.speakerX : Icons.speakerHigh
                    showValue: true
                    valueText: ConnectModel.percent(app.volume)
                    onMoved: v => {
                        Audio.setNodeVolume(app.modelData, v);
                        line.value = Qt.binding(() => app.volume);
                    }
                }
            }
        }
    }
}
