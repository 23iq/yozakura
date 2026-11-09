import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.aicenter.common
import qs.modules.components.kit

// Inline confirmation: a question with Confirm / Cancel (Enter / Esc).
StyledRect {
    id: root

    property string text: ""
    property string confirmLabel: I18n.t("ai.tasks.confirm")
    property bool danger: false
    signal confirmed
    signal cancelled

    function ask() {
        root.visible = true;
        root.forceActiveFocus();
    }
    function close() {
        root.visible = false;
    }

    visible: false
    implicitHeight: row.implicitHeight + 2 * Space.s
    radius: Look.radius("control")
    variant: root.danger ? "errorfocus" : "focus"
    Keys.onReturnPressed: {
        root.close();
        root.confirmed();
    }
    Keys.onEscapePressed: {
        root.close();
        root.cancelled();
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Space.s
        anchors.rightMargin: Space.s
        spacing: Space.s
        AiText {
            role: "caption"
            Layout.fillWidth: true
            text: root.text
            wrapMode: Text.Wrap
            color: Styling.srItem(root.variant)
        }
        Chip {
            objectName: "confirmCancel"
            text: I18n.t("ai.tasks.cancel_action")
            quiet: true
            onClicked: {
                root.close();
                root.cancelled();
            }
        }
        Chip {
            objectName: "confirmOk"
            text: root.confirmLabel
            primary: true
            danger: root.danger
            onClicked: {
                root.close();
                root.confirmed();
            }
        }
    }
}
