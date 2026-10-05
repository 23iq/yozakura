pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.settings.controls
import qs.modules.settings.previews
import qs.modules.settings.store
import qs.config
import "../Ui.js" as Ui
import "../../../config/motion/MotionProfiles.js" as MotionProfiles
import "../../../config/motion/MotionSpec.js" as MotionSpec

// Motion profile picker (compositor.motionProfile): one card per profile of
// config/motion, each looping a mini window that pops in and out with the
// profile's own windowsIn/windowsOut + fade curves, speeds and styles.
Item {
    id: root

    property var entry
    readonly property string current: SettingsStore.get("compositor.motionProfile") || MotionProfiles.DEFAULT_ID
    readonly property real durationScale: Number(SettingsStore.get("compositor.motionDurationScale")) || 1
    readonly property int columns: width < 520 ? 2 : (width < 760 ? 3 : 4)

    implicitHeight: grid.implicitHeight

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: 12

        Repeater {
            model: MotionProfiles.all()

            delegate: ChoiceCard {
                id: card
                required property var modelData
                required property int index
                objectName: "motionCard:" + modelData.id
                width: (grid.width - grid.spacing * (root.columns - 1)) / root.columns
                previewHeight: Math.round(width * 0.62)
                selected: root.current === modelData.id
                icon: modelData.icon
                title: I18n.t(modelData.label)
                subtitle: I18n.t(modelData.description)
                onClicked: SettingsStore.set("compositor.motionProfile", modelData.id)

                MotionCardPreview {
                    anchors.fill: parent
                    spec: MotionSpec.resolve({
                        "profile": card.modelData.id,
                        "durationScale": root.durationScale
                    })
                    delay: card.index * 140
                }
            }
        }
    }

    component MotionCardPreview: Item {
        id: mini

        property var spec
        property int delay: 0
        // Linear clocks of the in/out phases; the curves shape them.
        property real tIn: 0
        property real tOut: 0
        property bool leaving: false

        readonly property bool animated: spec.enabled && mini.visible
        readonly property var aIn: MotionSpec.animation(spec, "windowsIn")
        readonly property var aOut: MotionSpec.animation(spec, "windowsOut")
        readonly property var fIn: MotionSpec.animation(spec, "fadeIn")
        readonly property var fOut: MotionSpec.animation(spec, "fadeOut")
        readonly property int msIn: aIn ? Math.max(60, aIn.speed * 100) : 300
        readonly property int msOut: aOut ? Math.max(60, aOut.speed * 100) : 300

        function shaped(a, t, ms) {
            return a ? MotionSpec.curveAt(MotionSpec.curveNamed(mini.spec, a.curve), t, ms / 1000) : t;
        }

        readonly property real moveIn: shaped(aIn, tIn, msIn)
        readonly property real moveOut: shaped(aOut, tOut, msOut)
        readonly property real fadeIn: Math.max(0, Math.min(1, shaped(fIn, tIn, fIn ? fIn.speed * 100 : msIn)))
        readonly property real fadeOut: Math.max(0, Math.min(1, shaped(fOut, tOut, fOut ? fOut.speed * 100 : msOut)))
        readonly property real s0In: aIn ? MotionSpec.popinScale(aIn.style) : 1
        readonly property real s0Out: aOut ? MotionSpec.popinScale(aOut.style) : 1

        ScreenBackdrop {
            anchors.fill: parent
        }

        Rectangle {
            id: window
            width: parent.width * 0.56
            height: parent.height * 0.56
            anchors.centerIn: parent
            radius: Math.min(Styling.radius(0), 10)
            color: Colors.surfaceContainerHigh
            border.width: 2
            border.color: Colors.primary
            transformOrigin: Item.Center
            scale: !mini.spec.enabled ? 1 : (mini.leaving ? 1 - (1 - mini.s0Out) * mini.moveOut : mini.s0In + (1 - mini.s0In) * mini.moveIn)
            opacity: !mini.spec.enabled ? 1 : (mini.leaving ? 1 - mini.fadeOut : mini.fadeIn)

            Column {
                x: 8
                y: 8
                spacing: 4
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: window.width * (0.7 - index * 0.18)
                        height: 4
                        radius: 2
                        color: Ui.alpha(Colors.overBackground, 0.25)
                    }
                }
            }
        }

        SequentialAnimation {
            running: mini.animated
            loops: Animation.Infinite
            onRunningChanged: if (!running) {
                mini.leaving = false;
                mini.tIn = 1;
            }
            ScriptAction {
                script: {
                    mini.leaving = false;
                    mini.tIn = 0;
                }
            }
            PauseAnimation {
                duration: 120 + mini.delay / 2
            }
            NumberAnimation {
                target: mini
                property: "tIn"
                from: 0
                to: 1
                duration: mini.msIn
            }
            PauseAnimation {
                duration: 1400
            }
            ScriptAction {
                script: {
                    mini.tOut = 0;
                    mini.leaving = true;
                }
            }
            NumberAnimation {
                target: mini
                property: "tOut"
                from: 0
                to: 1
                duration: mini.msOut
            }
            PauseAnimation {
                duration: 200 + Math.max(0, 450 - mini.delay / 2)
            }
        }

        Rectangle {
            visible: !mini.spec.enabled
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            width: offText.implicitWidth + 12
            height: 18
            radius: 9
            color: Ui.alpha(Colors.surfaceContainerLowest, 0.8)
            Text {
                id: offText
                anchors.centerIn: parent
                text: I18n.t("prefs.common.off")
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-4)
                color: Colors.overSurfaceVariant
            }
        }
    }
}
