pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.services
import qs.modules.globals
import "UpdateVersions.js" as Versions

// Background update notice. What counts as newer depends on the update
// channel (system.updateChannel, see UpdateVersions.js): stable / beta read
// the repository's tags, git the tip of main. One unauthenticated GitHub
// call per check, at most about once an hour; the installed commit comes
// from the checkout the shell runs from (git describe), nothing else.
Singleton {
    id: root

    readonly property string currentVersion: Config.version
    readonly property string channel: Versions.channel(Config.system.updateChannel)
    readonly property string apiBase: "https://api.github.com/repos/" + Brand.repoSlug
    // one page of up to 100 tags (GitHub orders them by name, not version)
    readonly property string repoUrl: root.apiBase + "/tags?per_page=100"
    readonly property string changelogUrl: Brand.repoUrl + (root.channel === "git" ? "/commits/main" : "/releases")
    // QUICKSHELL-GIT: readonly property string cacheFile: Quickshell.cachePath("update_check.json")
    readonly property string cacheFile: Brand.cacheDir + "/update_check.json"

    // The target last found newer than the install ("0.3.2", "main @ 1a2b3c4")
    property string lastDetectedVersion: ""
    // lastDetectedVersion is newer than what is installed (settings status)
    property bool updateAvailable: false
    // The channel the cached result belongs to
    property string checkedChannel: ""
    property double lastCheckTime: 0
    property double nextCheckTime: 0
    // A check is in flight (settings "Check now")
    property bool checking: false
    // git describe of the checkout, read once per check
    property var described: Versions.describe("")

    FileView {
        id: cacheFileView
        path: root.cacheFile
        onLoaded: {
            try {
                const content = text();
                if (content && content.trim() !== "") {
                    const data = JSON.parse(content);
                    root.lastCheckTime = data.lastCheckTime || 0;
                    root.nextCheckTime = data.nextCheckTime || 0;
                    root.lastDetectedVersion = data.lastDetectedVersion || "";
                    // caches written before channels: the stable channel's tag
                    root.checkedChannel = data.channel || "stable";
                    root.updateAvailable = data.updateAvailable === undefined ? root.lastDetectedVersion !== "" && Versions.isNewer(root.lastDetectedVersion, root.currentVersion) : data.updateAvailable === true;
                    root.forgetOtherChannel();
                } else {
                    root.nextCheckTime = Date.now();
                }
            } catch (e) {
                console.log("[UpdateService] Error loading update cache:", e);
                root.nextCheckTime = Date.now();
            }
        }
    }

    function saveCache() {
        const data = {
            lastCheckTime: root.lastCheckTime,
            nextCheckTime: root.nextCheckTime,
            lastDetectedVersion: root.lastDetectedVersion,
            updateAvailable: root.updateAvailable,
            channel: root.checkedChannel
        };
        cacheFileView.setText(JSON.stringify(data));
    }

    // A result of another channel says nothing about this one: drop it and
    // look again at the next tick of the check timer.
    function forgetOtherChannel() {
        if (root.checkedChannel === "" || root.checkedChannel === root.channel)
            return;
        root.checkedChannel = root.channel;
        root.lastDetectedVersion = "";
        root.updateAvailable = false;
        root.nextCheckTime = Date.now();
    }
    onChannelChanged: forgetOtherChannel()

    Timer {
        id: startupDelay
        interval: 2000
        running: true
        onTriggered: {
            if (Config.system.updateServiceEnabled) {
                checkUpdates();
            }
            checkTimer.running = true;
        }
    }

    Timer {
        id: checkTimer
        interval: 300000 // Every 5 minutes check if it's time
        running: false
        repeat: true
        onTriggered: {
            if (!Config.system.updateServiceEnabled) return;
            const now = Date.now();
            if (now >= root.nextCheckTime) {
                checkUpdates();
            }
        }
    }

    // A check: describe the checkout, then ask GitHub for the channel's
    // target (tags, or the tip of main).
    function checkUpdates() {
        if (root.checking)
            return;
        root.checking = true;
        root._describing = true;
        describeProc.running = true;
        describeFallback.restart();
    }

    // Exactly once per check: after git describe, or without it when git is
    // missing / the shell is not a checkout (Nix: the version file only).
    property bool _describing: false
    function takeDescribe(text) {
        if (!root._describing)
            return;
        root._describing = false;
        describeFallback.stop();
        root.described = Versions.describe(text);
        root.fetchTarget(root.channel);
    }

    Process {
        id: describeProc
        command: ["git", "-C", Quickshell.shellDir, "describe", "--tags", "--long", "--always", "--abbrev=40"]
        stdout: StdioCollector {
            onStreamFinished: root.takeDescribe(text)
        }
    }

    Timer {
        id: describeFallback
        interval: 5000
        onTriggered: root.takeDescribe("")
    }

    // The ancestry check of the git channel: exit 0 = HEAD already has the tip.
    Process {
        id: ancestorProc
        property string tip: ""
        onExited: exitCode => root.finishCheck("git", exitCode === 0 ? "" : Versions.gitLabel(ancestorProc.tip))
    }

    function fetchTarget(channel) {
        const git = channel === "git";
        const xhr = new XMLHttpRequest();
        xhr.open("GET", git ? root.apiBase + "/commits/main" : root.repoUrl);
        if (git)
            xhr.setRequestHeader("Accept", "application/vnd.github.sha");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200) {
                root.finishCheck(channel, null);
                return;
            }
            if (git) {
                const tip = xhr.responseText.trim();
                const verdict = Versions.gitCompare(tip, root.described.commit);
                if (verdict === "check") {
                    ancestorProc.tip = tip;
                    ancestorProc.command = ["git", "-C", Quickshell.shellDir, "merge-base", "--is-ancestor", tip, "HEAD"];
                    ancestorProc.running = true;
                } else {
                    root.finishCheck(channel, verdict === "same" ? "" : null);
                }
                return;
            }
            try {
                const tags = JSON.parse(xhr.responseText);
                // GitHub lists tags by name, not by version
                const installed = Versions.installed(root.currentVersion, root.described);
                root.finishCheck(channel, Versions.tagUpdate(tags, channel, installed));
            } catch (e) {
                console.log("[UpdateService] Error parsing GitHub tags:", e);
                root.finishCheck(channel, null);
            }
        };
        xhr.send();
    }

    // newer: the target to announce, "" = up to date, null = no answer
    // (offline, rate limited): the previous result stays.
    function finishCheck(channel, newer) {
        root.checking = false;
        if (newer !== null && channel === root.channel) {
            root.checkedChannel = channel;
            root.updateAvailable = newer !== "";
            if (newer !== "" && (newer !== root.lastDetectedVersion || !isNotificationInHistory())) {
                // "Check now" with the service off only updates the settings
                // status, no popup
                if (Config.system.updateServiceEnabled)
                    sendUpdateNotification(newer);
            }
            root.lastDetectedVersion = newer;
        }
        root.lastCheckTime = Date.now();

        // If nextCheckTime is in the past or now, set it to 1 hour from now
        if (root.nextCheckTime <= Date.now()) {
            root.nextCheckTime = Date.now() + 3600000;
        }

        saveCache();
    }

    function isNewer(latest, current) {
        return Versions.isNewer(latest, current);
    }

    function isNotificationInHistory() {
        if (typeof Notifications === "undefined" || !Notifications.list) return false;
        for (let i = 0; i < Notifications.list.length; i++) {
            const notif = Notifications.list[i];
            if (notif && notif.appName === Brand.displayName + " Update") {
                return true;
            }
        }
        return false;
    }

    function sendUpdateNotification(newVersion) {
        const summary = Brand.displayName + " update available!";
        const installed = root.channel === "git" ? Versions.gitLabel(root.described.commit) : root.currentVersion;
        const body = newVersion + " available! (Installed " + installed + ", " + root.channel + " channel)";

        // Routed through the shell's Notifications service so it can be
        // dismissed/tracked like every other notification instead
        // of leaking into the system daemon. The actions keep their
        // previous behavior via localActionHandlers — `attemptInvokeAction`
        // fires them when the user clicks a button.
        Notifications.notifyInternal({
            summary: summary,
            body: body,
            appName: Brand.displayName + " Update",
            appIcon: "system-software-update",
            urgency: "normal",
            replaceKey: Brand.appId + "-update-available",
            actions: [
                { identifier: "changelog", text: "Changelog" },
                { identifier: "later",     text: "Maybe later" },
                { identifier: "update",    text: "Update" }
            ],
            actionHandlers: {
                "changelog": function () {
                    Quickshell.execDetached(["xdg-open", root.changelogUrl]);
                },
                "later": function () {
                    root.nextCheckTime = Date.now() + 8 * 3600000;
                    root.saveCache();
                },
                "update": function () {
                    TerminalService.execDetached(Brand.appBin + " update; exec $SHELL");
                }
            }
        });
    }
}
