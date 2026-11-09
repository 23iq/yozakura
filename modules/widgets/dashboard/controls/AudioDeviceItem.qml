pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit

// One output / input device as a kit ListRow: its glyph and name, the
// default one selected with a check; a click makes it the default.
ListRow {
    id: root

    required property PwNode node
    property bool isOutput: true
    property bool isSelected: false

    objectName: "audioDevice"
    title: Audio.friendlyDeviceName(root.node)
    selected: root.isSelected
    leading: Component {
        Icon {
            icon: root.isOutput ? Icons.speakerHigh : Icons.mic
            role: "body"
            tone: root.isSelected ? "accent" : "secondary"
        }
    }
    trailing: Component {
        Icon {
            visible: root.isSelected
            icon: Icons.accept
            role: "body"
            tone: "accent"
        }
    }
    onClicked: {
        if (root.isOutput)
            Audio.setDefaultSink(root.node);
        else
            Audio.setDefaultSource(root.node);
    }

    PwObjectTracker {
        objects: [root.node]
    }
}
