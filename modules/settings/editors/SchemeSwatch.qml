import QtQuick
import qs.modules.theme
import qs.modules.settings.store
import qs.modules.components.kit

// Preview of one matugen scheme (SchemeGallery): a mini surface with the
// palette's key roles, "Aa" on the primary. The colors are the previewed
// palette (`colorMap`, data); a quiet shimmer while palettes load.
Item {
    id: strip

    property var colorMap: null
    readonly property bool ready: colorMap !== null
    readonly property int inset: Space.xs + 1

    function c(role, fallback) {
        return colorMap && colorMap[role] ? colorMap[role] : fallback;
    }

    Rectangle {
        anchors.fill: parent
        radius: Look.chipRadius(height)
        color: strip.c("surfaceContainer", Type.placeholder)
        clip: true

        Rectangle {
            anchors.fill: parent
            visible: !strip.ready
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Type.placeholder
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
            SequentialAnimation on x {
                running: !strip.ready && SchemePreviews.loading
                loops: Animation.Infinite
                NumberAnimation {
                    from: -strip.width
                    to: strip.width
                    duration: 1100
                }
            }
        }

        Rectangle {
            id: hero
            visible: strip.ready
            x: strip.inset
            y: strip.inset
            width: (parent.width - strip.inset * 3) * 0.6
            height: parent.height - strip.inset * 2
            radius: Space.smallRadius
            color: strip.c("primary", "transparent")

            KitText {
                anchors.left: parent.left
                anchors.leftMargin: Space.s
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Space.xs
                role: "title"
                text: "Aa"
                color: strip.c("overPrimary", "transparent")
            }
        }

        Column {
            visible: strip.ready
            anchors.left: hero.right
            anchors.leftMargin: strip.inset
            anchors.right: parent.right
            anchors.rightMargin: strip.inset
            y: strip.inset
            spacing: Space.xs

            Repeater {
                model: ["secondaryContainer", "tertiary", "surfaceContainerHighest"]
                Rectangle {
                    required property string modelData
                    width: parent.width
                    height: (strip.height - strip.inset * 2 - Space.xs * 2) / 3
                    radius: Space.clampRadius(Space.smallRadius, height)
                    color: strip.c(modelData, "transparent")
                }
            }
        }
    }
}
