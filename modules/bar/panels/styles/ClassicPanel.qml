pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.bar as Bar
import qs.modules.bar.panels

// "classic": one continuous strip (BarBg) with pill modules; start and end
// groups at the ends, an optional center group (absolutely centered) and the
// integrated dock in the middle. Vertical keeps the historical column.
PanelStyleBase {
    id: classic

    readonly property var b: classic.barRoot

    implicitThickness: (vertical ? contentImplicitWidth : contentImplicitHeight) + 2 * padding
    outerMargin: barBg.outerMargin
    padding: barBg.padding
    startReach: padding + classicStartReach
    endReach: padding + classicEndReach

    readonly property Item contentItem: (classic.vertical ? verticalLoader.item : horizontalLoader.item) as Item
    readonly property int contentImplicitWidth: contentItem ? contentItem.implicitWidth : 0
    readonly property int contentImplicitHeight: contentItem ? contentItem.implicitHeight : 0

    // Outer ends of the groups, for live activities
    property real classicStartReach: 0
    property real classicEndReach: 0

    Bar.BarBg {
        id: barBg
        anchors.fill: parent
        position: classic.edge
        // options.surface: "bar" (default, theme bar background) or "bg"
        variant: classic.b && classic.b.options && classic.b.options.surface === "bg" ? "bg" : "barbg"
        effectiveContainBar: classic.b ? classic.b.contained : false

        Loader {
            id: horizontalLoader
            active: classic.b !== null && !classic.vertical
            anchors.fill: parent
            sourceComponent: RowLayout {
                id: classicRow
                spacing: 4

                Binding {
                    target: classic
                    property: "classicStartReach"
                    value: startGroupRow.x + startGroupRow.width
                }
                Binding {
                    target: classic
                    property: "classicEndReach"
                    value: classicRow.width - endGroupRow.x
                }

                RowLayout {
                    id: startGroupRow
                    spacing: 4
                    Layout.fillHeight: true

                    Bar.BarModuleGroup {
                        barRoot: classic.b
                        ids: classic.b.startIds
                        outerRadius: classic.b.outerRadius
                        innerRadius: classic.b.innerRadius
                        endConnected: classic.b.dockAtStart
                        enableShadow: classic.b.shadowsEnabled
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: classic.b.integratedDockEnabled

                    Bar.IntegratedDock {
                        bar: classic.b
                        orientation: classic.b.orientation
                        anchors.verticalCenter: parent.verticalCenter
                        enableShadow: classic.b.shadowsEnabled

                        // Connect to left/right groups if at start/end
                        startRadius: classic.b.dockAtStart ? classic.b.innerRadius : classic.b.outerRadius
                        endRadius: classic.b.dockAtEnd ? classic.b.innerRadius : classic.b.outerRadius

                        // Calculate target position based on config
                        property real targetX: {
                            if (classic.b.integratedDockPosition === "start")
                                return 0;
                            if (classic.b.integratedDockPosition === "end")
                                return parent.width - width;

                            // Center logic (reactive using parent.x + margin offset)
                            // RowLayout has anchors.margins: 4, so offset is 4
                            return (classic.width - width) / 2 - (parent.x + 4);
                        }

                        // Clamp the x position so it never leaves the container (preventing overlap)
                        x: Math.max(0, Math.min(parent.width - width, targetX))

                        width: Math.min(implicitWidth, parent.width)
                        height: implicitHeight
                    }
                }

                Item {
                    Layout.fillWidth: true
                    visible: !classic.b.integratedDockEnabled
                }

                // End group; the drawer slides out of its start edge
                RowLayout {
                    id: endGroupRow
                    spacing: 0
                    Layout.fillHeight: true

                    HoverHandler {
                        onHoveredChanged: classic.b.drawerHovered = hovered
                    }

                    Bar.BarDrawer {
                        id: classicDrawer
                        barRoot: classic.b
                        ids: classic.b.drawerIds
                        expanded: classic.b.drawerExpanded
                        outerRadius: classic.b.outerRadius
                        innerRadius: classic.b.innerRadius
                        enableShadow: classic.b.shadowsEnabled
                    }

                    RowLayout {
                        spacing: 4
                        Layout.fillHeight: true

                        Bar.BarModuleGroup {
                            barRoot: classic.b
                            ids: classic.b.endIds
                            outerRadius: classic.b.outerRadius
                            innerRadius: classic.b.innerRadius
                            startConnected: classic.b.dockAtEnd || classicDrawer.open
                            enableShadow: classic.b.shadowsEnabled
                        }
                    }
                }
            }
        }

        Loader {
            id: verticalLoader
            active: classic.b !== null && classic.vertical
            anchors.fill: parent
            sourceComponent: ColumnLayout {
                spacing: 4

                Bar.BarModuleGroup {
                    barRoot: classic.b
                    ids: classic.b.startIds
                    outerRadius: classic.b.outerRadius
                    innerRadius: classic.b.innerRadius
                    enableShadow: classic.b.shadowsEnabled
                }

                // Center Group Container
                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Calculate target position to be absolutely centered in the bar (vertically)
                        property real targetY: {
                            if (!parent)
                                return 0;

                            // Force re-evaluation when parent moves
                            var _trigger = parent.y;

                            var parentPos = parent.mapToItem(classic, 0, 0);
                            return (classic.height - height) / 2 - parentPos.y;
                        }

                        // Clamp y position
                        y: Math.max(0, Math.min(parent.height - height, targetY))

                        height: Math.min(parent.height, implicitHeight)
                        width: parent.width
                        spacing: 4

                        Bar.BarModuleGroup {
                            barRoot: classic.b
                            ids: classic.b.centerIds
                            outerRadius: classic.b.outerRadius
                            innerRadius: classic.b.innerRadius
                            // In vertical, the dock is always appended to this group if enabled
                            endConnected: classic.b.integratedDockEnabled
                            enableShadow: classic.b.shadowsEnabled
                            forcedAlignment: Qt.AlignHCenter
                        }
                    }

                    Bar.IntegratedDock {
                        bar: classic.b
                        orientation: classic.b.orientation
                        visible: classic.b.integratedDockEnabled
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        enableShadow: classic.b.shadowsEnabled

                        startRadius: classic.b.innerRadius
                        endRadius: classic.b.outerRadius
                    }
                }

                // End group; the drawer slides out of its top edge
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    HoverHandler {
                        onHoveredChanged: classic.b.drawerHovered = hovered
                    }

                    Bar.BarDrawer {
                        id: classicDrawerVert
                        barRoot: classic.b
                        ids: classic.b.drawerIds
                        expanded: classic.b.drawerExpanded
                        outerRadius: classic.b.outerRadius
                        innerRadius: classic.b.innerRadius
                        enableShadow: classic.b.shadowsEnabled
                    }

                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        Bar.BarModuleGroup {
                            barRoot: classic.b
                            ids: classic.b.endIds
                            outerRadius: classic.b.outerRadius
                            innerRadius: classic.b.innerRadius
                            startConnected: classicDrawerVert.open
                            enableShadow: classic.b.shadowsEnabled
                        }
                    }
                }
            }
        }

        // Horizontal center group, absolutely centered on the panel
        PanelCenterGroup {
            barRoot: classic.b
            active: classic.b !== null && !classic.vertical && classic.b.centerIds.length > 0
            anchors.centerIn: parent
            enableShadow: classic.b ? classic.b.shadowsEnabled : false
        }
    }

    // Modules floating (flat) in the free spans next to the center/notch
    PanelGapSlots {
        anchors.fill: parent
        barRoot: classic.b
        startLimit: classic.startReach + 8
        endLimit: classic.endReach + 8
    }
}
