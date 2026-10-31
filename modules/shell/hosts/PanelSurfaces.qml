pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.modules.services
import qs.modules.shell.hosts
import qs.modules.widgets.defaultview.panels
import "../../widgets/defaultview/panels/NotchPanels.js" as NotchPanels

// Per-screen owner of the notch's auto panels (voice input, timers hub,
// ringing alarm; NotchPanels.js `auto`) while layout.panels.host resolves
// off the notch (HostRouter.panelsHost "card"; the notch off makes "auto"
// do that). Same rules as the notch (NotchPanelController): the first
// available auto panel opens by itself, a dismissed one (Esc, click outside)
// stays closed until its content goes away, and the services keep the
// state: TimersService.openHub / VoiceService.openPanel open them wherever
// they are hosted. The panel is created on open and unloaded once the card
// glided out.
Scope {
    id: root

    required property ShellScreen screen
    readonly property string screenName: root.screen ? root.screen.name : ""
    readonly property bool active: (HostRouter.panelsHost ?? "notch") !== "notch"
    // { voice, timerHub, alarm } on this screen; nothing while the notch hosts them
    readonly property var available: root.active ? NotchPanels.autoContext({
        "screen": root.screenName,
        "voiceOpen": VoiceService.panelOpen,
        "voiceScreen": VoiceService.panelScreen,
        "hubOpen": TimersService.hubOpen,
        "hubScreen": TimersService.hubScreen,
        "ringing": TimersService.ringing,
        "alarmPanel": Config.system?.timers?.alarmPanel,
        "alarmRepeat": Config.system?.timers?.alarmRepeat,
        "alarmScreen": TimersService.alarmScreen
    }) : ({})
    property string dismissedId: ""
    // The auto panel that should be open ("" when none)
    readonly property string panelId: NotchPanels.autoPanel(root.available, root.dismissedId)
    // The panel loaded in the card (kept while the card closes)
    property string shownId: ""

    // For tests and callers
    readonly property CardHost card: cardLoader.item as CardHost
    readonly property NotchPanel panel: panelLoader.item as NotchPanel

    onAvailableChanged: {
        if (root.dismissedId !== "" && !root.available[root.dismissedId])
            root.dismissedId = "";
    }
    onPanelIdChanged: root.route()
    Component.onCompleted: root.route()

    function route() {
        if (root.panelId === "") {
            if (root.card && root.card.isOpen)
                root.card.close();
            else if (!root.card || root.card.progress === 0)
                root.shownId = "";
            return;
        }
        cardLoader.active = true;
        if (root.shownId === root.panelId && root.panel)
            root.openCard();
        else
            root.shownId = root.panelId;
    }

    function openCard() {
        const card = root.card;
        if (!card || !root.panel || root.panelId === "" || root.shownId !== root.panelId)
            return;
        card.modal = NotchPanels.isModal(root.shownId);
        card.preferredWidth = NotchPanels.widthFor(root.shownId, Config.notch?.expandedMediaWidth ?? 440);
        card.open(root.panel, root.screen);
    }

    // Esc, click outside, or the panel asked (closeRequested): like the
    // notch's controller, the panel hears dismissed() while its content is
    // still there, and the auto panel stays closed until it goes away
    function dismiss() {
        const id = root.panelId;
        if (id === "")
            return;
        if (root.available[id] && root.panel)
            root.panel.dismissed();
        if (root.available[id])
            root.dismissedId = id;
    }

    Loader {
        id: panelLoader
        active: root.shownId !== ""
        source: {
            const entry = NotchPanels.byId(root.shownId);
            return entry ? Qt.resolvedUrl("../../widgets/defaultview/panels/" + entry.url) : "";
        }
        onLoaded: {
            const p = root.panel;
            if (!p)
                return;
            p.visible = false;
            p.screenName = Qt.binding(() => root.screenName);
            p.revealed = Qt.binding(() => !!root.card && root.card.isOpen);
            const entry = NotchPanels.byId(root.shownId);
            p.maxRows = entry ? entry.maxRows || 0 : 0;
            p.closeRequested.connect(root.dismiss);
            root.openCard();
        }
    }

    Loader {
        id: cardLoader
        active: false
        sourceComponent: Component {
            CardHost {
                screen: root.screen
                onRequestClose: root.dismiss()
                onHostClosed: {
                    if (root.panelId === "")
                        root.shownId = "";
                }
            }
        }
    }
}
