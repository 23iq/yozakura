import QtQuick
import qs.modules.services
import qs.modules.components.kit
import "../Ui.js" as Ui

// A kit LineSlider with its value (unit, special values). `moved(value)`
// fires while dragging with the value snapped to `stepSize` (values are
// applied live and previewed by the shell). Arrows / PageUp / PageDown /
// Home / End step it from the keyboard.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property string unit: ""
    property var specialValues: []

    signal moved(real value)

    readonly property real ratio: to > from ? Ui.clamp((value - from) / (to - from), 0, 1) : 0
    readonly property bool dragging: line.pressed

    implicitWidth: 280
    implicitHeight: line.implicitHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.Slider

    function emitValue(v) {
        const snapped = Ui.snap(v, from, to, stepSize);
        if (Math.abs(snapped - value) > 1e-9)
            moved(snapped);
    }

    Keys.onLeftPressed: emitValue(value - stepSize)
    Keys.onRightPressed: emitValue(value + stepSize)
    Keys.onDownPressed: emitValue(value - stepSize)
    Keys.onUpPressed: emitValue(value + stepSize)
    Keys.onPressed: event => {
        const big = stepSize * 10;
        const target = ({
                [Qt.Key_PageUp]: value + big,
                [Qt.Key_PageDown]: value - big,
                [Qt.Key_Home]: from,
                [Qt.Key_End]: to
            })[event.key];
        if (target === undefined)
            return;
        emitValue(target);
        event.accepted = true;
    }

    LineSlider {
        id: line
        anchors.fill: parent
        from: root.from
        to: root.to
        value: root.value
        step: root.stepSize
        showValue: true
        highlighted: root.activeFocus
        valueText: Ui.formatValue(root.value, root.unit, root.specialValues, I18n.t)
        onMoved: v => {
            root.forceActiveFocus();
            root.emitValue(v);
            // LineSlider assigns its own value while dragging: follow ours.
            line.value = Qt.binding(() => root.value);
        }
    }
}
