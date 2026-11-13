pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.components.kit
import "DisplayFormat.js" as DisplayFormat

// Beside the Displays hero: the picked monitor (its name, connector and an
// on / off switch), its rotation as four tilted screens, adaptive sync,
// and the actions: Identify, Discard and Apply (15 s to keep or go back).
// Edits nothing itself: every change is a `patch` the page merges into
// the draft.
Column {
    id: root

    property var config: null
    property var output: null
    property bool dirty: false
    property bool busy: false
    readonly property bool active: !!root.config && root.config.enabled !== false

    signal patch(var values)
    signal identify
    signal discard
    signal apply

    spacing: Space.s

    Card {
        id: monitor
        width: root.width
        padding: Space.m
        spacing: Space.s

        Item {
            width: monitor.contentWidth
            height: Math.max(names.implicitHeight, toggle.height)
            Column {
                id: names
                anchors.left: parent.left
                anchors.right: toggle.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                KitText {
                    width: parent.width
                    role: "body"
                    font.weight: Type.weight("title")
                    // the monitor's name wraps in a narrow side column
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideNone
                    text: root.config ? DisplayFormat.title(root.output, root.config) : ""
                }
                KitText {
                    width: parent.width
                    role: "caption"
                    color: Type.secondary
                    elide: Text.ElideRight
                    text: root.config ? root.config.name : ""
                }
            }
            Switch {
                id: toggle
                objectName: "enabledToggle"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.active
                onToggled: v => root.patch({
                        "enabled": v
                    })
            }
        }

        // rotation: the screen drawn turned
        Row {
            objectName: "rotationSelector"
            visible: root.active
            spacing: Space.xs
            Repeater {
                model: DisplayFormat.rotationOptions().filter(o => o.value < 4)
                delegate: IconButton {
                    required property var modelData
                    objectName: "rotation:" + modelData.value
                    size: "s"
                    icon: Icons.monitor
                    rotation: modelData.value * 90
                    active: !!root.config && root.config.transform === modelData.value
                    tooltip: I18n.t(modelData.label)
                    onClicked: root.patch({
                        "transform": modelData.value
                    })
                }
            }
        }

        // adaptive sync (VRR) on / off
        Item {
            visible: root.active
            width: monitor.contentWidth
            height: Math.max(vrr.height, vrrLabel.height)
            // the name wraps in a narrow side column, whole
            KitText {
                id: vrrLabel
                anchors.left: parent.left
                anchors.right: vrr.left
                anchors.rightMargin: Space.s
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                text: I18n.t("prefs.displays.vrr")
            }
            Switch {
                id: vrr
                objectName: "vrrSelector"
                anchors.right: parent.right
                checked: !!root.config && Number(root.config.vrr) > 0
                onToggled: v => root.patch({
                        "vrr": v ? 1 : 0
                    })
            }
        }
    }

    Row {
        spacing: Space.s
        PillButton {
            objectName: "identifyButton"
            icon: "eye"
            kind: "ghost"
            text: I18n.t("prefs.displays.identify")
            onClicked: root.identify()
        }
    }
    Row {
        spacing: Space.s
        PillButton {
            objectName: "applyButton"
            kind: "filled"
            enabled: root.dirty && !root.busy
            icon: "accept"
            text: I18n.t("prefs.displays.apply")
            onClicked: root.apply()
        }
        PillButton {
            objectName: "discardButton"
            visible: root.dirty
            icon: "arrowCounterClockwise"
            kind: "ghost"
            text: I18n.t("prefs.displays.discard")
            onClicked: root.discard()
        }
    }
}
