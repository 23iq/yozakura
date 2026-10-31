import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings
import qs.modules.settings.store

// Short notice from the preset studio (saved, exported, an error) with
// Undo after a delete. Hides itself after a few seconds.
Item {
    id: toast

    readonly property var notice: PresetStudio.toast
    readonly property bool shown: notice !== null

    // "Details" of a notice (kept settings after an apply): the changes sheet.
    signal detailsRequested

    // Undo of a delete (a trash id) or of a save ("save:<version id>").
    function undo() {
        const id = toast.notice.undo;
        if (id.indexOf("save:") === 0)
            PresetStatusService.undoSave(id.slice(5), (ok, message) => PresetStudio.notify(message, ""));
        else
            PresetStudio.undoDelete(id);
    }

    objectName: "presetToast"
    implicitWidth: Math.min(row.implicitWidth + 32, parent ? parent.width - 32 : 560)
    implicitHeight: 48
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.exit.duration
        }
    }

    onNoticeChanged: if (notice)
        hide.restart()

    Timer {
        id: hide
        interval: 6000
        onTriggered: PresetStudio.toast = null
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Colors.inverseSurface
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, toast.parent ? toast.parent.width - 200 : 420)
            text: toast.notice ? toast.notice.text : ""
            elide: Text.ElideRight
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            color: Colors.inverseOnSurface
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            objectName: "toastUndo"
            visible: toast.notice !== null && toast.notice.undo !== ""
            text: I18n.t("prefs.presets.undo")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Bold
            color: Colors.inversePrimary
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: toast.undo()
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            objectName: "toastDetails"
            visible: toast.notice !== null && !!toast.notice.details
            text: I18n.t("presets.status.details")
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.Bold
            color: Colors.inversePrimary
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    PresetStudio.toast = null;
                    toast.detailsRequested();
                }
            }
        }
    }
}
