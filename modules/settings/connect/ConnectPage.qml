import QtQuick
import qs.modules.theme
import qs.config
import qs.modules.settings
import "../Ui.js" as Ui

// Connect pages (network, bluetooth, sound, audio effects): live device
// controls, not settings. Hosts the dashboard's control panel for the page
// (modules/widgets/dashboard/controls/<panel>) under the common header.
Item {
    id: root

    required property var category
    // Panel file under modules/widgets/dashboard/controls/.
    required property string panel

    PageHeader {
        id: header
        x: (parent.width - width) / 2
        y: Metrics.padding * 3
        width: Math.min(parent.width - Metrics.padding * 5, Metrics.sheetW * 2)
        category: root.category
    }

    Loader {
        id: loader
        objectName: "connectPanel"
        anchors.top: header.bottom
        anchors.topMargin: Metrics.padding * 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Metrics.padding
        x: header.x
        width: header.width
        asynchronous: true
        source: Qt.resolvedUrl("../../widgets/dashboard/controls/" + root.panel)
        opacity: status === Loader.Ready ? 1 : 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.enter.duration
            }
        }
        onLoaded: Ui.setIfPresent(item, "maxContentWidth", Qt.binding(() => loader.width))
    }
}
