pragma Singleton
import QtQuick

// Live activity source "torrents": qBittorrent, Transmission and Deluge.
// Detection lives in backend/pkg/svc/transfers (see AGENTS.md there and in
// this directory).
TransferProvider {
    source: "torrents"
}
