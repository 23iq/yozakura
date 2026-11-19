import QtQuick

// A Repeater whose items can be read from a binding. Inside a view built
// asynchronously (WarmLoader, KeepAliveLoader, LivePart) `count` changes
// before the delegates exist, and `itemAt()` notifies nothing, so a binding
// on them stays null until something else re-evaluates it. liveItemAt()
// re-evaluates the binding whenever an item is added or removed. Imperative
// code (handlers, functions) can keep calling itemAt().
Repeater {
    id: root

    property int _revision: 0

    function liveItemAt(index: int): Item {
        return root._revision >= 0 ? root.itemAt(index) : null;
    }

    onItemAdded: root._revision++
    onItemRemoved: root._revision++
}
