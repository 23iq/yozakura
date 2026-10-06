pragma Singleton
import QtQuick
import qs.config
import qs.modules.services

// Gate of the decorative signatures (theme.signatures.*): each one needs its
// flag on and the shell not "quiet" (game mode or the power-saver profile),
// so they cost nothing where performance matters. Petals also need motion.
QtObject {
    id: root

    readonly property bool quiet: GameModeClient.toggled || PowerProfileClient.currentProfile === "power-saver"
    readonly property bool brush: !!Config.theme.signatures.brushHighlight && !quiet
    readonly property bool petals: !!Config.theme.signatures.petals && !quiet && Config.animDuration > 0
}
