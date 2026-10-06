pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.theme
import qs.modules.services
import qs.modules.globals
import qs.config

// Look step, "Style" tab: "keep my look" plus every preset (built-in and
// saved). Picking one applies it at once, so the shell behind the wizard
// changes (a preset may reload the shell: the wizard resumes here).
Item {
    id: root

    property OnboardingState wizard

    readonly property var manager: GlobalStates.wallpaperManager
    readonly property string wallpaper: {
        const m = root.manager;
        const p = m ? (m.currentWallpaper || "") : "";
        if (!p)
            return "";
        const src = m.getDisplaySource ? m.getDisplaySource(p) : p;
        return src ? (String(src).indexOf("://") === -1 ? "file://" + src : src) : "";
    }
    readonly property var current: ({
            "position": Config.bar.position,
            "style": Config.bar.layout && Config.bar.layout.style ? Config.bar.layout.style : "classic",
            "frame": Config.bar.frameEnabled === true,
            "roundness": Config.theme.roundness,
            "light": Config.theme.lightMode === true,
            "oled": Config.theme.oledMode === true,
            "font": Config.theme.font
        })
    readonly property var presets: [null].concat(PresetsService.presets || [])

    Component.onCompleted: PresetsService.initialize()

    GridView {
        id: grid
        objectName: "presetGrid"
        anchors.fill: parent
        clip: true
        readonly property int columns: Math.max(2, Math.min(4, Math.floor(width / 230)))
        cellWidth: Math.floor(width / columns)
        cellHeight: Math.round((cellWidth - 14) * 9 / 16) + Math.round(Styling.fontSize(0) * 4.6) + 14
        model: root.presets
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight

            PresetCard {
                anchors.fill: parent
                anchors.margins: 7
                preset: cell.modelData
                wallpaper: root.wallpaper
                current: root.current
                selected: !!root.wizard && (cell.modelData ? cell.modelData.name : "") === root.wizard.chosenPreset
                onPicked: root.wizard.choosePreset(cell.modelData ? cell.modelData.name : "")
            }
        }
    }
}
