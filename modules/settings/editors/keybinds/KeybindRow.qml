pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.keybinds
import qs.config
import "../../Ui.js" as Ui
import "../../../keybinds/BindModel.js" as BindModel

// One bind in the editor, one compact line: the app icon (app binds) or
// the action's group glyph, what it does, its keycaps and markers for a
// conflict / a changed default. Click to edit below (KeybindDetails).
Item {
    id: root

    required property var bind
    readonly property bool expanded: KeybindsStore.expandedUid === bind.uid
    readonly property var conflicts: KeybindsStore.conflictsOf(bind.uid)
    readonly property bool conflicted: conflicts.length > 0
    readonly property bool modified: KeybindsStore.isModified(bind)
    readonly property var app: BindModel.appOf(bind)
    // Just added, or moved here by a new action: flashes for a moment.
    readonly property bool highlighted: KeybindsStore.highlightUid !== "" && KeybindsStore.highlightUid === bind.uid

    objectName: "keybindRow:" + bind.uid
    implicitHeight: col.implicitHeight
    clip: true

    Behavior on implicitHeight {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Styling.radius(-4)
        color: root.expanded ? Ui.alpha(Colors.overBackground, 0.05) : (root.conflicted ? Ui.alpha(Colors.error, 0.06) : Ui.alpha(Colors.overBackground, headerArea.containsMouse ? 0.04 : 0))
        border.width: root.expanded ? 1 : 0
        border.color: root.conflicted ? Ui.alpha(Colors.error, 0.5) : Ui.alpha(Colors.outlineVariant, 0.6)
    }

    Rectangle {
        objectName: "keybindHighlight"
        anchors.fill: parent
        radius: Styling.radius(-4)
        color: Colors.primary
        opacity: root.highlighted ? 0.16 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Motion.enter.duration
                easing.type: Motion.enter.easing
            }
        }
    }

    Column {
        id: col
        width: parent.width

        Item {
            id: header
            width: parent.width
            height: Math.max(40, headerRow.implicitHeight + 10)

            MouseArea {
                id: headerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // An unassigned slot first becomes a custom bind
                onClicked: {
                    if (root.bind.kind === "slot")
                        KeybindsStore.claim(root.bind.uid);
                    else
                        KeybindsStore.expandedUid = root.expanded ? "" : root.bind.uid;
                }
            }

            RowLayout {
                id: headerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 10

                // Apps group: the app's icon (or a terminal for commands).
                Item {
                    visible: root.bind.group === "apps"
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    opacity: root.bind.enabled ? 1 : 0.45

                    IconImage {
                        anchors.fill: parent
                        visible: !!root.app && root.app.id !== ""
                        implicitSize: 20
                        source: root.app ? Quickshell.iconPath(root.app.icon || root.app.id, "application-x-executable") : ""
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.app || root.app.id === ""
                        text: Icons[BindModel.group(root.bind.group).icon] ?? ""
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                    }
                }

                // Title, then (conflict) what else fires on this combo: kept,
                // never overwritten.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: title.implicitHeight

                    Text {
                        id: title
                        width: Math.min(implicitWidth, parent.width)
                        text: KeybindsStore.title(root.bind)
                        elide: Text.ElideRight
                        opacity: root.bind.enabled ? 1 : 0.5
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: Font.Medium
                        color: Colors.overBackground
                    }
                    Text {
                        objectName: "conflictNote"
                        x: title.width + 10
                        width: Math.max(0, parent.width - x)
                        anchors.baseline: title.baseline
                        visible: root.conflicted && width > 40
                        text: I18n.t("binds.conflict_with", KeybindsStore.conflictText(root.bind.uid).split("\n").join(", "))
                        elide: Text.ElideRight
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-3)
                        color: Colors.error
                    }
                }

                Text {
                    visible: !root.bind.enabled
                    text: I18n.t("binds.off")
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-3)
                    font.weight: Font.DemiBold
                    color: Colors.outline
                }

                Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4
                    opacity: root.bind.enabled ? 1 : 0.45

                    Repeater {
                        model: root.bind.keys
                        delegate: KeyCombo {
                            required property var modelData
                            x: parent ? parent.width - width : 0
                            modifiers: modelData.modifiers
                            key: modelData.key
                            tone: root.conflicted ? "error" : "normal"
                            placeholder: I18n.t("binds.not_set")
                        }
                    }
                }

                Text {
                    visible: root.conflicted
                    text: Icons.warning
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.error
                }

                // Changed from the default: one click restores it.
                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    visible: root.modified

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: resetArea.containsMouse ? Ui.alpha(Colors.primary, 0.16) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: Icons.arrowCounterClockwise
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.primary
                    }
                    MouseArea {
                        id: resetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: KeybindsStore.reset(root.bind.uid)
                    }
                    StyledToolTip {
                        show: resetArea.containsMouse
                        tooltipText: I18n.t("common.reset_default")
                    }
                }
            }
        }

        Loader {
            width: parent.width
            active: root.expanded
            visible: active
            sourceComponent: KeybindDetails {
                bind: root.bind
            }
        }
    }
}
