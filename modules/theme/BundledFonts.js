.pragma library

// Bundled UI font registry. Every file under assets/fonts/ui/<dir>/ is
// listed here (tests/bundled-fonts.test.cjs checks both ways) and loaded at
// shell startup by FontRegistry.qml, so presets can name these families in
// theme.font / theme.monoFont / workspaces.numeralFont on any machine.
// Adding a font = its files + licence in assets/fonts/ui/<dir>/ and one
// entry here. Only OFL / Apache-2.0 fonts, subset to Latin (+ Cyrillic,
// Greek, kana where the family has them) with pyftsubset.
//
//  family   the family name the font registers (what a preset writes)
//  dir      directory under assets/fonts/ui
//  files    font files in that directory (variable fonts keep their wght axis)
//  licence  licence file in that directory
//  kind     sans | serif | mono | display (settings/AI hints)
var ROOT = "assets/fonts/ui/";

var FONTS = [
    {
        "family": "Google Sans Flex",
        "dir": "GoogleSansFlex",
        "files": ["GoogleSansFlex[wght].ttf"],
        "licence": "OFL.txt",
        "kind": "sans"
    },
    {
        "family": "Inter",
        "dir": "Inter",
        "files": ["Inter[wght].ttf"],
        "licence": "OFL.txt",
        "kind": "sans"
    },
    {
        "family": "Manrope",
        "dir": "Manrope",
        "files": ["Manrope[wght].ttf"],
        "licence": "OFL.txt",
        "kind": "sans"
    },
    {
        "family": "Nunito",
        "dir": "Nunito",
        "files": ["Nunito[wght].ttf"],
        "licence": "OFL.txt",
        "kind": "sans"
    },
    {
        "family": "Space Grotesk",
        "dir": "SpaceGrotesk",
        "files": ["SpaceGrotesk[wght].ttf"],
        "licence": "OFL.txt",
        "kind": "sans"
    },
    {
        "family": "Oswald",
        "dir": "Oswald",
        "files": ["Oswald[wght].ttf"],
        "licence": "OFL.txt",
        "kind": "display"
    },
    {
        "family": "Zen Kaku Gothic New",
        "dir": "ZenKakuGothicNew",
        "files": ["ZenKakuGothicNew-Regular.ttf", "ZenKakuGothicNew-Medium.ttf", "ZenKakuGothicNew-Bold.ttf"],
        "licence": "OFL.txt",
        "kind": "sans"
    },
    {
        "family": "Shippori Mincho",
        "dir": "ShipporiMincho",
        "files": ["ShipporiMincho-Regular.ttf", "ShipporiMincho-Medium.ttf", "ShipporiMincho-Bold.ttf"],
        "licence": "OFL.txt",
        "kind": "serif"
    },
    {
        "family": "JetBrains Mono",
        "dir": "JetBrainsMono",
        "files": ["JetBrainsMono[wght].ttf"],
        "licence": "OFL.txt",
        "kind": "mono"
    },
    {
        "family": "IBM Plex Mono",
        "dir": "IBMPlexMono",
        "files": ["IBMPlexMono-Regular.ttf", "IBMPlexMono-Medium.ttf", "IBMPlexMono-SemiBold.ttf", "IBMPlexMono-Bold.ttf"],
        "licence": "OFL.txt",
        "kind": "mono"
    }
];

// Repo-relative paths of every bundled font file.
function files() {
    var out = [];
    for (var i = 0; i < FONTS.length; i++) {
        for (var j = 0; j < FONTS[i].files.length; j++)
            out.push(ROOT + FONTS[i].dir + "/" + FONTS[i].files[j]);
    }
    return out;
}

function families() {
    return FONTS.map(function (f) {
        return f.family;
    });
}

function has(family) {
    return families().indexOf(family) !== -1;
}
