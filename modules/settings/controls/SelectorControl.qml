pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import "../Ui.js" as Ui

// Segmented choice. options: [{value, label (i18n key), icon (Icons name)}].
// Wraps onto several lines when it does not fit.
Item {
    id: root

    property var options: []
    property var value
    // false: labels are already display text (e.g. language names)
    property bool translate: true
    signal selected(var value)

    readonly property int currentIndex: {
        for (let i = 0; i < options.length; i++) {
            if (options[i].value === value)
                return i;
        }
        return -1;
    }

    // Width of all chips on one line. Inline rows give the control its
    // implicit width, so the Flow must not derive its width from ours.
    readonly property real rowWidth: {
        let w = 0;
        const n = chips.count;
        for (let i = 0; i < n; i++) {
            const it = chips.itemAt(i);
            if (it)
                w += it.width;
        }
        return Math.ceil(w + Math.max(0, n - 1) * flow.spacing) + 1;
    }

    implicitWidth: rowWidth + 8
    implicitHeight: flow.implicitHeight + 8
    activeFocusOnTab: true

    Keys.onLeftPressed: if (currentIndex > 0)
        selected(options[currentIndex - 1].value)
    Keys.onRightPressed: if (currentIndex < options.length - 1)
        selected(options[currentIndex + 1].value)

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Styling.radius(2), 18)
        color: Ui.alpha(Colors.overBackground, 0.06)
        border.width: root.activeFocus ? 2 : 0
        border.color: Colors.primary
    }

    Flow {
        id: flow
        x: 4
        y: 4
        width: Math.max(root.width - 8, 0) || root.rowWidth
        spacing: 4

        Repeater {
            id: chips
            model: root.options

            delegate: Item {
                id: chip
                required property var modelData
                required property int index
                readonly property bool selected: index === root.currentIndex

                width: Math.max(64, row.implicitWidth + 28)
                height: 32

                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(Styling.radius(0), 14)
                    color: chip.selected ? Colors.primary : (hover.containsMouse ? Ui.alpha(Colors.overBackground, 0.14) : "transparent")
                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                        }
                    }
                }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        visible: !!chip.modelData.icon
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.icon ? (Icons[chip.modelData.icon] ?? "") : ""
                        font.family: Icons.font
                        font.pixelSize: 14
                        color: chip.selected ? Colors.overPrimary : Colors.overSurfaceVariant
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.translate ? I18n.t(chip.modelData.label) : chip.modelData.label
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.weight: chip.selected ? Font.Bold : Font.Medium
                        color: chip.selected ? Colors.overPrimary : Colors.overBackground
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.forceActiveFocus();
                        root.selected(chip.modelData.value);
                    }
                }
            }
        }
    }
}
