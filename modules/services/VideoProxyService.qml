pragma Singleton

import QtQuick
import Quickshell
import qs.modules.services

// Screen-sized copies of video wallpapers (backend `wallpaper.videoProxy`,
// package videoproxy): a video larger than the screen or faster than
// 30 fps is transcoded once with ffmpeg into the cache, and the wallpaper
// plays that copy instead of decoding the original.
//
// request(file, width, height, cb) calls cb(path) with the file to play:
// the original right away when there is no copy yet, then the copy once
// the backend announces it (`wallpaper.videoProxy` event). The answers are
// remembered per file and size, so a second screen of the same size is
// answered at once.
Singleton {
    id: root

    // "<file>|<w>x<h>" -> {state, path}
    property var _known: ({})
    // "<file>|<w>x<h>" -> [callbacks] waiting for a pending copy
    property var _waiters: ({})
    property int _subscription: -1

    function _key(file, width, height) {
        return file + "|" + width + "x" + height;
    }

    function _subscribe() {
        if (root._subscription >= 0)
            return;
        root._subscription = BackendService.addSubscription(["wallpaper"], (service, data) => {
            if (service === "wallpaper.videoProxy" && data)
                root._settle(data);
        });
    }

    function _final(state) {
        return state === "ready" || state === "original";
    }

    // A backend answer or event: remember it and wake the waiters. A late
    // "pending" answer never replaces a final state the event already set.
    function _settle(res) {
        const key = root._key(res.source, res.width, res.height);
        const prev = root._known[key];
        if (res.state === "pending" && prev && root._final(prev.state))
            return;
        const known = Object.assign({}, root._known);
        known[key] = {
            "state": res.state,
            "path": res.path || ""
        };
        root._known = known;
        if (res.state === "pending")
            return;
        const waiting = root._waiters[key] || [];
        const rest = Object.assign({}, root._waiters);
        delete rest[key];
        root._waiters = rest;
        const file = res.state === "ready" && res.path ? res.path : res.source;
        for (let i = 0; i < waiting.length; i++)
            waiting[i](file);
    }

    function _wait(key, cb) {
        const waiters = Object.assign({}, root._waiters);
        waiters[key] = (waiters[key] || []).concat([cb]);
        root._waiters = waiters;
    }

    function request(file, width, height, cb) {
        const w = Math.round(width);
        const h = Math.round(height);
        if (!file || w <= 0 || h <= 0) {
            cb(file);
            return;
        }
        const key = root._key(file, w, h);
        const known = root._known[key];
        if (known && known.state === "ready" && known.path) {
            cb(known.path);
            return;
        }
        if (known && known.state === "original") {
            cb(file);
            return;
        }
        root._subscribe();
        root._wait(key, cb);
        if (known && known.state === "pending") {
            cb(file);
            return;
        }
        BackendService.call("wallpaper.videoProxy", {
            "path": file,
            "width": w,
            "height": h
        }, (res, error) => {
            if (error || !res) {
                root._settle({
                    "source": file,
                    "width": w,
                    "height": h,
                    "state": "original"
                });
                return;
            }
            // The finished event can overtake this answer: then the
            // waiter already got the copy and must not go back.
            const settled = root._known[key];
            if (res.state === "pending" && !(settled && root._final(settled.state)))
                cb(file);
            root._settle(res);
        });
    }
}
