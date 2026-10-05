pragma Singleton
import QtQuick

// Live activity source "fileOps": cp, mv, rsync, dd, tar, archivers, ffmpeg progress.
// Detection lives in backend/pkg/svc/transfers (see AGENTS.md there and in
// this directory).
TransferProvider {
    source: "fileOps"
}
