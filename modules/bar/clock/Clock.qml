pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.modules.theme
import qs.modules.components
import qs.modules.services

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
    readonly property color fg: root.popupOpen ? buttonBg.item : Colors.overBackground
    readonly property var dayKeys: ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    readonly property string dayAbbrev: I18n.t("calendar.day." + root.dayKeys[root.now.getDay()])
    readonly property int pad: Math.round(24 * root.moduleSize / 36)

    Layout.preferredWidth: vertical ? root.moduleSize : buttonBg.implicitWidth
    Layout.preferredHeight: vertical ? buttonBg.implicitHeight : root.moduleSize

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    StyledRect {
        id: buttonBg
        variant: root.popupOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled && !root.flat
        backgroundOpacity: root.flat && !root.popupOpen ? 0 : -1
        effectSurface: root.flat ? "" : "bar"
        enableBorder: !root.flat || root.popupOpen

        topLeftRadius: root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.endRadius

        implicitWidth: root.vertical ? root.moduleSize : layout.implicitWidth + root.pad
        implicitHeight: root.vertical ? layout.implicitHeight + root.pad : root.moduleSize

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: root.popupOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: parent.radius ?? 0

            Behavior on opacity {
                enabled: Motion.enter.duration > 0
                NumberAnimation {
                    duration: Motion.enter.duration
                    easing.type: Motion.enter.easing
                }
            }
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
                font.pixelSize: root.weatherAvailable ? Styling.fontSize(2) : Config.theme.fontSize
                font.family: Config.theme.font
                font.bold: !root.weatherAvailable
            }

            Separator {
                visible: lead.visible
                vert: !root.vertical
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
            }

            Text {
                visible: root.showDate && !root.vertical
                Layout.alignment: Qt.AlignCenter
                text: "· " + root.dayAbbrev + " " + root.now.getDate()
                color: root.fg
                font.pixelSize: Config.theme.fontSize
                font.family: Config.theme.font
                font.bold: true
            }

            PomodoroIndicator {
                objectName: "pomodoroInline"
                Layout.alignment: Qt.AlignCenter
                style: root.pomodoroStyle
                slot: "inline"
                vertical: root.vertical
                fontSize: Config.theme.fontSize
                fontFamily: Config.theme.font
            }
        }

        PomodoroIndicator {
            objectName: "pomodoroOverlay"
            anchors.fill: parent
            style: root.pomodoroStyle
            slot: "overlay"
            vertical: root.vertical
            fontSize: Config.theme.fontSize
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
