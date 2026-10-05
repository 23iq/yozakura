// Yozakura spicetify theme: hot-reload colors.css / user.css.
//
// Yozakura rewrites color.ini on every palette change and runs
// `spicetify refresh -n`, which rewrites xpui/colors.css on disk without
// restarting Spotify. This watcher notices the new file and swaps the
// stylesheet in place, so Spotify follows the wallpaper live.
(function yozakuraLiveColors() {
    const INTERVAL_MS = 2500;
    const files = ["colors.css", "user.css"];
    const last = {};

    async function check(name) {
        try {
            const res = await fetch(name + "?yozakura=" + Date.now(), { cache: "no-store" });
            if (!res.ok) return;
            const text = await res.text();
            if (last[name] === undefined) {
                last[name] = text;
                return;
            }
            if (text === last[name]) return;
            last[name] = text;
            const link = document.querySelector('link.userCSS[href^="' + name + '"]');
            if (link) link.href = name + "?v=" + Date.now();
        } catch (e) {
            // Ignore: file may be mid-write; retry on next tick.
        }
    }

    function tick() {
        if (document.visibilityState === "visible" || document.hasFocus()) {
            files.forEach(check);
        }
    }

    files.forEach(check);
    setInterval(tick, INTERVAL_MS);
})();
