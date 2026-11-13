pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConnectModel.js" as ConnectModel

// Sound > the apps playing now, each its icon, its name and its own volume
// line (applied at once); the list scrolls inside its card.
Item {
    id: root

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
            height: Math.max(Space.controlL + Space.s, Math.min((Space.controlL + Space.s) * 1.9, (list.height - list.spacing * (root.apps.length - 1)) / Math.max(1, root.apps.length)))

            // the app's icon (its initials while there is none)
            Avatar {
                id: face
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(Space.controlL, app.height - Space.s * 2)
                height: width
                radius: Look.radius("small", height)
                name: app.name
                source: app.iconName !== "" ? "image://icon/" + app.iconName : ""
            }
            Column {
                anchors.left: face.right
                anchors.leftMargin: Space.m
                anchors.right: parent.right
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
