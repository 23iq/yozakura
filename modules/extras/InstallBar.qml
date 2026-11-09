import QtQuick
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import qs.modules.components.kit
import "ExtrasModel.js" as ExtrasModel
import "ExtrasUi.js" as Ui

// Sticky bottom bar of the catalog: what is installing right now (mini
// progress, "+2 queued") and the "Install 3 apps · 1.3 GB" button for the
// grid selection. Slides in while there is a selection or a running job.
StyledRect {
    id: root

    property var selected: ({})
    signal clearRequested

    readonly property var ids: ExtrasModel.selectedIds(ExtrasService.catalog, ExtrasService.status, ExtrasService.progress, root.selected)
    readonly property string size: ExtrasModel.selectionSize(ExtrasService.catalog ? ExtrasService.catalog.entries : [], root.selectedMap)
    readonly property var selectedMap: {
        const m = {};
        root.ids.forEach(id => m[id] = true);
        return m;
    }
    readonly property var jobs: ExtrasService.activeJobs
    readonly property var current: root.jobs.length > 0 ? root.jobs[0] : null
    readonly property bool shown: root.ids.length > 0 || root.jobs.length > 0

    function jobName(p) {
        if (!p)
            return "";
        const names = (p.entries || []).map(id => ExtrasService.displayName(id));
        if (names.length > 0)
            return names.join(", ");
        return I18n.t("extras.ui.job." + p.kind);
    }

    function install() {
        if (root.ids.length > 0 && !ExtrasService.offline)
            ExtrasService.install(root.ids, false);
    }

    variant: "popup"
    // opaque: cards scroll underneath
    backgroundOpacity: 1
    radius: Look.radius("surface")
    enableShadow: true
    implicitHeight: Space.controlL
    visible: opacity > 0
    opacity: root.shown ? 1 : 0
    Behavior on opacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Motion.enter.duration
        }
    }
    transform: Translate {
        y: root.shown ? 0 : Space.xl
        Behavior on y {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Motion.morph.duration
                easing.type: Motion.morph.easing
            }
        }
    }

    // solid base under the (possibly translucent) popup fill: card text
    // scrolling underneath never shows through
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 1)
        z: -1
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: Space.hairline
        border.color: Ui.alpha(Colors.outlineVariant, 0.6)
        z: 10
    }

    // Running job summary
    Item {
        id: summary
        x: Space.xl
        width: parent.width - Space.xl - Space.l - (actions.visible ? actions.width + Space.m : 0)
        anchors.verticalCenter: parent.verticalCenter
        height: Space.chip

        Column {
            visible: !!root.current
            width: parent.width
            spacing: Space.s

            Row {
                width: parent.width
                spacing: Space.s
                KitText {
                    id: jobLabel
                    objectName: "jobLabel"
                    width: Math.min(implicitWidth, parent.width - (more.visible ? more.implicitWidth + Space.s : 0))
                    role: "secondary"
                    color: Type.text
                    font.weight: Look.activeLabelWeight
                    text: {
                        const p = root.current;
                        if (!p)
                            return "";
                        const pct = p.state === "running" && p.percent >= 0 ? " · " + p.percent + "%" : "";
                        return I18n.t(p.state === "running" ? "extras.ui.jobs.running" : "extras.ui.jobs.waiting", root.jobName(p)) + pct;
                    }
                }
                KitText {
                    id: more
                    visible: root.jobs.length > 1
                    role: "secondary"
                    text: I18n.tn("extras.ui.jobs.more", root.jobs.length - 1)
                }
            }
            ProgressTrack {
                width: Math.min(parent.width, 320)
                percent: root.current && root.current.state === "running" ? root.current.percent : -1
            }
        }

        Row {
            visible: !root.current
            anchors.verticalCenter: parent.verticalCenter
            spacing: Space.s
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Icons.packageBox
                role: "title"
                tone: "secondary"
            }
            KitText {
                anchors.verticalCenter: parent.verticalCenter
                role: "secondary"
                text: I18n.tn("extras.ui.selected_n", root.ids.length)
            }
        }
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: Space.m
        anchors.verticalCenter: parent.verticalCenter
        spacing: Space.s
        visible: root.ids.length > 0

        ExtrasButton {
            objectName: "clearButton"
            kind: "ghost"
            text: I18n.t("extras.ui.clear")
            onClicked: root.clearRequested()
        }
        ExtrasButton {
            objectName: "installButton"
            kind: "filled"
            iconName: "downloadSimple"
            enabled: !ExtrasService.offline
            text: I18n.tn("extras.ui.install_n", root.ids.length) + (root.size !== "" ? "  ·  " + root.size : "")
            onClicked: root.install()
        }
    }
}
