pragma Singleton
import QtQuick

// Live activity source "steam": Steam game downloads and updates.
// Detection lives in backend/pkg/svc/transfers (see AGENTS.md there and in
// this directory).
TransferProvider {
    source: "steam"
}
