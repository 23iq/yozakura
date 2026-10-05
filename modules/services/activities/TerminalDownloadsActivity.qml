pragma Singleton
import QtQuick

// Live activity source "terminal": curl, wget, yt-dlp and other terminal downloaders.
// Detection lives in backend/pkg/svc/transfers (see AGENTS.md there and in
// this directory).
TransferProvider {
    source: "terminal"
}
