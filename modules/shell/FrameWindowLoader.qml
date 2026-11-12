pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The frame's own window (FrameWindow) of one screen: exists only while
// performance.splitFrame and the frame are on (FrameSplit.windowWanted);
// FrameSplit maps and unmaps it.
Loader {
    id: root

    required property ShellScreen targetScreen
    property FrameSplit split: null
    property bool hasFullscreenWindow: false

    active: !!root.split && root.split.windowWanted
    sourceComponent: FrameWindow {
        targetScreen: root.targetScreen
        hasFullscreenWindow: root.hasFullscreenWindow
        split: root.split
    }
}
