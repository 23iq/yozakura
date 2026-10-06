pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.controls
import "../Ui.js" as Ui
import "PartMeta.js" as PartMeta

// Controls of the layout builder's selected part: show/hide, style, edge
// and alignment, plus where its content went while it is hidden.
Item {
    id: root

    property string part: "bar"
    signal edit(string part, string field, var value)

    readonly property var partState: ShellLayout.layout[root.part]
    readonly property var meta: PartMeta.part(root.part)
    readonly property var alignOptions: PartMeta.alignOptions(root.part)
    // Re-homing notes (i18n keys) for this part
    readonly property var notes: {
        const out = [];
        if (root.part === "notch" && !root.partState.enabled)
            out.push("prefs.layout.home.activities." + ShellLayout.homeOf("activities"));
        if (root.part === "bar" && !root.partState.enabled)
            out.push("prefs.layout.home.clock." + ShellLayout.homeOf("clock"));
        if (root.part === "bar" && root.partState.enabled && ShellLayout.cornerContent.indexOf("activities") !== -1)
            out.push("prefs.layout.home.activities.corner");
        return out;
    }

    objectName: "partInspector"
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Metrics.spacing * 3

        // Header: icon, name, description, show switch
        Item {
            width: parent.width
            height: Math.max(head.implicitHeight, toggle.implicitHeight)

            Rectangle {
                id: tile
                width: 40
                height: 40
                radius: Math.min(Styling.radius(-2), 14)
                anchors.verticalCenter: parent.verticalCenter
                color: Ui.alpha(Colors.primary, root.partState.enabled ? 0.18 : 0.08)
                Text {
                    anchors.centerIn: parent
                    text: Icons[root.meta.icon] || ""
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(3)
                    color: root.partState.enabled ? Colors.primary : Colors.overSurfaceVariant
                }
            }
            Column {
                id: head
                anchors.left: tile.right
                anchors.leftMargin: Metrics.spacing * 3
                anchors.right: toggle.left
                anchors.rightMargin: Metrics.spacing * 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    text: I18n.t(root.meta.label)
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(1)
                    font.weight: Font.DemiBold
                    color: Colors.overBackground
                }
                Text {
                    width: parent.width
                    text: I18n.t(root.meta.desc)
                    wrapMode: Text.WordWrap
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                }
            }
            ToggleControl {
                id: toggle
                objectName: "partToggle"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.partState.enabled
                onToggled: value => root.edit(root.part, "enabled", value)
            }
        }

        // Where the content went while the part is hidden
        Repeater {
            model: root.notes
            Rectangle {
                id: note
                required property string modelData
                width: col.width
                height: noteText.implicitHeight + Metrics.spacing * 3
                radius: Math.min(Styling.radius(-2), 12)
                color: Ui.alpha(Colors.primary, 0.1)
                border.width: 1
                border.color: Ui.alpha(Colors.primary, 0.3)
                Text {
                    id: noteIcon
                    anchors.verticalCenter: parent.verticalCenter
                    x: Metrics.spacing * 3
                    text: Icons.info
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.primary
                }
                Text {
                    id: noteText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: noteIcon.right
                    anchors.leftMargin: Metrics.spacing * 2
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.spacing * 3
                    text: I18n.t(note.modelData)
                    wrapMode: Text.WordWrap
                    font.family: Styling.defaultFont
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overBackground
                }
            }
        }

        Field {
            label: "prefs.layout.field.style"
            options: PartMeta.styleOptions(root.part)
            value: root.partState.style
            field: "style"
        }
        Field {
            label: "prefs.layout.field.edge"
            options: PartMeta.edgeOptions(root.part)
            value: root.partState.edge
            field: "edge"
        }
        Field {
            visible: root.alignOptions.length > 0
            label: "prefs.layout.field.align"
            options: root.alignOptions
            value: root.partState.align
            field: "align"
        }
    }

    // A labelled selector row; dimmed while the part is hidden
    component Field: Item {
        id: fieldRow
        property string label
        property var options: []
        property var value
        property string field
        width: col.width
        height: Math.max(name.implicitHeight, selector.implicitHeight)
        opacity: root.partState.enabled ? 1 : 0.5
        enabled: root.partState.enabled

        Text {
            id: name
            width: 96
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t(fieldRow.label)
            font.family: Styling.defaultFont
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Medium
            color: Colors.overSurfaceVariant
        }
        SelectorControl {
            id: selector
            anchors.left: name.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: fieldRow.options
            value: fieldRow.value
            onSelected: value => root.edit(root.part, fieldRow.field, value)
        }
    }
}
