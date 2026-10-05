.pragma library
.import "ColorUtils.js" as CU
.import "TelegramBase.js" as Base

// Builds the contents of colors.tdesktop-theme from an Yozakura palette.
//
// Telegram's own "Night" theme (TelegramBase.js) is used as the structural
// template: every literal color in it is reclassified and recolored with
// palette roles, so the result covers every key Telegram knows about while
// preserving the original contrast hierarchy.
//
//   neutral tones  -> surface / outline / onSurface ladder (by lightness)
//   blue accent    -> primaryContainer .. primary .. primaryFixed (by lightness)
//   reds           -> errorContainer .. error
//   other hues     -> kept, but harmonized towards primary
//   pure black     -> shadow (alpha kept)
//   white overlays -> onSurface (alpha kept)
//
// A short list of keys that sit on accent fills get explicit Material roles
// so text/icons on them always use the matching "on" color.

// p: object with "#rrggbb" strings for the Material roles used below.
function build(p) {
    const pick = (name, fallback) => p[name] || fallback;

    // Night theme reference lightness (OKLab L) -> Yozakura role.
    const neutral = [
        [0.00, pick("shadow", "#000000")],
        [0.20, p.surfaceContainerLowest],
        [0.24, p.background],
        [0.28, p.surfaceContainer],
        [0.30, p.surfaceContainerHigh],
        [0.36, p.surfaceContainerHighest],
        [0.46, p.outlineVariant],
        [0.60, p.outline],
        [0.80, p.overSurfaceVariant],
        [0.97, p.overSurface]
    ];
    const accent = [
        [0.35, CU.mix(p.background, p.primaryContainer, 0.45)],
        [0.43, p.primaryContainer],
        [0.53, CU.mix(p.primaryContainer, p.primary, 0.45)],
        [0.74, p.primary],
        [0.88, p.primaryFixed]
    ];
    const reds = [
        [0.35, p.errorContainer],
        [0.62, p.error]
    ];

    const recolor = (hex) => {
        const src = CU.parseHex(hex);
        const alpha = src.a;
        const c = CU.lch(hex);
        let out;
        if (c.L < 0.02) {
            out = pick("shadow", "#000000");
        } else if (c.L > 0.995 && c.C < 0.01) {
            // Pure white: overlays/strokes and text on dark surfaces.
            out = p.overSurface;
        } else if (c.C < 0.045) {
            out = CU.ramp(neutral, c.L);
        } else if (c.h >= 225 && c.h <= 275) {
            out = CU.ramp(accent, c.L);
        } else if ((c.h <= 40 || c.h >= 350) && c.C > 0.12) {
            out = CU.ramp(reds, c.L);
        } else {
            out = CU.harmonize(hex, p.primary, 0.25, 20);
        }
        return alpha < 1 ? CU.withAlpha(out, alpha) : out;
    };

    const onPrimary = p.overPrimary;
    const overrides = {
        // Accent fills -> primary, content on them -> onPrimary.
        windowBgActive: p.primary,
        windowFgActive: onPrimary,
        windowActiveTextFg: p.primary,
        activeButtonBg: p.primary,
        activeButtonBgOver: CU.mix(p.primary, onPrimary, 0.08),
        activeButtonBgRipple: CU.mix(p.primary, onPrimary, 0.16),
        activeButtonFg: onPrimary,
        activeButtonFgOver: onPrimary,
        activeButtonSecondaryFg: CU.mix(onPrimary, p.primary, 0.35),
        activeLineFg: p.primary,
        lightButtonFg: p.primary,
        dialogsUnreadBg: p.primary,
        dialogsUnreadBgOver: p.primary,
        dialogsUnreadFg: onPrimary,
        dialogsUnreadBgMuted: p.outline,
        dialogsUnreadBgMutedOver: p.outline,
        dialogsUnreadFgOver: onPrimary,
        dialogsVerifiedIconBg: p.primary,
        dialogsVerifiedIconFg: onPrimary,
        sideBarBadgeBg: p.primary,
        sideBarBadgeFg: onPrimary,
        msgFileInBg: p.primary,
        msgFileInBgOver: CU.mix(p.primary, onPrimary, 0.08),
        msgFileInBgSelected: p.primaryFixed,
        msgFileOutBg: p.primary,
        msgFileOutBgOver: CU.mix(p.primary, onPrimary, 0.08),
        msgFileOutBgSelected: p.primaryFixed,
        historyFileInIconFg: onPrimary,
        historyFileInIconFgSelected: onPrimary,
        historyFileInRadialFg: onPrimary,
        historyFileOutIconFg: onPrimary,
        historyFileOutIconFgSelected: onPrimary,
        historyFileOutRadialFg: onPrimary,
        historyFileOutRadialFgSelected: onPrimary,
        callAnswerBg: p.primary,
        callAnswerRipple: CU.mix(p.primary, onPrimary, 0.16),
        overviewCheckFgActive: onPrimary,
        profileVerifiedCheckFg: onPrimary,
        // Chat list / bubbles: Material containers.
        dialogsBgActive: p.primaryContainer,
        dialogsRippleBgActive: CU.mix(p.primaryContainer, p.overPrimaryContainer, 0.12),
        dialogsNameFgActive: p.overPrimaryContainer,
        dialogsTextFgActive: CU.mix(p.overPrimaryContainer, p.primaryContainer, 0.2),
        dialogsDateFgActive: CU.mix(p.overPrimaryContainer, p.primaryContainer, 0.2),
        msgInBg: p.surfaceContainerHigh,
        msgInBgSelected: CU.mix(p.surfaceContainerHigh, p.primary, 0.25),
        msgOutBg: p.primaryContainer,
        msgOutBgSelected: CU.mix(p.primaryContainer, p.primary, 0.25),
        historyTextOutFg: p.overPrimaryContainer,
        historyTextOutFgSelected: p.overPrimaryContainer,
        historyComposeAreaBg: p.surfaceContainer,
        sideBarBg: p.surfaceContainerLowest,
        titleBg: p.surfaceContainerLowest,
        titleBgActive: p.surfaceContainerLowest,
        trayCounterFg: p.overError,
        trayCounterBg: p.error
    };

    const lines = [
        "// Yozakura - generated from the current Material palette. Do not edit:",
        "// this file is rewritten on every wallpaper / color change.",
        ""
    ];
    const entries = Base.entries;
    for (let i = 0; i < entries.length; i++) {
        const key = entries[i][0];
        const value = entries[i][1];
        let out;
        if (overrides[key] !== undefined)
            out = overrides[key];
        else if (value[0] === "#")
            out = recolor(value);
        else
            out = value;
        lines.push(key + ": " + out + ";");
    }
    // Keys missing from the Night base but present in newer clients.
    for (const key in overrides) {
        let found = false;
        for (let i = 0; i < entries.length && !found; i++)
            found = entries[i][0] === key;
        if (!found)
            lines.push(key + ": " + overrides[key] + ";");
    }
    return lines.join("\n") + "\n";
}
