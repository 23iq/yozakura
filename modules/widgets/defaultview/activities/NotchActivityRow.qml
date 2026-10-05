import QtQuick
import qs.config
import qs.modules.theme
import qs.modules.services
import qs.modules.services.activities
import qs.modules.bar.activities
import "NotchActivities.js" as NotchActivities

// One non-download activity in a notch panel: recording (with a stop
// button), timers, privacy (kind + apps; the microphone gets a mute
// toggle). Clicking the row activates it.
Item {
    id: row

    property var activity: null
    property string screenName: ""

    readonly property var a: row.activity || ({})
    readonly property var text: NotchActivities.activityText(row.a, {
        recording: I18n.t("shell.activities_recording")
    })
    readonly property color accent: {
        const c = Colors[row.a.color];
        return c !== undefined ? c : Colors.primary;
    }
    readonly property real iconSize: Math.round(Styling.fontSize(6))
    readonly property real pad: Math.round(Styling.fontSize(-4))

    implicitHeight: Math.max(row.iconSize, textColumn.implicitHeight, stopButton.implicitHeight) + row.pad * 2

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => ActivityService.activate(row.activity, event.button, row.screenName)
    }

    ActivityIndicator {
        id: indicator
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round((row.iconSize - width) / 2)
        kind: row.a.indicator || "glyph"
        icon: row.a.icon || ""
        image: row.a.image || ""
        progress: row.a.progress === undefined ? -1 : row.a.progress
        accent: row.accent
        size: Math.round(row.iconSize * 0.8)
    }

    Column {
        id: textColumn
        anchors.left: parent.left
        anchors.leftMargin: row.iconSize + row.pad * 2
        anchors.right: stopButton.visible ? stopButton.left : (muteButton.visible ? muteButton.left : parent.right)
        anchors.rightMargin: row.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.text.primary
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Colors.overBackground
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-1)
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: row.text.secondary
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Colors.overSurfaceVariant
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(-2)
            font.features: ({
                    "tnum": 1
                })
        }
    }

    NotchIconButton {
        id: stopButton
        visible: row.a.source === "recording"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.stop
        tone: "error"
        tooltip: I18n.t("activities.stop")
        onClicked: ActivityService.activate(row.activity, Qt.LeftButton, row.screenName)
    }

    NotchIconButton {
        id: muteButton
        visible: row.a.source === "privacy" && row.a.action === "mic"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: MicrophoneStatus.muted ? Icons.micSlash : Icons.mic
        tone: MicrophoneStatus.muted ? "error" : "overBackground"
        tooltip: MicrophoneStatus.muted ? I18n.t("activities.unmute") : I18n.t("activities.mute")
        onClicked: ActivityService.activate(row.activity, Qt.LeftButton, row.screenName)
    }
}
