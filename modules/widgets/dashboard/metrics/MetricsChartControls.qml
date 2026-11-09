pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import "MetricsModel.js" as MetricsModel

// Under the chart: the zoom slider between its zoom-out / zoom-in glyphs,
// and the refresh interval stepper (100 ms steps, saved in the state).
RowLayout {
    id: root

    property real zoom: 1

    // A new zoom from the slider (one decimal).
    signal zoomMoved(real zoom)

    function stepInterval(delta: int) {
        const ms = MetricsModel.stepInterval(SystemResources.updateInterval, delta);
        SystemResources.updateInterval = ms;
        StateService.set("metricsRefreshInterval", ms);
    }

    implicitHeight: Space.controlS
    spacing: Space.s

    Icon {
        icon: Icons.glassMinus
        role: "body"
        tone: "secondary"
    }

    LineSlider {
        id: zoomSlider
        objectName: "zoomSlider"
        Layout.fillWidth: true
        from: 0.2
        to: 3.0
        step: 0.1
        onMoved: v => root.zoomMoved(Math.round(v * 10) / 10)

        Binding {
            target: zoomSlider
            property: "value"
            value: root.zoom || 1
            when: !zoomSlider.pressed
        }
    }

    Icon {
        icon: Icons.glassPlus
        role: "body"
        tone: "secondary"
    }

    Divider {
        Layout.preferredHeight: Type.iconSize("body")
        vertical: true
    }

    IconButton {
        objectName: "intervalDown"
        size: "s"
        icon: Icons.minus
        onClicked: root.stepInterval(-1)
    }

    KitText {
        objectName: "intervalText"
        role: "body"
        tabular: true
        font.weight: Font.DemiBold
        text: `${SystemResources.updateInterval}ms`
    }

    IconButton {
        objectName: "intervalUp"
        size: "s"
        icon: Icons.plus
        onClicked: root.stepInterval(1)
    }
}
