pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.components.kit
import "../Ui.js" as Ui

// The legacy single bar of a preset miniature (PresetMiniShell, used when
// the preset has no bar.panels): islands or a classic strip, workspaces in
// the preset's numeral style, integrated dock apps and the clock. Drawn in
// the preset's palette, font and scale (`shell.c`, `shell.v`, `shell.u`).
Item {
    id: bar

    required property var shell
    readonly property real m: shell.islands && !shell.contained ? shell.gapOut : 0
    readonly property real along: shell.frameThick + m
    readonly property real u: shell.u

    x: shell.edge === "left" ? m : (shell.edge === "right" ? shell.width - shell.barThick - m : along)
    y: shell.edge === "top" ? m : (shell.edge === "bottom" ? shell.height - shell.barThick - m : along)
    width: shell.vertical ? shell.barThick : shell.width - 2 * along
    height: shell.vertical ? shell.height - 2 * along : shell.barThick

    // Islands: three floating groups
    Repeater {
        model: bar.shell.islands ? 3 : 0
        Rectangle {
            required property int index
            readonly property real len: [0.26, 0.16, 0.2][index] * (bar.shell.vertical ? bar.height : bar.width)
            readonly property real pos: index === 0 ? 0 : (index === 1 ? ((bar.shell.vertical ? bar.height : bar.width) - len) / 2 : (bar.shell.vertical ? bar.height : bar.width) - len)
            x: bar.shell.vertical ? 4 * bar.u : pos
            y: bar.shell.vertical ? pos : 4 * bar.u
            width: bar.shell.vertical ? bar.width - 8 * bar.u : len
            height: bar.shell.vertical ? len : bar.height - 8 * bar.u
            radius: Math.min(bar.shell.radius, Math.min(width, height) / 2)
            color: bar.shell.contained ? Ui.alpha(bar.shell.c("surfaceContainer"), 0.9) : bar.shell.chrome
        }
    }

    // Workspaces
    Grid {
        id: ws
        readonly property string style: bar.shell.v("workspaces.numeralStyle", "arabic")
        readonly property var glyphs: style === "roman" ? ["I", "II", "III", "IV"] : (style === "kanji" ? ["一", "二", "三", "四"] : ["1", "2", "3", "4"])
        columns: bar.shell.vertical ? 1 : 4
        spacing: 6 * bar.u
        x: bar.shell.vertical ? (bar.width - width) / 2 : 14 * bar.u
        y: bar.shell.vertical ? 14 * bar.u : (bar.height - height) / 2
        Repeater {
            model: 4
            Rectangle {
                id: wsCell
                required property int index
                width: index === 0 && !bar.shell.vertical ? 30 * bar.u : 18 * bar.u
                height: index === 0 && bar.shell.vertical ? 30 * bar.u : 18 * bar.u
                radius: Math.min(bar.shell.radius, height / 2)
                color: index === 0 ? bar.shell.c("primary") : "transparent"
                KitText {
                    anchors.centerIn: parent
                    text: ws.glyphs[wsCell.index]
                    font.family: bar.shell.v("theme.font", "")
                    font.pixelSize: Math.max(1, 11 * bar.u)
                    font.weight: Font.Bold
                    color: wsCell.index === 0 ? bar.shell.c("overPrimary") : bar.shell.c("overSurfaceVariant")
                }
            }
        }
    }

    // Integrated dock apps
    Row {
        visible: bar.shell.dockOn && bar.shell.dockTheme === "integrated" && !bar.shell.vertical
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: bar.width * 0.18
        spacing: 5 * bar.u
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: 18 * bar.u
                height: width
                radius: Math.min(bar.shell.radius * 0.6, width / 2)
                color: [bar.shell.c("primary"), bar.shell.c("tertiary"), bar.shell.c("secondary"), bar.shell.c("primaryContainer")][index]
            }
        }
    }

    // Clock
    KitText {
        visible: !bar.shell.vertical
        anchors.right: parent.right
        anchors.rightMargin: 16 * bar.u
        anchors.verticalCenter: parent.verticalCenter
        text: "21:47"
        tabular: true
        font.family: bar.shell.v("theme.font", "")
        font.pixelSize: Math.max(1, 15 * bar.u)
        font.weight: Font.DemiBold
        color: bar.shell.c("overBackground")
    }
    Rectangle {
        visible: bar.shell.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14 * bar.u
        width: 18 * bar.u
        height: 18 * bar.u
        radius: width / 2
        color: bar.shell.c("primary")
    }
}
