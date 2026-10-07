import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.controls
import qs.modules.settings.store
import "PresetModel.js" as PresetModel
import "../Ui.js" as Ui

// Modal name prompt over the studio (save current look, duplicate,
// rename, mix): validates like the backend and explains why a name is
// refused. ask(title, initial, confirmLabel, except, callback(name)).
Item {
    id: root

    property string title: ""
    property string confirmLabel: ""
    property string except: ""
    property var callback: null
    readonly property bool shown: opacity > 0
    readonly property string problem: PresetModel.nameProblem(PresetStudio.presets, field.input.text, except)

    function ask(t, initial, confirm, keep, cb) {
        title = t;
        confirmLabel = confirm;
        except = keep || "";
        callback = cb;
        field.text = "";
        field.input.text = initial;
        opacity = 1;
        field.input.forceActiveFocus();
        field.input.selectAll();
    }

    function close() {
        opacity = 0;
        callback = null;
    }

    function accept() {
        if (problem !== "")
            return;
        const cb = callback;
        const name = field.input.text;
        close();
        if (cb)
            cb(name);
    }

    anchors.fill: parent
    opacity: 0
    visible: opacity > 0
    z: 50
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.exit.duration
        }
    }

    Connections {
        target: field.input
        function onAccepted() {
            root.accept();
        }
    }
    Shortcut {
        sequence: "Escape"
        enabled: root.shown
        onActivated: root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Ui.alpha(Colors.shadow, 0.45)
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 440)
        height: column.implicitHeight + 44
        radius: Math.min(Styling.radius(6), 26)
        color: Colors.surfaceContainerHigh
        border.width: 1
        border.color: Ui.alpha(Colors.outline, 0.35)
        scale: root.opacity * 0.06 + 0.94
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            x: 22
            y: 22
            width: parent.width - 44
            spacing: 14

            Text {
                width: parent.width
                text: root.title
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(3)
                font.weight: Font.Bold
                color: Colors.overBackground
                wrapMode: Text.WordWrap
            }
            TextControl {
                id: field
                objectName: "presetNameField"
                width: parent.width
                placeholder: I18n.t("prefs.presets.name.placeholder")
                invalid: root.problem !== "" && input.text !== ""
            }
            Text {
                width: parent.width
                visible: root.problem !== "" && field.input.text !== ""
                text: I18n.t(root.problem)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.error
                wrapMode: Text.WordWrap
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                PillButton {
                    kind: "ghost"
                    text: I18n.t("common.cancel")
                    onClicked: root.close()
                }
                PillButton {
                    objectName: "presetNameConfirm"
                    kind: "filled"
                    icon: "accept"
                    text: root.confirmLabel
                    enabled: root.problem === ""
                    onClicked: root.accept()
                }
            }
        }
    }
}
