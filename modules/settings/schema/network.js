.pragma library

// Network: Wi-Fi as a list page (form "list"): the band says where you are
// connected and turns Wi-Fi on and off; the networks around you scroll in
// their card, the picked one's details (signal, security, connect with a
// password, disconnect) beside it. Live system state (NetworkService), no
// config keys. Entry format: see modules/settings/AGENTS.md.

var category = {
    "id": "network",
    "icon": "wifiHigh",
    "title": "prefs.cat.network",
    "description": "prefs.cat.network.desc",
    "keywords": "network wifi wi-fi internet ethernet connection wireless password ssid",
    "form": "list",
    "stage": "NetworkBand",
    "hero": {
        "hint": "prefs.net.hint"
    },
    "row": ["networks", "details"],
    "sections": [
        {
            "id": "networks",
            "title": "prefs.net.section.networks",
            "entries": [
                {
                    "id": "network.list",
                    "type": "custom",
                    "component": "WifiList",
                    "resettable": false,
                    "label": "prefs.net.section.networks",
                    "description": "prefs.net.list.desc",
                    "keywords": "wifi networks list scan nearby ssid connect"
                }
            ]
        },
        {
            "id": "details",
            "title": "prefs.net.section.details",
            "entries": [
                {
                    "id": "network.details",
                    "type": "custom",
                    "component": "WifiDetails",
                    "resettable": false,
                    "label": "prefs.net.section.details",
                    "description": "prefs.net.details.desc",
                    "keywords": "connect disconnect password signal security band"
                }
            ]
        }
    ]
};
