pragma Singleton
import QtQuick
import QtQml.Models
import "BundledFonts.js" as BundledFonts

// Loads every bundled UI font (BundledFonts.js, assets/fonts/ui) into the
// application font database, so theme.font / theme.monoFont can name them
// like installed fonts. shell.qml touches `count` before any surface is
// created. A family that is neither bundled nor installed falls back to
// Qt's default sans (fontconfig), never to an empty face.
QtObject {
    id: root

    readonly property var families: BundledFonts.families()
    readonly property int count: loaders.count

    function has(family) {
        return BundledFonts.has(family);
    }

    property Instantiator loaders: Instantiator {
        model: BundledFonts.files()

        delegate: FontLoader {
            required property string modelData
            source: Qt.resolvedUrl("../../" + modelData)
            onStatusChanged: {
                if (status === FontLoader.Error)
                    console.warn("FontRegistry: cannot load", modelData);
            }
        }
    }
}
