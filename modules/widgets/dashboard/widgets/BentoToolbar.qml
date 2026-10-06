pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// Bento edit toolbar: add a widget, reset the layout (inline confirmation),
// finish editing. Every button is reachable with Tab and fires on Enter/Space.
StyledRect {
    id: root

    property bool canAdd: true
    property bool confirming: false

    signal addRequested
    signal resetRequested
    signal doneRequested

    variant: "popup"
    enableShadow: true
    radius: height / 2
    implicitWidth: row.implicitWidth + Metrics.spacing * 2
    implicitHeight: Metrics.rowHeight

    onVisibleChanged: if (!visible)
        confirming = false

    component ToolButton: StyledRect {
        id: btn

        property string icon: ""
        property string label: ""
        property string tone: "common"
        property bool available: true

        signal activated

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        implicitWidth: btnRow.implicitWidth + Metrics.spacing * 2.5
        implicitHeight: Metrics.rowHeight - Metrics.spacing
        radius: height / 2
        opacity: available ? 1 : 0.4
        variant: btn.activeFocus || hover.hovered ? (tone === "common" ? "focus" : tone + "focus") : tone
        activeFocusOnTab: available
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                btn.activated();
                event.accepted = true;
            }
        }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: Metrics.spacing / 2

            Text {
                visible: btn.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: btn.icon
                font.family: Icons.font
                font.pixelSize: Styling.fontSize(0)
                color: btn.tone === "common" ? Colors.overBackground : Styling.srItem(btn.tone)
            }
            Text {
                visible: btn.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.weight: Font.DemiBold
                color: btn.tone === "common" ? Colors.overBackground : Styling.srItem(btn.tone)
            }
        }

        HoverHandler {
            id: hover
            cursorShape: btn.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
        TapHandler {
            enabled: btn.available
            onTapped: btn.activated()
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Metrics.spacing / 2

        // Normal state
        ToolButton {
            objectName: "bentoAdd"
            visible: !root.confirming
            icon: Icons.plus
            label: I18n.t("bento.add")
            available: root.canAdd
            onActivated: root.addRequested()
        }
        ToolButton {
            objectName: "bentoReset"
            visible: !root.confirming
            icon: Icons.arrowCounterClockwise
            label: I18n.t("bento.reset")
            onActivated: {
                root.confirming = true;
                confirmYes.forceActiveFocus();
            }
        }
        ToolButton {
            objectName: "bentoDone"
            visible: !root.confirming
            icon: Icons.check
            label: I18n.t("bento.done")
            tone: "primary"
            onActivated: root.doneRequested()
        }

        // Inline reset confirmation
        Text {
            visible: root.confirming
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Metrics.spacing
            rightPadding: Metrics.spacing / 2
            text: I18n.t("bento.reset_confirm")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.overBackground
        }
        ToolButton {
            objectName: "bentoResetCancel"
            visible: root.confirming
            label: I18n.t("bento.cancel")
            onActivated: root.confirming = false
        }
        ToolButton {
            id: confirmYes
            objectName: "bentoResetConfirm"
            visible: root.confirming
            icon: Icons.arrowCounterClockwise
            label: I18n.t("bento.reset")
            tone: "error"
            onActivated: {
                root.confirming = false;
                root.resetRequested();
            }
        }
    }
}
