"""A still wallpaper is decoded at the screen size and never drawn minified.

StaticWallpaper decodes its image with `sourceSize` = the wallpaper window
(PreserveAspectCrop: the decode covers the window, the rest is cropped) and
fills the window with it, so the texture is drawn 1:1 (or magnified when the
file is smaller than the screen). A mip chain would add a third to a
screen-sized texture without ever being sampled, so the image has none.
Checked for wide, tall, exact, small and huge files, with and without tint.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.qmlharness import Harness  # noqa: E402
from lib.waits import wait_until  # noqa: E402

from PySide6.QtGui import QColor, QImage  # noqa: E402

PALETTE = ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer",
           "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest",
           "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue",
           "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

h = Harness("static-wallpaper-scale")
h.singleton("qs.modules.theme", "Colors",
            "QtObject {\n" + "\n".join(f'    property color {n}: "#808080"' for n in PALETTE) + "\n}")
h.copy("modules/widgets/dashboard/wallpapers/StaticWallpaper.qml")

W, H = 1280, 720
images = {}
for name, (iw, ih) in {"wide": (4000, 1200), "tall": (1000, 3000), "exact": (W, H),
                       "small": (640, 480), "huge": (7680, 4320)}.items():
    img = QImage(iw, ih, QImage.Format_RGB32)
    img.fill(QColor("#336699"))
    path = h.root / f"{name}.png"
    assert img.save(str(path))
    images[name] = path

root = h.load(f"""import QtQuick
Item {{
    width: {W}; height: {H}
    property string file: ""
    property bool tint: false
    // The decoded wallpaper: StaticWallpaper's Image (its child with a fillMode).
    readonly property Image img: {{
        for (const c of still.children)
            if (c.fillMode !== undefined)
                return c;
        return null;
    }}
    StaticWallpaper {{
        id: still
        sourceFile: parent.file
        tint: parent.tint
        sourceWidth: {W}
        sourceHeight: {H}
    }}
}}""", auto_stub=False)

ok_all = True


def check(name, ok, detail=""):
    global ok_all
    ok_all &= bool(ok)
    print(("PASS " if ok else "FAIL ") + name + (" " + detail if detail else ""))


check("no mip chain on the wallpaper texture", h.eval(root, "img.mipmap") is False)
for tint in (False, True):
    root.setProperty("tint", tint)
    for name, path in images.items():
        root.setProperty("file", str(path))
        loaded = f"img.status === Image.Ready && img.source.toString().endsWith('/{path.name}')"
        wait_until(lambda expr=loaded: h.eval(root, expr))
        iw = h.eval(root, "img.implicitWidth")
        ih = h.eval(root, "img.implicitHeight")
        w = h.eval(root, "img.width")
        hh = h.eval(root, "img.height")
        # PreserveAspectCrop draws the decoded image at max(w/iw, h/ih).
        scale = max(w / iw, hh / ih) if iw and ih else 0
        check(f"{name} (tint {tint}) drawn at >= 1:1", scale >= 0.999,
              f"(decoded {iw:.0f}x{ih:.0f}, item {w:.0f}x{hh:.0f}, scale {scale:.4f})")
        root.setProperty("file", "")

sys.exit(0 if ok_all else 1)
