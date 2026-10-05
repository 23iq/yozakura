import QtQuick
import qs.modules.services.activities

// Base of providers whose transfers come from a backend source of the same
// name (backend/pkg/svc/transfers/<source>.go). A provider file is just:
//   pragma Singleton
//   TransferProvider { source: "steam" }
ActivityProvider {
    id: provider

    backendSource: true

    transfers: provider.active ? (TransfersBackend.itemsBySource[provider.source] || []) : []

    function transferAction(transfer, action) {
        TransfersBackend.action(transfer, action);
    }
}
