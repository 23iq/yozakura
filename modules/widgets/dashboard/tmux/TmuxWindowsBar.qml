pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components.kit

// Horizontally scrollable kit Chips of the selected session's windows (the
// active one `active`). Click switches window, double click attaches to the
// session.
Item {
    id: bar

    required property var tab
    property var currentSession: null

    function isSession(session) {
        return session && !session.isCreateButton && !session.isCreateSpecificButton;
    }

    Flickable {
        anchors.fill: parent
        contentWidth: windowsRow.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: windowsRow
            spacing: Space.s
            height: bar.height

            Repeater {
                model: bar.tab.sessionWindows

                Chip {
                    id: chip
                    required property var modelData

                    height: windowsRow.height
                    text: chip.modelData.index + ": " + chip.modelData.name
                    active: !!chip.modelData.active
                    highlighted: clicks.containsMouse

                    // Over the chip: it also needs double clicks.
                    MouseArea {
                        id: clicks
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (bar.isSession(bar.currentSession))
                                bar.tab.switchToWindow(bar.currentSession.name, chip.modelData.index);
                        }
                        onDoubleClicked: {
                            if (bar.isSession(bar.currentSession))
                                bar.tab.attachToSession(bar.currentSession.name);
                        }
                    }
                }
            }
        }
    }
}
