pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.settings.store
import "Ui.js" as Ui

// A titled card of SettingRows (one schema section). `collapsible: true`
// sections (advanced options) fold behind their title, `collapsed` sets the
// initial state; a search jump into a folded section unfolds it. A titled
// section with changed values shows a reset button in its header.
Column {
    id: sectionRoot

    required property var section
    readonly property string sectionId: section.id
    readonly property bool collapsible: !!section.collapsible
    property bool expanded: !(collapsible && section.collapsed)
    readonly property int modifiedCount: SettingsStore.sectionModifiedCount(section)

    objectName: "settingsSection:" + sectionId
    visible: !section.compositor || YozdService.compositorName === section.compositor
    spacing: 10

    function rowFor(entryId) {
        for (let i = 0; i < rows.count; i++) {
            const r = rows.itemAt(i);
            if (Ui.prop(r, "entryId") === entryId) {
                expanded = true;
                return r;
            }
        }
        return null;
    }

    Item {
        visible: !!sectionRoot.section.title
        width: parent.width
        height: title.implicitHeight

        Row {
            spacing: 6
            Text {
                id: title
                leftPadding: 6
                // Small caps label: upper unless the user picked a heading case.
                text: !sectionRoot.section.title ? "" : (Config.theme.type ? Config.theme.type.headingCase : "none") === "none" ? I18n.t(sectionRoot.section.title).toUpperCase() : Styling.heading(I18n.t(sectionRoot.section.title))
                font.family: Styling.headingFont
                font.pixelSize: Styling.fontSize(-3)
                font.weight: Font.Bold
                font.letterSpacing: 1.4
                color: Ui.alpha(Colors.overSurfaceVariant, 0.85)
            }
            Text {
                visible: sectionRoot.collapsible
                anchors.verticalCenter: title.verticalCenter
                text: sectionRoot.expanded ? Icons.caretDown : Icons.caretRight
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(-3)
                color: Ui.alpha(Colors.overSurfaceVariant, 0.85)
            }
        }

        MouseArea {
            objectName: "sectionToggle:" + sectionRoot.sectionId
            anchors.fill: parent
            enabled: sectionRoot.collapsible
            cursorShape: Qt.PointingHandCursor
            onClicked: sectionRoot.expanded = !sectionRoot.expanded
        }

        Text {
            objectName: "sectionReset:" + sectionRoot.sectionId
            visible: sectionRoot.modifiedCount > 0
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.arrowCounterClockwise
            font.family: Icons.font
            font.pixelSize: Styling.fontSize(-2)
            color: resetArea.containsMouse ? Colors.primary : Ui.alpha(Colors.overSurfaceVariant, 0.85)
            Accessible.role: Accessible.Button
            Accessible.name: I18n.t("prefs.common.reset_section")

            MouseArea {
                id: resetArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.resetSection(sectionRoot.section)
            }
        }
    }

    StyledRect {
        id: card
        variant: "pane"
        width: parent.width
        visible: sectionRoot.expanded
        height: visible ? list.implicitHeight : 0
        radius: Styling.radius(4)
        enableShadow: false

        // Hairline outline: keeps the card distinct from the window in
        // light mode and with translucent pane variants.
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            border.width: 1
            border.color: Ui.alpha(Colors.outlineVariant, 0.55)
            z: 10
        }

        Column {
            id: list
            width: parent.width

            Repeater {
                id: rows
                model: sectionRoot.section.entries

                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property alias entryId: settingRow.entryId
                    width: list.width
                    height: settingRow.height

                    // Hairline between visible rows
                    Rectangle {
                        x: 20
                        width: parent.width - 40
                        height: 1
                        color: Ui.alpha(Colors.outlineVariant, 0.45)
                        visible: slot.index > 0 && settingRow.shown
                    }

                    SettingRow {
                        id: settingRow
                        width: parent.width
                        entry: slot.modelData
                    }
                }
            }
        }
    }
}
