import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.globals
import qs.config
import "../widgets/WidgetFormat.js" as WidgetFormat

// The dashboard frame's header row (every tab): the time large with the
// date and the weather beside it on the left; the tabs as labelled chips
// (StageTabs), the bento edit toggle (widgets tab in bento mode only) and
// the settings button on the right. `showClock: false` leaves the time and
// the weather to a hero that shows them large (the idle stage home): the
// date alone leads then.
Item {
    id: root

    property var order: [0, 1, 2]
    property int currentTab: 0
    property bool canEdit: false
    property bool editing: false
    property bool showClock: true
    property date now: new Date()
    readonly property bool use12h: Config.bar.use12hFormat ?? false

    signal navigate(int index)
    signal editToggled

    implicitHeight: Math.max(Space.controlM, clock.implicitHeight)

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Row {
        id: when
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.l * clock.opacity

        // Hands the time to the idle hero and back: folds away, no pop.
        KitText {
            id: clock
            objectName: "clock"
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.showClock ? 1 : 0
            visible: opacity > 0
            width: implicitWidth * clock.opacity
            clip: true
            role: "display"
            font.pixelSize: Math.round(Type.size("display") * 1.2)
            text: Qt.formatTime(root.now, root.use12h ? "h:mm" : "HH:mm")

            Behavior on opacity {
                enabled: Motion.glide.duration > 0
                NumberAnimation {
                    duration: Motion.glide.duration
                    easing.type: Motion.glide.easing
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.xs / 2

            KitText {
                objectName: "date"
                role: root.showClock ? "body" : "title"
                font.weight: Look.labelWeight
                text: Qt.locale(I18n.resolvedLanguage).toString(root.now, "dddd, MMMM d")
            }

            Row {
                objectName: "weather"
                spacing: Space.s
                visible: WeatherService.dataAvailable && root.showClock

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons[WidgetFormat.weatherGlyph(WeatherService.effectiveWeatherCode ?? WeatherService.weatherCode, WeatherService.effectiveIsDay ?? true)] || Icons.sun
                    font.family: Icons.font
                    font.pixelSize: Type.iconSize("secondary")
                    color: Type.secondary
                }

                KitText {
                    objectName: "temperature"
                    anchors.verticalCenter: parent.verticalCenter
                    role: "secondary"
                    tabular: true
                    text: WidgetFormat.temp(WeatherService.currentTemp) + "  " + (WeatherService.effectiveWeatherDescription ?? "")
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.m

        StageTabs {
            anchors.verticalCenter: parent.verticalCenter
            order: root.order
            currentTab: root.currentTab
            onNavigate: index => root.navigate(index)
        }

        IconButton {
            id: edit
            objectName: "bentoEditToggle"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.canEdit
            icon: root.editing ? Icons.check : Icons.pencil
            active: root.editing
            Accessible.name: I18n.t(root.editing ? "bento.done" : "bento.edit")

            StyledToolTip {
                show: edit.hovered
                tooltipText: I18n.t(root.editing ? "bento.done" : "bento.edit")
            }

            onClicked: root.editToggled()
        }

        IconButton {
            objectName: "settingsButton"
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.gear
            active: GlobalStates.settingsWindowVisible
            onClicked: GlobalShortcuts.toggleSettings()
        }
    }
}
