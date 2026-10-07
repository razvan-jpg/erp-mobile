import SwiftUI

struct PendingSyncView: View {
    @ObservedObject private var syncEngine = SyncEngine.shared
    @State private var items: [SyncOutboxItem] = []

    var body: some View {
        List {
            Section {
                HStack {
                    Label(
                        syncEngine.isOnlineLabel,
                        systemImage: syncEngine.isOnlineIcon
                    )
                    Spacer()
                    if syncEngine.isSyncing {
                        ProgressView()
                    }
                }
                if let lastError = syncEngine.lastError, !lastError.isEmpty {
                    Text(lastError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if items.isEmpty {
                Section {
                    Text(L10n.tr("offline.pending.empty"))
                        .foregroundColor(AppColors.secondary)
                }
            } else {
                Section(L10n.tr("offline.pending.section")) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.body.weight(.semibold))
                            Text(item.operationType.rawValue)
                                .font(.caption2)
                                .foregroundColor(AppColors.secondary)
                            Text(statusLabel(item))
                                .font(.caption)
                                .foregroundColor(item.status == .failed ? .red : AppColors.secondary)
                            if let error = item.lastError, !error.isEmpty {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                syncEngine.discardItem(id: item.id)
                                reload()
                            } label: {
                                Label(L10n.tr("offline.pending.discard"), systemImage: "trash")
                            }
                        }
                    }
                }

                Section {
                    Button {
                        syncEngine.retryAllFailed()
                        reload()
                    } label: {
                        Label(L10n.tr("offline.pending.retry"), systemImage: "arrow.clockwise")
                    }
                    Button {
                        syncEngine.scheduleSync(reason: "manual")
                        reload()
                    } label: {
                        Label(L10n.tr("offline.pending.sync_now"), systemImage: "icloud.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("offline.pending.title"))
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .offlineSyncStateDidChange)) { _ in
            reload()
        }
    }

    private func reload() {
        items = syncEngine.pendingItems()
    }

    private func statusLabel(_ item: SyncOutboxItem) -> String {
        switch item.status {
        case .pending: return L10n.tr("offline.status.pending")
        case .syncing: return L10n.tr("offline.status.syncing")
        case .failed: return L10n.tr("offline.status.failed")
        }
    }
}

private extension SyncEngine {
    var isOnlineLabel: String {
        NetworkMonitor.shared.isOnline
            ? L10n.tr("offline.status.online")
            : L10n.tr("offline.status.offline")
    }

    var isOnlineIcon: String {
        NetworkMonitor.shared.isOnline ? "wifi" : "wifi.slash"
    }
}
