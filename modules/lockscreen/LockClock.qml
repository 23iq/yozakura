pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.theme
import qs.config

// Glass style clock: heavy digits with a rolling transition, an accent
// colon and the date below.
Item {
    id: root

    property real pixelSize: 200
    property date now: new Date()
    property color digitColor: Colors.secondaryFixed
    property color dateColor: digitColor
    property color colonColor: Colors.primaryFixedDim
    // Drop shadow (dark tone) or soft halo (light tone) behind the digits.
    property color shadowColor: Colors.shadow
    property real shadowOpacity: 0.7

    readonly property bool use12h: Config.bar?.use12hFormat ?? false
    readonly property int hours24: now.getHours()
    readonly property string hoursText: use12h ? String(hours24 % 12 || 12) : (hours24 < 10 ? "0" : "") + hours24
    readonly property string minutesText: (now.getMinutes() < 10 ? "0" : "") + now.getMinutes()

    readonly property font digitFont: fontSource.font

    // Font holder: variable fonts (e.g. Google Sans Flex) only reach the
    // heaviest instance through the wght axis, so set both weight and axis.
    Text {
        id: fontSource
        visible: false
        font.family: Config.theme.font
        font.pixelSize: Math.round(root.pixelSize)
        font.weight: Font.Black
        font.variableAxes: ({
                "wght": 900
            })
        font.features: ({
                "tnum": 1
            })
    }

    // The heavy glyphs sit well inside the font's line box; trim the empty
    // descent so the date tucks right under the digits.
    readonly property real digitTrim: Math.round(fontMetrics.descent * 0.9)
    // Tabular figures keep every digit as wide as "0"; the fixed cell stops
    // the clock from shifting when a narrow "1" rolls in.
    readonly property real cellWidth: Math.ceil(zeroMetrics.advanceWidth)
    readonly property real cellHeight: fontMetrics.height

    implicitWidth: Math.max(digits.width, dateLabel.implicitWidth)
    implicitHeight: digits.height - digitTrim + dateLabel.implicitHeight

    FontMetrics {
        id: fontMetrics
        font: root.digitFont
    }

    TextMetrics {
        id: zeroMetrics
        font: root.digitFont
        text: "0"
    }

    Item {
        id: clockLayer
        anchors.fill: parent

        // Soft drop shadow keeps the white digits readable on bright art.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.shadowColor
            shadowOpacity: root.shadowOpacity
            shadowBlur: 1.0
            shadowVerticalOffset: 2
            blurMax: 48
        }

        Row {
            id: digits
            anchors.horizontalCenter: parent.horizontalCenter
            // Tabular cells are generous; pull the digits together.
            spacing: -Math.round(root.pixelSize * 0.03)

            LockDigit {
                font: root.digitFont
                color: root.digitColor
                cellWidth: root.cellWidth
                value: root.hoursText.length > 1 ? root.hoursText.charAt(0) : ""
                visible: root.hoursText.length > 1
            }
            LockDigit {
                font: root.digitFont
                color: root.digitColor
                cellWidth: root.cellWidth
                value: root.hoursText.charAt(root.hoursText.length - 1)
            }

            // The only accent on the clock: a primary colon.
            Text {
                id: colon
                text: ":"
                font.family: Config.theme.font
                font.pixelSize: Math.round(root.pixelSize * 0.9)
                font.weight: Font.Bold
                font.variableAxes: ({
                        "wght": 700
                    })
                color: root.colonColor
                renderType: Text.QtRendering
                leftPadding: Math.round(root.pixelSize * 0.05)
                rightPadding: Math.round(root.pixelSize * 0.05)
                y: Math.round((root.cellHeight - height) / 2 - root.pixelSize * 0.04)
            }

            LockDigit {
                font: root.digitFont
                color: root.digitColor
                cellWidth: root.cellWidth
                value: root.minutesText.charAt(0)
            }
            LockDigit {
                font: root.digitFont
                color: root.digitColor
                cellWidth: root.cellWidth
                value: root.minutesText.charAt(1)
            }

            Text {
                visible: root.use12h
                text: root.hours24 < 12 ? "AM" : "PM"
                font.family: Config.theme.font
                font.pixelSize: Math.round(root.pixelSize * 0.16)
                font.weight: Font.Bold
                font.letterSpacing: 1
                color: root.digitColor
                opacity: 0.8
                leftPadding: Math.round(root.pixelSize * 0.06)
                y: Math.round(root.pixelSize * 0.3)
            }
        }

        Text {
            id: dateLabel
            anchors.horizontalCenter: parent.horizontalCenter
            y: digits.height - root.digitTrim
            text: root.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            font.family: Config.theme.font
            font.pixelSize: Math.max(16, Math.round(root.pixelSize * 0.13))
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
            color: root.dateColor
            opacity: 0.88
        }
    }
}
