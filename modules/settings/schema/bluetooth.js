.pragma library

// Bluetooth as a list page (form "list"): the band shows the devices
// connected now and turns Bluetooth on and off; your devices scroll in
// their card, the picked one's details (battery, connect, pair, forget)
// beside it. Live system state (BluetoothService), no config keys. Entry
// format: see modules/settings/AGENTS.md.

var category = {
    "id": "bluetooth",
    "icon": "bluetooth",
    "title": "prefs.cat.bluetooth",
    "description": "prefs.cat.bluetooth.desc",
    "keywords": "bluetooth devices pairing pair headphones earbuds mouse keyboard controller",
    "form": "list",
    "stage": "BluetoothBand",
    "hero": {
        "hint": "prefs.bt.hint"
    },
    "row": ["devices", "device"],
    "sections": [
        {
            "id": "devices",
            "title": "prefs.bt.section.devices",
            "entries": [
                {
                    "id": "bluetooth.list",
                    "type": "custom",
                    "component": "BluetoothList",
                    "resettable": false,
                    "label": "prefs.bt.section.devices",
                    "description": "prefs.bt.list.desc",
                    "keywords": "devices paired nearby headphones speaker mouse keyboard"
                }
            ]
        },
        {
            "id": "device",
            "title": "prefs.bt.section.device",
            "entries": [
                {
                    "id": "bluetooth.details",
                    "type": "custom",
                    "component": "BluetoothDetails",
                    "resettable": false,
                    "label": "prefs.bt.section.device",
                    "description": "prefs.bt.details.desc",
                    "keywords": "connect disconnect pair forget battery"
                }
            ]
        }
    ]
};
