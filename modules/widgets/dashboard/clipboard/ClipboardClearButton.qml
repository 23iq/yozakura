import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

// "Clear history" button: the first press widens it into a confirmation.
StyledRect {
    id: clearButton

    required property ClipboardTabBase tab

    function activate() {
        if (clearButton.tab.clearButtonConfirmState) {
            clearButton.tab.clearClipboardHistory();
        } else {
            clearButton.tab.clearButtonConfirmState = true;
        }
    }

    function leave() {
        clearButton.tab.resetClearButton();
        clearButton.tab.clearButtonFocused = false;
        clearButton.tab.focusSearchInput();
    }

    width: clearButton.tab.clearButtonConfirmState ? 120 : 48
    height: 48
    variant: {
        if (clearButton.tab.clearButtonConfirmState) {
            return "error";
        } else if (clearButton.tab.clearButtonFocused || clearButtonMouseArea.containsMouse) {
            return "focus";
        } else {
            return "pane";
        }
    }
    focus: clearButton.tab.clearButtonFocused
    activeFocusOnTab: true

    Behavior on width {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Motion.morph.easing
        }
    }

    onActiveFocusChanged: {
        if (activeFocus) {
            clearButton.tab.clearButtonFocused = true;
        } else {
            clearButton.tab.clearButtonFocused = false;
            clearButton.tab.resetClearButton();
        }
    }

    MouseArea {
        id: clearButtonMouseArea
        anchors.fill: parent
        hoverEnabled: true

        onClicked: clearButton.activate()
    }

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            width: 32
            height: parent.height
            text: clearButton.tab.clearButtonConfirmState ? Icons.alert : Icons.trash
            textFormat: Text.RichText
            font.family: Icons.font
            font.pixelSize: 20
            color: clearButton.tab.clearButtonConfirmState ? clearButton.item : Styling.srItem("overprimary")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            width: parent.width - 32 - parent.spacing
            height: parent.height
            text: I18n.t("clipboard.clear_all_confirm")
            font.family: Config.theme.font
            font.weight: Font.Bold
            font.pixelSize: Config.theme.fontSize
            color: clearButton.item
            opacity: clearButton.tab.clearButtonConfirmState ? 1.0 : 0.0
            visible: opacity > 0
            verticalAlignment: Text.AlignVCenter

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Motion.enter.easing
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            clearButton.activate();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            clearButton.leave();
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
            clearButton.leave();
            event.accepted = true;
        }
    }
}
