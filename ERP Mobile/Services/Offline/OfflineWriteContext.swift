import Foundation

enum OfflineWriteContext {
    /// Set while `SyncEngine` drains the outbox so domain services call Supabase directly.
    @TaskLocal static var isSyncDrain = false
}
