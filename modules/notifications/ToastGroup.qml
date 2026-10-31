import QtQuick
import qs.modules.services
import "ToastModel.js" as ToastModel

// What one popup group (one app, or one notification when
// notifications.groupByApp is off) shows and does, shared by the corner
// toasts (CornerToast.qml) and the strips (strips/Strip.qml): the latest
// notification and the count behind it, dismiss, activate, invoke an action
// and pause the group's timers while the pointer holds it. It keeps the last
// non-empty group so the content stays while a remove animation runs.
QtObject {
    id: root

    property var group: null
    property var held: null
    onGroupChanged: if (group)
        held = group
    readonly property var notifications: root.held ? ToastModel.visible(root.held.notifications) : []
    readonly property var latest: ToastModel.latest(root.notifications)
    readonly property int extra: Math.max(0, root.notifications.length - 1)
    readonly property bool critical: root.latest ? ToastModel.isCritical(root.latest.urgency) : false

    function dismiss(): void {
        if (root.notifications.length > 0)
            Notifications.discardNotifications(root.notifications.map(n => n.id));
    }

    function activate(): void {
        if (root.latest)
            Notifications.activateNotification(root.latest.id);
    }

    function invoke(identifier: string): void {
        if (!root.latest)
            return;
        Notifications.attemptInvokeAction(root.latest.id, identifier, false);
        root.dismiss();
    }

    // The app group this paused; resumed on release, or when the owner goes
    // away under the pointer (no leave event then)
    property string pausedApp: ""
    function hold(on: bool): void {
        if (root.pausedApp !== "")
            Notifications.resumeGroupTimers(root.pausedApp);
        root.pausedApp = on && root.held ? root.held.appName : "";
        if (root.pausedApp !== "")
            Notifications.pauseGroupTimers(root.pausedApp);
    }
    Component.onDestruction: hold(false)
}
