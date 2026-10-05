import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.globals
import qs.config

// Currency rates for the calculator (units per 1 USD). Order of trust:
// fresh cache (<cache>/currency-rates.json, refreshed every
// prefix.launcher.currencyRefreshHours from open.er-api.com, free, no key),
// stale cache, then the bundled offline table (assets/launcher).
QtObject {
    id: rates

    property var table: ({})
    property string date: ""
    property string source: ""      // "live" | "cache" | "offline"
    property real fetched: 0
    readonly property string url: "https://open.er-api.com/v6/latest/USD"
    readonly property string cacheFile: Brand.cacheDir + "/currency-rates.json"
    readonly property string fallbackFile: Qt.resolvedUrl("../../../../assets/launcher/currency-fallback.json").toString().replace("file://", "")
    readonly property real maxAgeMs: Math.max(1, Config.prefix.launcher.currencyRefreshHours || 12) * 3600 * 1000
    property bool fetching: false

    // Called when a conversion query is typed: refreshes stale rates.
    function ensure() {
        if (Date.now() - rates.fetched > rates.maxAgeMs)
            rates._fetch();
    }

    function _apply(json, src) {
        try {
            const d = JSON.parse(json);
            const r = d.rates || {};
            if (!r.USD)
                return false;
            rates.table = r;
            rates.date = d.date || (d.time_last_update_unix ? new Date(d.time_last_update_unix * 1000).toISOString().substring(0, 10) : "");
            rates.source = src;
            return true;
        } catch (e) {
            return false;
        }
    }

    function _fetch() {
        if (rates.fetching)
            return;
        rates.fetching = true;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            rates.fetching = false;
            if (xhr.status === 200 && rates._apply(xhr.responseText, "live")) {
                const d = JSON.parse(xhr.responseText);
                rates.fetched = Date.now();
                cache.setText(JSON.stringify({
                    "fetched": Date.now(),
                    "date": rates.date,
                    "rates": d.rates
                }));
            }
        };
        // A failed fetch is not retried before the next refresh period.
        rates.fetched = Date.now() - rates.maxAgeMs + 10 * 60 * 1000;
        xhr.open("GET", rates.url);
        xhr.send();
    }

    property FileView cache: FileView {
        path: rates.cacheFile
        blockLoading: false
        printErrors: false
        onLoaded: {
            const t = cache.text();
            try {
                rates.fetched = JSON.parse(t).fetched || 0;
            } catch (e) {}
            if (!rates._apply(t, "cache"))
                fallback.reload();
        }
        onLoadFailed: fallback.reload()
    }

    property FileView fallback: FileView {
        path: rates.fallbackFile
        blockLoading: false
        printErrors: false
        onLoaded: {
            if (rates.source === "")
                rates._apply(fallback.text(), "offline");
        }
    }
}
