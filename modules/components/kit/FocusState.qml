pragma Singleton

import QtQuick
import Quickshell

// Whether focus rings show: true once focus moved by the keyboard, false
// after a programmatic first focus (a surface focusing its main control on
// open shows no ring until the user starts using the keys). Surfaces set it
// (StageView); FocusRing reads it.
Singleton {
    property bool keyboard: true
}
