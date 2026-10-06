pragma Singleton
import QtQuick
import Quickshell

// Hub between the OSD and the island. The OSD side (volume, mic,
// brightness, output device changes) calls `toIsland(...)` when the OSD is
// routed into the notch (notch.osd / layout.osd.style "island"); the
// island's OsdActivity shows it as an ephemeral level segment.
//   kind    "volume" | "mic" | "brightness" | "device"
//   value   level 0..1
//   muted   distinct muted state
//   device  output/input device name ("" when unchanged)
Singleton {
    id: root

    signal toIsland(string kind, real value, bool muted, string device)
}
