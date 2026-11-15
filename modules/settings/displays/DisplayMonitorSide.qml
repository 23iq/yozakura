pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings
import qs.modules.components.kit
import "DisplayFormat.js" as DisplayFormat

// The inspector of the Displays hero card, beside the arrangement: the
// picked monitor (its name, connector and an on / off switch), its
// rotation as four tilted screens and adaptive sync at the top; the
// actions in one row at its foot: Identify, Discard and Apply (15 s to
// keep or go back). Edits nothing itself: every change is a `patch`
// the page merges into the draft. The page gives it its height.
Item {
    id: root

    property var config: null
    property var output: null
    property bool dirty: false
    property bool busy: false
    readonly property bool active: !!root.config && root.config.enabled !== false
    // the height the inspector needs (the hero card is at least this tall)
    readonly property real needed: top.implicitHeight + Space.l + actions.implicitHeight

    signal patch(var values)
    signal identify
    signal discard
    signal apply

    Column {
        id: top
        width: root.width
        spacing: Space.m

        Item {
            width: root.width
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
            width: root.width
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

    // the draft's actions, at the inspector's foot
    Column {
        id: actions
        anchors.bottom: parent.bottom
        width: root.width
        spacing: Space.s
        Divider {
            width: parent.width
        }
        // one actions row, Apply on the right edge (Identify wraps to a
        // line of its own when Discard needs the room)
        Flow {
            width: parent.width
            spacing: Space.s
            layoutDirection: Qt.RightToLeft
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
            PillButton {
                objectName: "identifyButton"
                icon: "eye"
                kind: "ghost"
                text: I18n.t("prefs.displays.identify")
                onClicked: root.identify()
            }
        }
    }
}
