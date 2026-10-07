import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import "ExtrasUi.js" as Ui

// Modal viewer of one install job's log (`extras.log`, tail 256 KiB):
// read-only monospace text, scrolled to the end where the error is.
Popup {
    id: popup

    property string job: ""
    property string name: ""
    property string text: ""
    property bool loading: false

    function show(job, name) {
        popup.job = job;
        popup.name = name;
        popup.text = "";
        popup.loading = true;
        popup.open();
        ExtrasService.fetchLog(job, (text, error) => {
            if (popup.job !== job)
                return;
            popup.loading = false;
            popup.text = error ? error : text;
            Qt.callLater(() => flick.contentY = Math.max(0, flick.contentHeight - flick.height));
        });
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min((parent ? parent.width : 800) - 48, 760)
    height: Math.min((parent ? parent.height : 700) - 48, 560)
    padding: 22
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle {
        color: Ui.alpha(Colors.shadow, 0.45)
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Math.max(1, Config.animDuration / 2)
        }
        NumberAnimation {
            property: "scale"
            from: 0.96
            to: 1
            duration: Math.max(1, Config.animDuration / 2)
            easing.type: Motion.enter.easing
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: Math.max(1, Config.animDuration / 3)
        }
    }

    background: Rectangle {
        radius: Math.min(Styling.radius(6), 26)
        color: Colors.surfaceContainerHigh
        border.width: 1
        border.color: Ui.alpha(Colors.outline, 0.35)
    }

    contentItem: Item {
        Item {
            id: header
            width: parent.width
            height: 40

            Text {
                anchors.left: parent.left
                anchors.right: close.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("extras.ui.log.title", popup.name)
                elide: Text.ElideRight
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(2)
                font.weight: Font.Bold
                color: Colors.overBackground
            }
            ExtrasButton {
                id: close
                objectName: "logClose"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                kind: "ghost"
                icon: "cancel"
                text: I18n.t("extras.ui.close")
                onClicked: popup.close()
            }
        }

        Rectangle {
            anchors.top: header.bottom
            anchors.topMargin: 14
            anchors.bottom: parent.bottom
            width: parent.width
            radius: Math.min(Styling.radius(2), 14)
            color: Colors.surfaceContainerLowest
            border.width: 1
            border.color: Ui.alpha(Colors.outlineVariant, 0.6)

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 2
                clip: true
                contentWidth: width
                contentHeight: area.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                TextEdit {
                    id: area
                    objectName: "logText"
                    width: flick.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.WrapAnywhere
                    textFormat: TextEdit.PlainText
                    text: popup.loading ? I18n.t("extras.ui.log.loading") : (popup.text !== "" ? popup.text : I18n.t("extras.ui.log.empty"))
                    font.family: Config.theme.monoFont
                    font.pixelSize: Styling.monoFontSize(-2)
                    color: Colors.overSurface
                    selectionColor: Ui.alpha(Colors.primary, 0.4)
                    padding: 14
                }
            }
        }
    }
}
