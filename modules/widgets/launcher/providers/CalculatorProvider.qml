import QtQuick
import Quickshell
import qs.modules.theme
import qs.modules.services
import "../Calc.js" as Calc
import "../Units.js" as Units

// Calculator, unit and currency converter: "12*7", "sqrt(2)", "5 kg in lb",
// "100 usd in rub". Enter copies the result. In mixed searches it only
// answers queries that look like math or a conversion.
LauncherProvider {
    id: calc

    mixedLimit: 1

    property CurrencyRates rates: CurrencyRates {}

    // Rates arrive after the query (cache read, network): answer again.
    property Connections ratesWatch: Connections {
        target: calc.rates
        function onTableChanged() {
            if (calc.mode !== "" && calc.query !== "")
                calc.search(calc.query, calc.mode);
        }
    }

    function compute(text, searchMode) {
        const q = (text || "").trim();
        if (q === "")
            return searchMode === "prefix" ? [calc.hintRow()] : [];
        if (Units.split(q).length > 0)
            calc.rates.ensure();
        const conv = Units.convert(q, calc.rates.table);
        if (conv)
            return [calc.conversionRow(q, conv)];
        if (searchMode === "prefix" || Calc.looksLikeMath(q)) {
            const v = Calc.evaluate(q);
            if (v !== null)
                return [calc.mathRow(q, v)];
        }
        return searchMode === "prefix" ? [calc.hintRow()] : [];
    }

    function mathRow(q, v) {
        return {
            "key": "calc",
            "title": "= " + Calc.format(v),
            "subtitle": q,
            "icon": Icons.calculator,
            "badge": I18n.t("launcher.provider.calculator"),
            "hint": I18n.t("launcher.copy"),
            "emphasis": true,
            "data": {
                "value": Calc.plain(v),
                "expression": q
            }
        };
    }

    function conversionRow(q, c) {
        const currency = c.kind === "currency";
        const value = currency ? Calc.format(Math.round(c.value * 100) / 100) : Calc.format(c.value, 8);
        const unitTo = currency ? c.to : Units.label(c.to);
        const unitFrom = currency ? c.from : Units.label(c.from);
        let sub = Calc.format(c.amount) + " " + unitFrom;
        if (currency)
            sub += "  ·  " + I18n.t("launcher.calc.rates_" + (calc.rates.source || "offline")) + (calc.rates.date ? " " + calc.rates.date : "");
        return {
            "key": "convert",
            "title": "= " + value + " " + unitTo,
            "subtitle": sub,
            "icon": currency ? Icons.globe : Icons.arrowsOutCardinal,
            "badge": currency ? c.from + " → " + c.to : I18n.t("launcher.calc.dim." + c.dim),
            "hint": I18n.t("launcher.copy"),
            "emphasis": true,
            "data": {
                "value": currency ? String(Math.round(c.value * 100) / 100) : Calc.plain(c.value),
                "expression": q
            }
        };
    }

    function hintRow() {
        return {
            "key": "hint",
            "title": I18n.t("launcher.calc.hint"),
            "subtitle": I18n.t("launcher.calc.hint.desc"),
            "icon": Icons.calculator,
            "inert": true
        };
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", "--", text]);
    }

    function activate(item, option) {
        if (item.inert || !item.data)
            return false;
        calc.copy(option === "full" ? item.data.expression + " " + item.title : item.data.value);
        return true;
    }

    function options(item) {
        if (item.inert)
            return [];
        return [
            {
                "id": "",
                "text": I18n.t("launcher.calc.copy_result"),
                "icon": Icons.copy,
                "variant": "primary"
            },
            {
                "id": "full",
                "text": I18n.t("launcher.calc.copy_full"),
                "icon": Icons.clipboardText,
                "variant": "secondary"
            }
        ];
    }
}
