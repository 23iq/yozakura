import QtQuick
import qs.modules.theme
import qs.config
import "Ui.js" as Ui

// Adapter for categories not migrated to the schema yet: hosts the old
// dashboard panel (modules/widgets/<legacy.source>) under the common page
// header, opened at its legacy sub-section. Nothing is lost while the
// categories migrate one by one.
Item {
    id: host

    required property var category
    property string subSection: category.legacy.section || ""

    function reveal(sectionId) {
        if (sectionId)
            Ui.setIfPresent(panel.item, "currentSection", sectionId);
    }

    PageHeader {
        id: header
        x: (parent.width - width) / 2
        y: 36
        width: Math.min(parent.width - 64, 820)
        category: host.category
    }

    Loader {
        id: panel
        anchors.top: header.bottom
        anchors.topMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        x: header.x
        width: header.width
        asynchronous: true
        source: Qt.resolvedUrl("../widgets/" + host.category.legacy.source)
        opacity: status === Loader.Ready ? 1 : 0
        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
            }
        }
        onLoaded: {
            // Legacy panels expose these as plain properties.
            // Classic panels were laid out for ~480 px; keep them readable.
            Ui.setIfPresent(item, "maxContentWidth", Qt.binding(() => Math.min(panel.width, 680)));
            if (host.subSection !== "")
                Ui.setIfPresent(item, "currentSection", host.subSection);
        }
    }
}
