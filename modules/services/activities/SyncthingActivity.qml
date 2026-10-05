pragma Singleton
import QtQuick

// Live activity source "syncthing": Syncthing folders that are syncing.
// Detection lives in backend/pkg/svc/transfers (see AGENTS.md there and in
// this directory).
TransferProvider {
    source: "syncthing"
}
