pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.modules.services
import qs.modules.globals
import qs.modules.components.kit
import qs.config

// Look step, "Style" tab: "keep my look" plus every preset (built-in and
// saved). Picking one applies it at once, so the shell behind the wizard
// changes (a preset may reload the shell: the wizard resumes here).
// Keyboard: Tab focuses the grid, arrows move, Enter / Space pick.
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
    readonly property string chosen: root.wizard ? root.wizard.chosenPreset : ""
    readonly property int chosenIndex: Math.max(0, root.presets.findIndex(p => (p ? p.name : "") === root.chosen))

    function pick(index: int) {
        const p = root.presets[index];
        if (index >= 0 && index < root.presets.length && root.wizard)
            root.wizard.choosePreset(p ? p.name : "");
    }

    Component.onCompleted: PresetsService.initialize()

    FontMetrics {
        id: nameLine
        font.family: Type.family("body")
        font.pixelSize: Type.size("body")
    }
    FontMetrics {
        id: descLine
        font.family: Type.family("secondary")
        font.pixelSize: Type.size("secondary")
    }

    GridView {
        id: grid
        objectName: "presetGrid"
        anchors.fill: parent
        clip: true
        readonly property int gap: Space.s
        readonly property int columns: Math.max(2, Math.min(4, Math.floor(width / Space.px(230))))
        cellWidth: Math.floor(width / columns)
        // card padding + 16:9 thumbnail + name + two description lines
        cellHeight: Math.ceil((cellWidth - gap - Space.s * 2) * 9 / 16 + Space.s * 4 + nameLine.height + descLine.height * 2 + gap)
        model: root.presets
        // Not bound to the choice: a pick must not scroll the gallery.
        // Keyboard focus starts on the chosen card.
        activeFocusOnTab: true
        onActiveFocusChanged: if (activeFocus)
            currentIndex = root.chosenIndex
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Keys.onReturnPressed: root.pick(grid.currentIndex)
        Keys.onEnterPressed: root.pick(grid.currentIndex)
        Keys.onSpacePressed: root.pick(grid.currentIndex)

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight

            PresetCard {
                anchors.fill: parent
                anchors.margins: grid.gap / 2
                preset: cell.modelData
                wallpaper: root.wallpaper
                current: root.current
                selected: !!root.wizard && (cell.modelData ? cell.modelData.name : "") === root.chosen
                focused: grid.activeFocus && grid.currentIndex === cell.index
                onPicked: {
                    grid.currentIndex = cell.index;
                    root.pick(cell.index);
                }
            }
        }
    }
}
