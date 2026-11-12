pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.modules.services
import qs.modules.globals
import qs.config
import "../notifications/NotificationPolicy.js" as Policy
import "../notifications/NotifyRequest.js" as NotifyRequest
import "NotificationImage.js" as NotificationImage
import "NotificationHistory.js" as NotificationHistory

Singleton {
    id: root

    component Notif: QtObject {
        required property int id
        property Notification notification
        property list<var> actions: notification?.actions.map(action => ({
                    "identifier": action.identifier,
                    "text": action.text
                })) ?? []
        property bool popup: false
        // Capturar valores inmediatamente para evitar binding issues
        property string appIcon: ""
        property string appName: ""
        property string desktopEntry: ""
        property string body: ""
        property string image: ""
        property string summary: ""
        property double time
        property string urgency: "normal"
        property int historyPriority: 0
        property string replaceKey: ""
        property var localActionHandlers: ({})
        // What backend actions do, as data (NotifyRequest.js): saved with
        // the notification, so its buttons work after a restore.
        property var actionData: ({})
        property Timer timer

        // Propiedades para cache de imágenes
        property string cachedAppIcon: ""
        property string cachedImage: ""

        // Indica si esta notificación fue cargada desde cache
        property bool isCached: false
        // closed() handler on `notification`, disconnected on destruction
        property var closedHandler: null

        // Inicializar valores cuando se asigna la notification
        onNotificationChanged: {
            if (notification) {
                appIcon = notification.appIcon ?? "";
                appName = notification.appName ?? "";
                desktopEntry = notification.desktopEntry ?? "";
                body = notification.body ?? "";
                image = notification.image ?? "";
                summary = notification.summary ?? "";
                urgency = notification.urgency.toString() ?? "normal";

                // Cachear imágenes
                if (appIcon && !appIcon.startsWith("data:")) {
                    root.cacheImageAsBase64(appIcon, function (cachedData) {
                        cachedAppIcon = cachedData;
                    });
                }
                if (image && !image.startsWith("data:")) {
                    root.cacheImageAsBase64(image, function (cachedData) {
                        cachedImage = cachedData;
                    });
                }

                // Escuchar cuando la notificación es cerrada por la aplicación
                // (CloseRequested = 3: la aplicación solicitó cerrar la notificación)
                const notifId = id;
                closedHandler = reason => {
                    if (reason === 3)
                        root.discardNotification(notifId);
                };
                notification.closed.connect(closedHandler);
            }
        }

        Component.onDestruction: {
            if (notification && closedHandler)
                notification.closed.disconnect(closedHandler);
            if (timer) {
                timer.stop();
                timer.destroy();
                timer = null;
            }
        }
    }

    component NotifTimer: Timer {
        required property int id
        property bool isPaused: false
        property real startTime: Date.now()

        property var suspendConnections: Connections {
            target: SuspendManager
            function onWakingUp() {
                if (!isPaused) {
                    // Small delay after wake to prevent popups appearing while screen is still transitioning
                    wakeStartTimer.restart();
                }
            }
        }

        property var wakeStartTimer: Timer {
            id: wakeStartTimer
            interval: 1000
            repeat: false
            onTriggered: if (!isPaused)
                parent.start()
        }

        running: !isPaused && !SuspendManager.isSuspending && interval > 0
        onTriggered: root.timeoutNotification(id)

        function pause() {
            isPaused = true;
            stop();
        }

        function resume() {
            isPaused = false;
            if (!SuspendManager.isSuspending && interval > 0) {
                start();
            }
        }
    }

    // ── Policy (config notifications.*, NotificationRules.qml + NotificationPolicy.js) ──
    readonly property var cfg: Config.notifications
    readonly property NotificationRules rules: NotificationRules {}
    // Do Not Disturb in effect (manual or scheduled)
    readonly property bool silent: rules.silent
    // Where popups show: "notch" (grow from the notch) or "corner" (toasts)
    readonly property string presentation: rules.presentation
    readonly property string cornerPosition: rules.cornerPosition
    function setDnd(on) {
        rules.setDnd(on);
    }
    function toggleDnd() {
        rules.toggleDnd();
    }
    // Focus mode's runtime-only quiet period (never persisted)
    function setFocusSilent(on) {
        rules.setFocusSilent(on);
    }
    function showsOnScreen(name) {
        return rules.showsOnScreen(name);
    }

    // Applies the policy to a new notification object: popup + timer,
    // history priority, sound; then enforces maxVisible and historySize.
    function admit(notifObject, info) {
        const d = root.rules.decide(info);
        if (d.priority)
            notifObject.historyPriority = Math.max(notifObject.historyPriority, 1);
        if (d.popup && info.popup !== false) {
            notifObject.popup = true;
            // A group under the pointer stays paused for its new arrivals
            notifObject.timer = notifTimerComponent.createObject(root, {
                "id": notifObject.id,
                "interval": d.timeout,
                "isPaused": root._heldGroups[notifObject.appName] === true
            });
            if (d.sound)
                root.rules.playSound(info.hints);
        }
        Qt.callLater(root.enforceLimits);
    }

    function enforceLimits() {
        const hide = Policy.overflowPopups(root.popupList, Policy.popupLimit(root.cfg, root.presentation));
        hide.forEach(id => {
            const n = root.list.find(x => x.id === id);
            if (n) {
                n.popup = false;
                root.dropTimer(n);
            }
        });
        const drop = Policy.trimHistory(root.list, root.cfg ? root.cfg.historySize : 100);
        if (drop.length > 0)
            root.discardNotifications(drop);
        else if (hide.length > 0)
            root.triggerListChange();
    }

    property list<Notif> list: []
    property var popupList: list.filter(notif => notif.popup)
    // Popups by presentation; the other one gets an empty list.
    readonly property var notchPopupList: presentation === "notch" ? popupList : []
    readonly property var cornerPopupList: presentation === "corner" ? popupList : []
    property var latestTimeForApp: ({})
    property var totalCounts: ({})  // Conteo total independiente del almacenamiento: {appName: {summary: count}}

    Component {
        id: notifComponent
        Notif {}
    }
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    // Debounced, compact saves; flushed on destruction
    NotificationHistoryFile {
        id: historyFile
        path: Brand.cacheDir + "/notifications.json"
        // At most 5 per app + summary, compact
        serialize: () => NotificationHistory.serialize(root.list)
        onLoaded: root.loadNotifications(false)
        onMissing: root.loadNotifications(true)
    }

    // A popup's hide step after its timeout animation (one deadline per id)
    NotificationHideQueue {
        id: hideQueue
        onExpired: id => {
            const n = root.list.find(notif => notif.id === id);
            if (n) {
                n.popup = false;
                root.dropTimer(n);
            }
            root.timeout(id);
        }
    }

    // Destroys dropped notification objects after a grace period
    NotificationReaper {
        id: reaper
        isLive: obj => root.list.indexOf(obj) !== -1
    }

    // Stop tracking notifications dropped from the list (timers now, objects later)
    function retire(notifs) {
        notifs.forEach(n => root.dropTimer(n));
        reaper.retire(notifs);
    }

    function dropTimer(n) {
        if (n && n.timer) {
            n.timer.stop();
            n.timer.destroy();
            n.timer = null;
        }
    }

    function jsonToNotif(json, id) {
        return notifComponent.createObject(root, {
            "id": id,
            "actions": json.actions,
            "appIcon": json.cachedAppIcon || json.appIcon  // Usar cached si disponible
            ,
            "appName": json.appName,
            "desktopEntry": json.desktopEntry || "",
            "body": json.body,
            "image": json.cachedImage || json.image  // Usar cached si disponible
            ,
            "summary": json.summary,
            "time": json.time,
            "urgency": json.urgency,
            "historyPriority": json.historyPriority || 0,
            "replaceKey": json.replaceKey || "",
            "actionData": json.actionData || {},
            "localActionHandlers": NotifyRequest.handlers(json.actionData, root.requestDeps()),
            "cachedAppIcon": json.cachedAppIcon || "",
            "cachedImage": json.cachedImage || "",
            "isCached": json.isCached || true  // Default to true for loaded notifications
            ,
            "popup": false  // No popup para notificaciones cargadas
        });
    }

    function saveNotifications() {
        if (ProcessRole.primary)
            historyFile.save();
    }

    // Once, merged under the live notifications (NotificationHistory.merge):
    // the ones that arrived before the history was read stay as they are
    // (popup, actions, ids). A missing or unreadable file is an empty
    // history, so a later reload never replaces live state.
    property bool historyLoaded: false
    function loadNotifications(missing) {
        if (root.historyLoaded)
            return;
        root.historyLoaded = true;
        let data = [];
        if (!missing) {
            try {
                data = JSON.parse(historyFile.text());
            } catch (e) {
                console.log("No saved notifications or error loading:", e);
            }
        }
        const live = root.list.map(n => ({
                    "id": n.id,
                    "time": n.time,
                    "summary": n.summary
                }));
        const fixed = root.list.some(n => n.notification !== null) || root._liveNotifs().length > 0;
        const m = NotificationHistory.merge(data, live, root.idOffset, root.internalIdCounter, fixed);
        root.idOffset = m.idOffset;
        root.internalIdCounter = m.internalIdCounter;
        if (m.entries.length > 0)
            root.list = [...m.entries.map(e => jsonToNotif(e.json, e.id)), ...root.list];
    }

    onListChanged: {
        // Update latest time for each app
        root.list.forEach(notif => {
            if (!root.latestTimeForApp[notif.appName] || notif.time > root.latestTimeForApp[notif.appName]) {
                root.latestTimeForApp[notif.appName] = Math.max(root.latestTimeForApp[notif.appName] || 0, notif.time);
            }
        });
        // Remove apps that no longer have notifications
        Object.keys(root.latestTimeForApp).forEach(appName => {
            if (!root.list.some(notif => notif.appName === appName)) {
                delete root.latestTimeForApp[appName];
            }
        });
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            if (groups[b].historyPriority !== groups[a].historyPriority) {
                return groups[b].historyPriority - groups[a].historyPriority;
            }
            return groups[b].time - groups[a].time;
        });
    }

    function groupsForList(list) {
        const groups = {};
        list.forEach((notif, index) => {
            // Verificar que la notificación es válida antes de agruparla
            if (!notif || !notif.appName || (!notif.summary && !notif.body)) {
                return;
            }

            // notifications.groupByApp: one group per app, or one per notification
            const key = Policy.groupKey(notif, root.cfg ? root.cfg.groupByApp : true);
            if (!groups[key]) {
                groups[key] = {
                    appName: notif.appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0,
                    historyPriority: 0,
                    totalCount: 0  // Conteo independiente del almacenamiento
                };
            }
            groups[key].notifications.push(notif);
            groups[key].totalCount++;
            // Always set to the latest time in the group
            groups[key].time = key === notif.appName ? (latestTimeForApp[notif.appName] || notif.time) : notif.time;
            groups[key].historyPriority = Math.max(groups[key].historyPriority || 0, notif.historyPriority || 0);
        });

        return groups;
    }

    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property var appNameList: appNameListForGroups(root.groupsByAppName)
    property var popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    // Quickshell's notification IDs starts at 1 on each run, while saved notifications
    // can already contain higher IDs. This is for avoiding id collisions
    property int idOffset
    property int internalIdCounter: 1
    signal initDone
    signal notify(notification: var)
    signal discard(id: var)
    signal discardAll
    signal timeout(id: var)

    // Live notification objects (hints update in place on replaces_id);
    // read by the notification-progress live activity
    readonly property var serverNotifications: root.notifServer ? root.notifServer.trackedNotifications : null
    function _liveNotifs() {
        return root.notifServer ? root.notifServer.trackedNotifications.values : [];
    }

    // The session's D-Bus notification server: the main shell only
    // (ProcessRole). A separate window hands its notifications to the daemon
    // (notifyInternal) and never reads or writes the history.
    readonly property var notifServer: serverInstance.object
    property Instantiator serverInstance: Instantiator {
        active: ProcessRole.primary
        delegate: NotificationServer {
            actionsSupported: true
            bodyHyperlinksSupported: true
            bodyImagesSupported: true
            bodyMarkupSupported: true
            bodySupported: true
            imageSupported: true
            keepOnReload: false
            persistenceSupported: true
            // Capability "sound": sound-file / sound-name / suppress-sound are honoured
            extraHints: ["sound"]

            onNotification: notification => {
                // Verificar que la notificación tiene contenido válido antes de procesarla
                if (!notification || (!notification.summary && !notification.body)) {
                    return;
                }

                notification.tracked = true;
                const newNotifObject = notifComponent.createObject(root, {
                    "id": notification.id + root.idOffset,
                    "notification": notification,
                    "time": Date.now()
                });

                // Usar Qt.callLater para evitar race conditions al actualizar la lista
                Qt.callLater(() => {
                    root.list = [...root.list, newNotifObject];
                    root.saveNotifications();
                });

                // Popup (notch or corner toasts), rules, DND and sound: NotificationPolicy.js
                root.admit(newNotifObject, {
                    "appName": notification.appName,
                    "desktopEntry": notification.desktopEntry,
                    "urgency": notification.urgency,
                    "expireTimeout": notification.expireTimeout,
                    "hints": notification.hints
                });

                root.notify(newNotifObject);
            }
        }
    }

    function notifyInternal(options) {
        if (!options || (!options.summary && !options.body)) {
            return null;
        }
        if (!ProcessRole.primary) {
            BackendService.call("notify.send", NotifyRequest.toSend(options));
            return null;
        }

        if (options.replaceKey) {
            const existingIds = root.list.filter(notif => notif && notif.replaceKey === options.replaceKey).map(notif => notif.id);
            if (existingIds.length > 0) {
                root.discardNotifications(existingIds);
            }
        }

        const notificationId = -1000000 - root.internalIdCounter++;
        const newNotifObject = notifComponent.createObject(root, {
            "id": notificationId,
            "actions": options.actions || [],
            "appIcon": options.appIcon || "",
            "appName": options.appName || "Yozakura",
            "body": options.body || "",
            "image": options.image || "",
            "summary": options.summary || "",
            "time": options.time || Date.now(),
            "urgency": options.urgency || NotificationUrgency.Normal,
            "historyPriority": options.historyPriority || 0,
            "replaceKey": options.replaceKey || "",
            "localActionHandlers": options.actionHandlers || {},
            "actionData": options.actionData || {},
            "popup": false,
            "isCached": false
        });

        root.admit(newNotifObject, {
            "appName": newNotifObject.appName,
            "desktopEntry": "",
            "urgency": newNotifObject.urgency,
            "expireTimeout": typeof options.expireTimeout === "number" ? options.expireTimeout : -1,
            "popup": options.popup,
            "hints": options.hints
        });

        root.list = [...root.list, newNotifObject];
        saveNotifications();
        root.notify(newNotifObject);
        return newNotifObject;
    }

    function discardNotification(id) {
        const index = root.list.findIndex(notif => notif.id === id);
        const notifServerIndex = root._liveNotifs().findIndex(notif => notif.id + root.idOffset === id);
        if (index !== -1) {
            const removed = root.list[index];
            root.list.splice(index, 1);
            triggerListChange();
            saveNotifications();
            root.retire([removed]);
        }
        if (notifServerIndex !== -1) {
            root._liveNotifs()[notifServerIndex].dismiss();
        }
        root.discard(id);
    }

    function discardNotifications(ids) {
        if (!ids || ids.length === 0)
            return;

        var idsMap = {};
        ids.forEach(id => {
            idsMap[id] = true;
        });

        const removed = root.list.filter(notif => idsMap[notif.id]);
        if (removed.length > 0) {
            root.list = root.list.filter(notif => !idsMap[notif.id]);
            triggerListChange();
            saveNotifications();
            root.retire(removed);
        }

        ids.forEach(id => {
            const notifServerIndex = root._liveNotifs().findIndex(notif => notif.id + root.idOffset === id);
            if (notifServerIndex !== -1) {
                root._liveNotifs()[notifServerIndex].dismiss();
            }
            root.discard(id);
        });
    }

    function discardAllNotifications() {
        const removed = root.list.slice();
        root.list = [];
        triggerListChange();
        saveNotifications();
        root.retire(removed);
        root._liveNotifs().forEach(notif => {
            notif.dismiss();
        });
        root.discardAll();
    }

    signal timeoutWithAnimation(id: var)

    function timeoutNotification(id) {
        root.timeoutWithAnimation(id);
        hideQueue.schedule(id);
    }

    function timeoutAll() {
        root.popupList.forEach(notif => {
            root.timeout(notif.id);
        });
        root.popupList.forEach(notif => {
            notif.popup = false;
            root.dropTimer(notif);
        });
    }

    function attemptInvokeAction(id, notifIdentifier, autoDiscard = true) {
        let invoked = false;
        const notif = root.list.find(notif => notif.id === id);
        const localHandler = notif?.localActionHandlers?.[notifIdentifier];
        if (typeof localHandler === "function") {
            localHandler(id);
            invoked = true;
        } else if (!notif?.isCached) {
            const live = root._liveNotifs().find(notif => notif.id + root.idOffset === id);
            const action = live?.actions.find(action => action.identifier === notifIdentifier);
            if (action) {
                action.invoke();
                invoked = true;
            }
        }
        if (invoked && autoDiscard) root.discardNotification(id);
        return invoked;
    }

    function activateNotification(id) {
        const notif = root.list.find(notif => notif.id === id);
        if (!notif) return false;

        // Let the sender handle navigation to the conversation or item. Never
        // select an arbitrary first action: it may delete, reply or dismiss.
        if (!notif.isCached) {
            for (const identifier of ["default", "open", "view"]) {
                if (root.attemptInvokeAction(id, identifier)) return true;
            }
        }

        // History and senders without an opening action can still open the app.
        const normalize = value => String(value || "").replace(/\.desktop$/i, "").toLowerCase();
        const desktopId = normalize(notif.desktopEntry);
        const appName = normalize(notif.appName);
        const entries = DesktopEntries.applications.values;
        const entry = (desktopId ? DesktopEntries.byId(notif.desktopEntry.replace(/\.desktop$/i, "")) : null)
            || entries.find(entry => (desktopId && normalize(entry.id) === desktopId)
                || (appName && normalize(entry.name) === appName));
        const identities = [desktopId, appName, normalize(entry?.id), normalize(entry?.startupClass)].filter(value => value);
        const client = YozdService.clients.values.filter(client => identities.includes(normalize(client.class)))
            .sort((a, b) => (a.focusHistoryID ?? 999999) - (b.focusHistoryID ?? 999999))[0];
        if (client) {
            YozdService.dispatch(`focuswindow address:${client.address}`);
        } else if (entry) {
            entry.execute();
        } else {
            return false;
        }
        root.discardNotification(id);
        return true;
    }

    // App groups whose popup is hovered (pauseGroupTimers .. resumeGroupTimers)
    property var _heldGroups: ({})
    function pauseGroupTimers(appName) {
        root._heldGroups[appName] = true;
        root.popupList.forEach(notif => {
            if (notif.appName === appName && notif.timer) {
                notif.timer.pause();
            }
        });
    }

    function resumeGroupTimers(appName) {
        delete root._heldGroups[appName];
        root.popupList.forEach(notif => {
            if (notif.appName === appName && notif.timer) {
                notif.timer.resume();
            }
        });
    }

    function pauseAllTimers() {
        root.popupList.forEach(notif => {
            if (notif.timer) {
                notif.timer.pause();
            }
        });
    }

    function resumeAllTimers() {
        root.popupList.forEach(notif => {
            if (notif.timer) {
                notif.timer.resume();
            }
        });
    }

    function hideAllPopups() {
        root.popupList.forEach(notif => {
            notif.popup = false;
            root.dropTimer(notif);
        });
    }

    function triggerListChange() {
        root.list = root.list.slice(0);
    }

    property int activeXhrCount: 0
    property int maxConcurrentXhr: 3

    function cacheImageAsBase64(imageUrl, callback) {
        if (!imageUrl || imageUrl.startsWith("data:")) {
            callback(imageUrl);
            return;
        }

        if (!imageUrl.startsWith("http://") && !imageUrl.startsWith("https://")) {
            callback(imageUrl);
            return;
        }

        if (imageUrl.length > 2048) {
            callback(imageUrl);
            return;
        }

        if (activeXhrCount >= maxConcurrentXhr) {
            callback(imageUrl);
            return;
        }

        activeXhrCount++;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", imageUrl, true);
        xhr.responseType = "arraybuffer";
        xhr.timeout = 5000;

        var cleanupXhr = function () {
            activeXhrCount--;
            xhr = null;
        };

        xhr.onload = function () {
            if (xhr.status === 200 && xhr.response) {
                try {
                    // Over 1 MiB or empty: keep the URL, never a cut (corrupt) image
                    callback(NotificationImage.dataUrl(new Uint8Array(xhr.response), imageUrl, btoa) || imageUrl);
                } catch (e) {
                    callback(imageUrl);
                }
            } else {
                callback(imageUrl);
            }
            cleanupXhr();
        };

        xhr.onerror = function () {
            callback(imageUrl);
            cleanupXhr();
        };

        xhr.ontimeout = function () {
            callback(imageUrl);
            cleanupXhr();
        };

        xhr.send();
    }

    Component.onCompleted: {
        // A separate window shows no notifications: no history, no stream.
        if (!ProcessRole.primary) {
            root.initDone();
            return;
        }
        // Defer notification history reload to not block boot.
        // The DBus notification server is registered above and live notifications work.
        notifDeferTimer.start();

        // Subscribe to the notify IPC service so external CLI commands
        // (colorpicker, screen, …) can route their notifications through
        // this singleton instead of shelling out to notify-send. Without
        // this they bypass Yozakura's notification lifecycle and leak into
        // the system daemon — see cmds_colorpicker.go for the originating
        // bug. We register the subscription even if BackendService isn't
        // connected yet; the callback simply won't fire until the socket
        // is up.
        root.notifyIpcHandle = BackendService.addSubscription(
            ["notify"],
            (service, data) => root.handleNotifyRequest(data)
        );

        root.initDone();
    }

    property int notifyIpcHandle: -1

    // handleNotifyRequest converts a backend notify.request (CLI `notify
    // send`, timers...) into a tracked notification; NotifyRequest.js wires
    // `clipboard` actions (wl-copy) and `call` actions (backend IPC call).
    function handleNotifyRequest(data) {
        if (!data)
            return;
        root.notifyInternal(NotifyRequest.build(data, root.requestDeps()));
    }

    // What NotifyRequest actions run. A failed call (already answered,
    // task gone) shows a short quiet notice.
    function requestDeps() {
        return {
            // The value is untrusted notification data: argv only.
            "copy": value => Quickshell.execDetached(["wl-copy", "--type", "text/plain", "--", value]),
            "call": (method, params) => BackendService.call(method, params, (res, err) => {
                if (err)
                    root.notifyInternal(NotifyRequest.failureNotice(err, key => I18n.t(key)));
            }),
            "tr": key => I18n.t(key),
            "has": key => I18n.has(key)
        };
    }

    Timer {
        id: notifDeferTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: historyFile.reload()
    }
}
