import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.modules.components.kit
import qs.modules.bar.islandchips

// The idle island's microphone glyph in the bar (MicChipContent): only
// while the default source is muted, plus a transient chip with the label
// for the mic notice (MicrophoneStatus.noticeVisible) on this screen.
// Click toggles the mute. Shown only while the island does not show it
// itself (ShellLayout.homeOf, LayoutModel.js).
BarModuleBase {
    id: root

    moduleKey: "mic"

    readonly property string screenName: root.bar && root.bar.screen ? root.bar.screen.name : ""
    readonly property bool notice: MicrophoneStatus.noticeVisible === true && MicrophoneStatus.noticeScreen === root.screenName
    readonly property bool shown: ShellLayout.homeOf("mic") === "bar" && MicrophoneStatus.available === true && (MicrophoneStatus.muted === true || root.notice)

    visible: root.shown
    contentLength: root.shown ? (root.vertical ? chip.implicitHeight : chip.implicitWidth + (root.flat ? Space.m : Space.l * 1.5)) : 0

    BarModuleSurface {
        id: surface
        module: root
        hovered: hover.hovered
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: Audio.toggleMicMute()
    }

    MicChipContent {
        id: chip
        anchors.centerIn: parent
        vertical: root.vertical
        moduleSize: root.moduleSize
        glyphSize: root.iconSize
        textSize: root.textSize
        textWeight: root.textWeight
        textFont: root.textFont
        ink: surface.foreground
        notice: root.notice
    }

    StyledToolTip {
        show: hover.hovered
        tooltipText: I18n.t(chip.muted ? "bar.mic.tooltip_muted" : "bar.mic.tooltip_live")
    }
}
