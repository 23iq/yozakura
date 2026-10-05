pragma Singleton
import QtQuick

// Live activity source "launchers": Heroic and Lutris installs.
// Detection lives in backend/pkg/svc/transfers (see AGENTS.md there and in
// this directory).
TransferProvider {
    source: "launchers"
}
