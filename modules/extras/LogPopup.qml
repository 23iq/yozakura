import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components.kit
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
    width: Math.min((parent ? parent.width : 800) - Space.xxl * 2, 760)
    height: Math.min((parent ? parent.height : 700) - Space.xxl * 2, 560)
    padding: Look.surfacePadding
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

    background: Surface {}

    contentItem: Item {
        Item {
            id: header
            width: parent.width
            height: Space.controlM

            KitText {
                anchors.left: parent.left
                anchors.right: close.left
                anchors.rightMargin: Space.m
                anchors.verticalCenter: parent.verticalCenter
                role: "title"
                text: I18n.t("extras.ui.log.title", popup.name)
            }
            ExtrasButton {
                id: close
                objectName: "logClose"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                kind: "ghost"
                iconName: "cancel"
                text: I18n.t("extras.ui.close")
                onClicked: popup.close()
            }
        }

        // The log reads as an inset screen of the popup.
        Well {
            anchors.top: header.bottom
            anchors.topMargin: Space.m
            anchors.bottom: parent.bottom
            width: parent.width
            radius: Look.radius("control")

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: Space.hairline * 2
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
                    color: Type.text
                    selectionColor: Ui.alpha(Type.accent, 0.4)
                    padding: Space.m
                }
            }
        }
    }
}
