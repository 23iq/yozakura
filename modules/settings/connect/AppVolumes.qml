pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "ConnectModel.js" as ConnectModel

// Sound > the apps playing now, each its name over its own volume line
// (applied at once); the list scrolls inside its card.
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
        delegate: Column {
            id: app
            required property var modelData
            readonly property real volume: Number(app.modelData?.audio?.volume ?? 0)
            objectName: "appVolume:" + Audio.appNodeDisplayName(app.modelData)
            width: list.width
            spacing: Space.xs
            KitText {
                width: parent.width
                role: "secondary"
                elide: Text.ElideRight
                text: Audio.appNodeDisplayName(app.modelData)
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
