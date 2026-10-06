import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.aicenter.common

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
    implicitHeight: row.implicitHeight + 12
    radius: Styling.radius(-4)
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
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 6
        UiText {
            Layout.fillWidth: true
            text: root.text
            wrapMode: Text.Wrap
            size: -2
            color: Styling.srItem(root.variant)
        }
        Chip {
            objectName: "confirmCancel"
            label: I18n.t("ai.tasks.cancel_action")
            variant: "transparent"
            onClicked: {
                root.close();
                root.cancelled();
            }
        }
        Chip {
            objectName: "confirmOk"
            label: root.confirmLabel
            variant: root.danger ? "error" : "primary"
            onClicked: {
                root.close();
                root.confirmed();
            }
        }
    }
}
