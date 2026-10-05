pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.settings.store
import "Ui.js" as Ui

// Renders a schema-driven category: header + one SettingsSection per
// schema section. Nothing here is category specific.
Flickable {
    id: page

    required property var category

    contentWidth: width
    contentHeight: column.implicitHeight + 120
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
    }

    NumberAnimation {
        id: scroller
        target: page
        property: "contentY"
        duration: Math.max(1, Config.animDuration * 1.5)
        easing.type: Easing.OutCubic
    }

    // Scroll to an entry (or a section) and flash it.
    function reveal(sectionId, entryId) {
        let target = null;
        for (let i = 0; i < sections.count; i++) {
            const s = sections.itemAt(i) as SettingsSection;
            if (!s)
                continue;
            if (entryId) {
                const r = s.rowFor(entryId);
                if (r) {
                    target = r;
                    break;
                }
            } else if (s.sectionId === sectionId) {
                target = s;
                break;
            }
        }
        if (!target)
            return;
        const y = target.mapToItem(column, 0, 0).y;
        scroller.to = Math.max(0, Math.min(y - 96, contentHeight - height));
        scroller.restart();
        if (entryId) {
            SettingsStore.highlightedEntry = entryId;
            unflash.restart();
        }
    }

    Timer {
        id: unflash
        interval: 1400
        onTriggered: SettingsStore.highlightedEntry = ""
    }

    Column {
        id: column
        width: Math.min(page.width - 64, 820)
        x: (page.width - width) / 2
        y: 36
        spacing: 30

        PageHeader {
            width: parent.width
            category: page.category
        }

        Repeater {
            id: sections
            model: page.category.sections

            delegate: SettingsSection {
                required property var modelData
                width: column.width
                section: modelData
            }
        }
    }
}
