pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.config
import qs.modules.components.kit
import "../Ui.js" as Ui
import "ColorRoleModel.js" as Model

// `color-role` control: palette-role swatches of the live palette, an alpha
// slider and (for gradient keys) up to four gradient stops. Values are
// color specs (role, literal, "role@alpha"), so they follow the wallpaper.
// `edited(value)` fires with a string (single color) or a list (gradient).
Item {
    id: root

    property var value
    property bool gradient: false
    property int maxStops: Model.MAX_STOPS
    property int selected: 0
    signal edited(var value)

    readonly property var stops: {
        const s = Model.toStops(root.value);
        return s.length > 0 ? s : ["primary"];
    }
    readonly property int current: Math.min(root.selected, root.stops.length - 1)
    readonly property string currentSpec: root.stops[root.current]

    implicitWidth: 420
    implicitHeight: column.implicitHeight

    function resolve(spec) {
        const role = Model.roleOf(spec);
        const base = Colors[role] !== undefined ? Colors[role] : Qt.color(role);
        return Ui.alpha(base, Model.alphaOf(spec));
    }

    function commit(stops) {
        root.edited(Model.fromStops(stops, root.gradient));
    }

    Column {
        id: column
        width: parent.width
        spacing: 12

        // Stops: a strip showing the gradient, one chip per stop.
        Row {
            width: parent.width
            spacing: 10
            visible: root.gradient

            Item {
                width: parent.width - stopButtons.width - 10
                height: 30

                // One two-stop segment per pair of stops (a single color fills it).
                Row {
                    id: strip
                    x: 11
                    y: 11
                    width: parent.width - 22
                    height: 8
                    Repeater {
                        model: Math.max(1, root.stops.length - 1)
                        delegate: Rectangle {
                            id: seg
                            required property int index
                            width: strip.width / Math.max(1, root.stops.length - 1)
                            height: strip.height
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0
                                    color: root.resolve(root.stops[seg.index])
                                }
                                GradientStop {
                                    position: 1
                                    color: root.resolve(root.stops[Math.min(seg.index + 1, root.stops.length - 1)])
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: root.stops.length
                    delegate: Rectangle {
                        id: chip
                        required property int index
                        readonly property bool isCurrent: index === root.current
                        width: 22
                        height: 22
                        radius: 11
                        y: 4
                        x: root.stops.length > 1 ? 4 + index * (parent.width - 30) / (root.stops.length - 1) : 4
                        color: root.resolve(root.stops[index])
                        border.width: isCurrent ? 3 : 2
                        border.color: isCurrent ? Colors.overBackground : Ui.alpha(Colors.background, 0.8)
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: I18n.t("prefs.color_role.stop") + " " + (index + 1)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selected = chip.index
                        }
                    }
                }
            }

            Row {
                id: stopButtons
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: [
                        {
                            "icon": "plus",
                            "add": true
                        },
                        {
                            "icon": "minus",
                            "add": false
                        }
                    ]
                    delegate: IconButton {
                        id: btn
                        required property var modelData
                        readonly property bool usable: modelData.add ? root.stops.length < root.maxStops : root.stops.length > 1
                        size: "s"
                        icon: Icons[btn.modelData.icon]
                        enabled: btn.usable
                        onClicked: {
                            if (btn.modelData.add) {
                                root.commit(Model.addStop(root.stops, root.current, root.maxStops));
                                root.selected = root.current + 1;
                            } else {
                                root.commit(Model.removeStop(root.stops, root.current));
                                root.selected = Math.max(0, root.current - 1);
                            }
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.t(btn.modelData.add ? "prefs.color_role.add_stop" : "prefs.color_role.remove_stop")
                    }
                }
            }
        }

        // Palette swatches for the selected stop, in evenly filled rows.
        Grid {
            id: swatches
            readonly property int fit: Math.max(1, Math.floor((parent.width + spacing) / (28 + spacing)))
            width: parent.width
            spacing: 6
            columns: Math.ceil(Model.ROLES.length / Math.ceil(Model.ROLES.length / fit))

            Repeater {
                model: Model.ROLES
                delegate: Rectangle {
                    id: swatch
                    required property string modelData
                    readonly property bool picked: Model.roleOf(root.currentSpec) === modelData
                    width: 28
                    height: 28
                    radius: 8
                    color: Colors[modelData] ?? "transparent"
                    border.width: picked ? 2 : 1
                    border.color: picked ? Colors.overBackground : Ui.alpha(Colors.outlineVariant, 0.9)
                    scale: swatchArea.containsMouse ? 1.08 : 1
                    Behavior on scale {
                        enabled: Config.animDuration > 0
                        NumberAnimation {
                            duration: Motion.exit.duration
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: swatch.picked
                        text: Icons.accept
                        font.family: Icons.font
                        font.pixelSize: 12
                        color: Colors.background
                    }
                    MouseArea {
                        id: swatchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.commit(Model.setRole(root.stops, root.current, swatch.modelData))
                    }
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: swatch.modelData
                    Accessible.checked: swatch.picked
                }
            }
        }

        Row {
            width: parent.width
            spacing: 12

            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                text: I18n.t("prefs.color_role.alpha")
            }
            SliderControl {
                width: parent.width - x
                value: Math.round(Model.alphaOf(root.currentSpec) * 100)
                from: 0
                to: 100
                stepSize: 5
                unit: "%"
                onMoved: v => root.commit(Model.setAlpha(root.stops, root.current, v / 100))
            }
        }
    }
}
