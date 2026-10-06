import QtQuick
import qs.config
import "Templates.js" as Templates

QtObject {
    property var owner

    function expandTemplate(template, extra, cb) {
        owner._ensureInit();
        const vars = Object.assign({
            language: Config.ai.selection.language
        }, extra || {});
        const needed = Templates.variables(template).filter(v => vars[v] === undefined && (v === "selection" || v === "clipboard" || v === "window"));
        const next = () => {
            if (needed.length === 0) {
                cb(Templates.expand(template, vars));
                return;
            }
            const v = needed.shift();
            if (v === "selection")
                owner.context.selectionText(t => {
                    vars.selection = t;
                    next();
                });
            else if (v === "clipboard")
                owner.context.clipboardText(t => {
                    vars.clipboard = t;
                    next();
                });
            else
                owner.context.activeWindow(a => {
                    vars.window = a ? a.text : "";
                    next();
                });
        };
        next();
    }
}
