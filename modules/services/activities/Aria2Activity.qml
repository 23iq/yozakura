pragma Singleton
import QtQuick

// Live activity source "aria2": aria2 over JSON-RPC.
// Detection lives in backend/pkg/svc/transfers (see AGENTS.md there and in
// this directory).
TransferProvider {
    source: "aria2"
}
