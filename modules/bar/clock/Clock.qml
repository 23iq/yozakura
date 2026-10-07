pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.components.kit
import qs.modules.bar.look

// Bar clock: the weather symbol (or day name), a clock face
// (bar.moduleOptions.clock.face, ClockFaces.js; a vertical bar shows digital
// as stacked) and the running Pomodoro (pomodoroStyle, PomodoroStyles.js).
// Click opens the clock panel (ClockPanel.qml) or the timers hub
// (system.timers.clockClick).
Item {
    id: root

    required property var bar
    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    property int moduleSize: BarMetrics.moduleSize
    property bool flat: false

    property bool popupOpen: clockPopup.isOpen
    property date now: new Date()

    readonly property var options: Config.bar.moduleOptions?.clock ?? ({})
    readonly property bool showDate: Config.bar.clockShowDate ?? false
    readonly property bool use12h: Config.bar.use12hFormat ?? false
    // bar.moduleOptions.clock.showWeather: false leaves the weather to its own module
    readonly property bool weatherAvailable: WeatherService.dataAvailable && root.options.showWeather !== false
    readonly property string pomodoroStyle: root.options.pomodoroStyle ?? "ring"
    readonly property color fg: box.ink
    // Kit type: the module text role, its font and weight (BarLook)
    readonly property int textSize: BarLook.textSize(root.moduleSize)
    readonly property var dayKeys: ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    readonly property string dayAbbrev: I18n.t("calendar.day." + root.dayKeys[root.now.getDay()])
    readonly property int pad: Math.round(24 * root.moduleSize / 36)

    Layout.preferredWidth: vertical ? root.moduleSize : buttonBg.implicitWidth
    Layout.preferredHeight: vertical ? buttonBg.implicitHeight : root.moduleSize

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    Item {
        id: buttonBg

        anchors.fill: parent
        implicitWidth: root.vertical ? root.moduleSize : layout.implicitWidth + root.pad
        implicitHeight: root.vertical ? layout.implicitHeight + root.pad : root.moduleSize

        ModuleBox {
            id: box
            vertical: root.vertical
            startRadius: root.startRadius
            endRadius: root.endRadius
            flat: root.flat
            shadow: root.layerEnabled
            active: root.popupOpen
            hovered: root.isHovered
        }

        GridLayout {
            id: layout
            anchors.centerIn: parent
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.vertical ? -1 : 1
            columns: root.vertical ? 1 : -1
            rowSpacing: Metrics.spacing / 2
            columnSpacing: Metrics.spacing

            Text {
                id: lead
                visible: root.vertical || root.weatherAvailable || !root.showDate
                Layout.alignment: Qt.AlignCenter
                text: root.weatherAvailable ? WeatherService.weatherSymbol : root.dayAbbrev
                color: root.fg
                font.pixelSize: root.weatherAvailable ? BarLook.iconSize(root.moduleSize) : root.textSize
                font.family: BarLook.textFont
                font.weight: BarLook.textWeight
            }

            Divider {
                visible: lead.visible && Look.dividers
                vertical: !root.vertical
                Layout.preferredWidth: root.vertical ? root.textSize : Space.hairline
                Layout.preferredHeight: root.vertical ? Space.hairline : root.textSize
                Layout.alignment: Qt.AlignCenter
            }

            ClockFace {
                objectName: "clockFace"
                Layout.alignment: Qt.AlignCenter
                face: root.options.face ?? "digital"
                vertical: root.vertical
                use12h: root.use12h
                now: root.now
                textColor: root.fg
                fontSize: root.textSize
                fontFamily: BarLook.textFont
                fontWeight: BarLook.textWeight
            }

            Text {
                visible: root.showDate && !root.vertical
                Layout.alignment: Qt.AlignCenter
                text: "· " + root.dayAbbrev + " " + root.now.getDate()
                color: root.fg
                font.pixelSize: root.textSize
                font.family: BarLook.textFont
                font.weight: BarLook.textWeight
                font.features: {
                    "tnum": 1
                }
                // Reserve two-digit day width so 9 -> 10 does not resize the island.
                Layout.minimumWidth: Math.ceil(dateMetrics.advanceWidth)
                TextMetrics {
                    id: dateMetrics
                    font: parent.font
                    text: "· " + root.dayAbbrev + " 00"
                }
            }

            PomodoroIndicator {
                objectName: "pomodoroInline"
                Layout.alignment: Qt.AlignCenter
                style: root.pomodoroStyle
                slot: "inline"
                vertical: root.vertical
                fontSize: root.textSize
                fontFamily: BarLook.textFont
                fontWeight: BarLook.textWeight
            }
        }

        PomodoroIndicator {
            objectName: "pomodoroOverlay"
            anchors.fill: parent
            style: root.pomodoroStyle
            slot: "overlay"
            vertical: root.vertical
            fontSize: root.textSize
        }

        // system.timers.clockClick: the left button opens the clock panel
        // or the notch timers hub, the right button the other one
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                const timersFirst = (Config.system?.timers?.clockClick ?? "popup") === "timers";
                if ((mouse.button === Qt.RightButton) === timersFirst)
                    clockPopup.toggle();
                else
                    TimersService.toggleHub("timer", root.bar?.screen?.name ?? "");
            }
        }
    }

    BarPopup {
        id: clockPopup
        anchorItem: buttonBg
        bar: root.bar
        variant: "transparent"
        popupPadding: 0

        contentWidth: panel.implicitWidth
        contentHeight: panel.implicitHeight

        onIsOpenChanged: {
            if (isOpen && !WeatherService.dataAvailable)
                WeatherService.updateWeather();
        }

        ClockPanel {
            id: panel
            width: implicitWidth
            height: implicitHeight
            now: root.now
            use12h: root.use12h
        }
    }

    PomodoroSync {
        onRequestPanel: clockPopup.open()
    }

    // minute ticks, aligned to the wall clock
    Timer {
        interval: 60000 - (Date.now() % 60000) + 20
        running: !SuspendManager.isSuspending
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date();
            interval = 60000 - (Date.now() % 60000) + 20;
        }
    }
}
