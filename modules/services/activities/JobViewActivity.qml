pragma Singleton
import QtQuick

// Live activity source "jobView": KDE job tracker (Dolphin/KIO copies, KGet, Plasma-aware apps).
// Detection lives in backend/pkg/svc/transfers (see AGENTS.md there and in
// this directory).
TransferProvider {
    source: "jobView"
}
