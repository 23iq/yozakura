import QtQuick
import qs.modules.theme
import qs.modules.components
import qs.modules.components.kit
import qs.modules.settings.store

// Card picture of a bar clock face (bar.moduleOptions.clock.face): the real
// face (modules/bar/clock/ClockFace.qml, a fixed 21:47, your 12-hour
// choice) on a piece of your bar.
MiniScreen {
    id: root

    property var entry
    property var value: "digital"

    StyledRect {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.86, face.width + Space.xl * 2)
        height: Math.round(parent.height * 0.5)
        variant: "barbg"
        backgroundOpacity: root.barOpacity
        enableShadow: false
        radius: Math.min(Styling.radius(0), height / 2)

        Loader {
            id: face
            anchors.centerIn: parent
            source: Qt.resolvedUrl("../../bar/clock/ClockFace.qml")
            onLoaded: {
                item.now = new Date(2026, 3, 9, 21, 47);
                item.textColor = Qt.binding(() => Colors.overBackground);
                item.fontSize = Qt.binding(() => Math.round(root.height * 0.2));
                item.face = Qt.binding(() => String(root.value));
                item.use12h = Qt.binding(() => SettingsStore.get("bar.use12hFormat") === true);
            }
        }
    }
}
