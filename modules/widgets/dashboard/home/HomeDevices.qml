pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// Audio devices for the composed dashboard's detail pane: the Pipewire
// outputs (`output: true`) or inputs as ListRows, the default one selected;
// a click makes a device the default.
ListView {
    id: root

    property bool output: true
    readonly property var current: root.output ? Audio.sink : Audio.source

    clip: true
    spacing: Space.xs / 2
    boundsBehavior: Flickable.StopAtBounds
    model: root.output ? Audio.outputDevices : Audio.inputDevices

    delegate: ListRow {
        id: entry

        required property var modelData

        objectName: "deviceRow"
        width: ListView.view.width
        height: Space.controlS + Space.s
        title: Audio.friendlyDeviceName(entry.modelData)
        selected: entry.modelData === root.current
        leading: Component {
            Text {
                text: root.output ? Icons.speakerHigh : Icons.mic
                font.family: Icons.font
                font.pixelSize: Type.iconSize("body")
                color: entry.selected ? Type.accent : Type.secondary
            }
        }
        onClicked: {
            if (root.output)
                Audio.setDefaultSink(entry.modelData);
            else
                Audio.setDefaultSource(entry.modelData);
        }
    }

    KitText {
        anchors.centerIn: parent
        visible: root.count === 0
        role: "caption"
        text: I18n.t("dashboard.home.no_devices")
    }
}
