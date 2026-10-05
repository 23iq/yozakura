pragma Singleton
import QtQuick

// Live activity source "browserDownloads": in-progress browser downloads in the XDG download dir.
// Detection lives in backend/pkg/svc/transfers (see AGENTS.md there and in
// this directory).
TransferProvider {
    source: "browserDownloads"
}
