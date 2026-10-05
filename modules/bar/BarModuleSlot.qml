pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.bar.workspaces
import qs.modules.bar.clock
import qs.modules.bar.systray
import qs.modules.widgets.dashboard
import qs.modules.widgets.powermenu
import qs.modules.widgets.presets
import qs.modules.bar
import qs.modules.theme
import "." as Bar
import "BarModuleRegistry.js" as Registry
// Lets Quickshell's scanner reach the file-based modules (loaded by URL)
import "modules" as BarFileModules

// Builds one bar module from its layout id (see BarLayout.js MODULE_IDS) and
// forwards the module's own Layout hints so it sizes exactly as when it was a
// direct child of the bar's RowLayout/ColumnLayout.
Loader {
    id: slot

    required property var barRoot
    required property string moduleId
    property real startRadius: 0
    property real endRadius: 0
    property bool enableShadow: true
    // 0 keeps the module's own alignment
    property int forcedAlignment: 0
    // Gap slots force flat modules on any style
    property bool forceFlat: false
    // "__sep__" slots draw this separator ("line", "dot", "slash")
    property string separatorStyle: "line"

    readonly property bool vertical: barRoot.orientation === "vertical"
    readonly property int moduleSize: barRoot.moduleSize !== undefined ? barRoot.moduleSize : BarMetrics.moduleSize
    readonly property bool flat: forceFlat || (barRoot.flat !== undefined ? barRoot.flat : false)
    readonly property bool shadow: enableShadow && !flat

    // File-based modules (BarModuleRegistry.js `file`) share one interface
    readonly property string moduleFile: Registry.file(moduleId)
    onModuleFileChanged: loadFileModule()
    Component.onCompleted: loadFileModule()
    function loadFileModule() {
        if (moduleFile === "")
            return;
        setSource(Qt.resolvedUrl(moduleFile), {
            "bar": barRoot
        });
    }
    Binding {
        target: slot.item
        when: slot.moduleFile !== "" && slot.item !== null
        property: "startRadius"
        value: slot.startRadius
    }
    Binding {
        target: slot.item
        when: slot.moduleFile !== "" && slot.item !== null
        property: "endRadius"
        value: slot.endRadius
    }
    Binding {
        target: slot.item
        when: slot.moduleFile !== "" && slot.item !== null
        property: "enableShadow"
        value: slot.shadow
    }
    Binding {
        target: slot.item
        when: slot.moduleFile !== "" && slot.item !== null
        property: "forceFlat"
        value: slot.forceFlat
    }

    sourceComponent: {
        if (moduleFile !== "")
            return null;
        switch (moduleId) {
        case "__sep__":
            return separatorComponent;
        case "launcher":
            return launcherComponent;
        case "workspaces":
            return workspacesComponent;
        case "layoutSelector":
            return layoutSelectorComponent;
        case "pin":
            return pinComponent;
        case "presets":
            return presetsComponent;
        case "tools":
            return toolsComponent;
        case "systray":
            return systrayComponent;
        case "controls":
            return controlsComponent;
        case "battery":
            return batteryComponent;
        case "clock":
            return clockComponent;
        case "power":
            return powerComponent;
        }
        console.warn("BarModuleSlot: unknown bar module id '" + moduleId + "'");
        return null;
    }

    // Loader.item is a QObject; every module is an Item.
    readonly property Item moduleItem: item as Item
    readonly property SysTray tray: item as SysTray

    // The tray hides itself when empty; collapse the slot so the layout does
    // not reserve spacing for it (matches the old direct-child behaviour).
    visible: moduleItem !== null && (tray === null || tray.hasItems)

    // A Loader's implicit size tracks the item's *size*, not its implicit
    // size; modules sizing themselves from their parent (SysTray's
    // `height: parent.height`) would collapse to 0. Fall back to the item's
    // implicit size, which is what the layout used for direct children.
    Layout.preferredWidth: moduleItem ? (moduleItem.Layout.preferredWidth >= 0 ? moduleItem.Layout.preferredWidth : moduleItem.implicitWidth) : -1
    Layout.preferredHeight: moduleItem ? (moduleItem.Layout.preferredHeight >= 0 ? moduleItem.Layout.preferredHeight : moduleItem.implicitHeight) : -1
    Layout.maximumWidth: moduleItem ? moduleItem.Layout.maximumWidth : Number.POSITIVE_INFINITY
    Layout.maximumHeight: moduleItem ? moduleItem.Layout.maximumHeight : Number.POSITIVE_INFINITY
    Layout.fillWidth: moduleItem ? moduleItem.Layout.fillWidth : false
    Layout.fillHeight: moduleItem ? moduleItem.Layout.fillHeight : false
    Layout.alignment: forcedAlignment !== 0 ? forcedAlignment : (moduleItem ? moduleItem.Layout.alignment : 0)

    Component {
        id: separatorComponent
        Bar.BarSeparator {
            vertical: slot.vertical
            style: slot.separatorStyle
            moduleSize: slot.moduleSize
        }
    }

    Component {
        id: launcherComponent
        LauncherButton {
            size: slot.moduleSize
            flat: slot.flat
            startRadius: slot.startRadius
            endRadius: slot.endRadius
            vertical: slot.vertical
            enableShadow: slot.shadow
        }
    }

    Component {
        id: workspacesComponent
        Workspaces {
            baseSize: slot.moduleSize
            flat: slot.flat
            orientation: slot.barRoot.orientation
            bar: QtObject {
                property var screen: slot.barRoot.screen
            }
            startRadius: slot.startRadius
            endRadius: slot.endRadius
            shadowEnabled: slot.shadow
        }
    }

    Component {
        id: layoutSelectorComponent
        LayoutSelectorButton {
            moduleSize: slot.moduleSize
            flat: slot.flat
            bar: slot.barRoot
            layerEnabled: slot.shadow
            startRadius: slot.startRadius
            endRadius: slot.endRadius
            vertical: slot.vertical
        }
    }

    Component {
        id: pinComponent
        Bar.BarPinButton {
            moduleSize: slot.moduleSize
            flat: slot.flat
            barRoot: slot.barRoot
            vertical: slot.vertical
            enableShadow: slot.shadow
            startRadius: slot.startRadius
            endRadius: slot.endRadius
        }
    }

    Component {
        id: presetsComponent
        PresetsButton {
            size: slot.moduleSize
            flat: slot.flat
            startRadius: slot.startRadius
            endRadius: slot.endRadius
            vertical: slot.vertical
            enableShadow: slot.shadow
        }
    }

    Component {
        id: toolsComponent
        ToolsButton {
            size: slot.moduleSize
            flat: slot.flat
            startRadius: slot.startRadius
            endRadius: slot.endRadius
            vertical: slot.vertical
            enableShadow: slot.shadow
        }
    }

    Component {
        id: systrayComponent
        SysTray {
            moduleSize: slot.moduleSize
            flat: slot.flat
            bar: slot.barRoot
            enableShadow: slot.shadow
            startRadius: slot.startRadius
            endRadius: slot.endRadius
        }
    }

    Component {
        id: controlsComponent
        ControlsButton {
            moduleSize: slot.moduleSize
            flat: slot.flat
            bar: slot.barRoot
            layerEnabled: slot.shadow
            startRadius: slot.startRadius
            endRadius: slot.endRadius
        }
    }

    Component {
        id: batteryComponent
        Bar.BatteryIndicator {
            moduleSize: slot.moduleSize
            flat: slot.flat
            bar: slot.barRoot
            layerEnabled: slot.shadow
            startRadius: slot.startRadius
            endRadius: slot.endRadius
        }
    }

    Component {
        id: clockComponent
        Clock {
            moduleSize: slot.moduleSize
            flat: slot.flat
            bar: slot.barRoot
            layerEnabled: slot.shadow
            startRadius: slot.startRadius
            endRadius: slot.endRadius
        }
    }

    Component {
        id: powerComponent
        PowerButton {
            size: slot.moduleSize
            flat: slot.flat
            startRadius: slot.startRadius
            endRadius: slot.endRadius
            vertical: slot.vertical
            enableShadow: slot.shadow
        }
    }
}
