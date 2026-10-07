import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme

// Modules listed in bar.layout.drawer. Collapsed to nothing until `expanded`,
// then slides out of the end group (right/bottom) towards the screen center.
Item {
    id: drawer

    required property var barRoot
    property var ids: []
    property bool expanded: false
    property real spacing: 4
    property real outerRadius: 0
    property real innerRadius: 0
    property bool enableShadow: true

    readonly property bool vertical: barRoot.orientation === "vertical"
    readonly property bool hasModules: ids.length > 0
    // Same timing as the notch's media hover expansion
    readonly property int animationDuration: Math.min(Config.animDuration, Math.max(0, Config.notch.mediaAnimationDuration))

    property real progress: expanded && hasModules ? 1 : 0
    Behavior on progress {
        enabled: drawer.animationDuration > 0
        NumberAnimation {
            duration: drawer.animationDuration
            easing.type: Motion.morph.easing
        }
    }
    // True from the moment `expanded` flips until the slide settles
    readonly property bool transitioning: (expanded && hasModules) ? progress < 1 : progress > 0
    readonly property bool open: progress > 0

    visible: hasModules && progress > 0
    clip: true
    opacity: progress

    implicitWidth: vertical ? inner.implicitWidth : (inner.implicitWidth + spacing) * progress
    implicitHeight: vertical ? (inner.implicitHeight + spacing) * progress : inner.implicitHeight

    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    GridLayout {
        id: inner
        flow: drawer.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: drawer.spacing
        columnSpacing: drawer.spacing

        // Anchored to the end group so the modules slide out of it
        x: drawer.vertical ? 0 : drawer.width - drawer.spacing - width
        y: drawer.vertical ? drawer.height - drawer.spacing - height : 0
        width: drawer.vertical ? drawer.width : implicitWidth
        height: drawer.vertical ? implicitHeight : drawer.height

        BarModuleGroup {
            barRoot: drawer.barRoot
            ids: drawer.ids
            outerRadius: drawer.outerRadius
            innerRadius: drawer.innerRadius
            endConnected: true
            enableShadow: drawer.enableShadow
        }
    }
}
