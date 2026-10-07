pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components.kit
import qs.modules.widgets.powermenu
import "../PowerActions.js" as PowerActions

// layout.powermenu.style "fullscreen": over a dimmed screen, centered in
// the work area, a quiet caption (uptime · user@host, when readable), a row
// of large round actions with their labels and a hint line: the focused
// destructive action asks to be held ("Hold to shut down"), its ring fills
// while held. Arrows/Tab move, Enter fires, Escape or a click on the
// backdrop closes.
FocusScope {
    id: root

    property point cursor
    property var area: null
    property bool shown: false
    property int currentIndex: 0
    readonly property var current: power.items[root.currentIndex] || null
    // Hero sizes on large screens (PowerActions.heroScale)
    readonly property var hero: PowerActions.heroScale(root.height)

    signal closeRequested

    property real progress: shown ? 1 : 0
    Behavior on progress {
        enabled: Motion.enter.duration > 0
        NumberAnimation {
            duration: root.shown ? Motion.enter.duration : Motion.exit.duration
            easing.type: root.shown ? Motion.enter.easing : Motion.exit.easing
        }
    }

    function focusAt(i) {
        const n = actions.count;
        if (n === 0)
            return;
        root.currentIndex = (i + n) % n;
        actions.itemAt(root.currentIndex).forceActiveFocus();
    }

    function cancelHolds() {
        for (let i = 0; i < actions.count; i++) {
            const action = actions.itemAt(i) as ActionButton;
            if (action)
                action.release();
        }
    }

    onCloseRequested: root.cancelHolds()
    onShownChanged: {
        if (!shown)
            root.cancelHolds();
        if (shown)
            power.refresh();
    }
    onActiveFocusChanged: {
        if (activeFocus)
            Qt.callLater(() => root.focusAt(root.currentIndex));
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
            root.focusAt(root.currentIndex + 1);
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
            root.focusAt(root.currentIndex - 1);
        else if (event.key === Qt.Key_Escape)
            root.closeRequested();
        else
            return;
        event.accepted = true;
    }

    PowerMenuModel {
        id: power
        objectName: "powerModel"
        onDone: root.closeRequested()
    }

    Rectangle {
        anchors.fill: parent
        color: Colors.background
        opacity: 0.72 * root.progress

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Column {
        id: content
        readonly property var box: root.area || {
            "x": 0,
            "y": 0,
            "w": root.width,
            "h": root.height
        }
        x: box.x + (box.w - width) / 2
        y: box.y + (box.h - height) / 2
        spacing: Space.xxl
        opacity: root.progress
        scale: 0.96 + 0.04 * root.progress

        KitText {
            objectName: "powerCaption"
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            role: root.hero.caption
            text: power.caption
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Space.xxl

            Repeater {
                id: actions
                model: power.items

                delegate: ActionButton {
                    required property var modelData
                    required property int index
                    width: button.width + (root.hero.size === "xl" ? Space.xxl * 2 : Space.xl)
                    size: root.hero.size
                    showLabel: true
                    labelRole: root.hero.label
                    icon: modelData.icon
                    text: modelData.label
                    confirm: modelData.confirm
                    onEntered: root.focusAt(index)
                    onActivated: power.run(index)
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Space.s

            KitText {
                objectName: "powerHint"
                anchors.verticalCenter: parent.verticalCenter
                role: root.hero.caption
                color: root.current && root.current.confirm ? Type.secondary : Type.muted
                text: root.current && root.current.hold ? root.current.hold : I18n.t("powermenu.hold_hint")
            }
            KeyHint {
                anchors.verticalCenter: parent.verticalCenter
                text: "Esc"
            }
        }
    }
}
