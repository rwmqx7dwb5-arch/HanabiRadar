import Foundation
import SwiftData

/// Persists measurement session summaries and enforces the free-tier retention limit.
///
/// The free tier keeps only the most recent `retentionLimit` sessions (§18); premium
/// passes `nil` for unlimited storage. The estimation engine itself is identical in both
/// tiers — only retention differs (§18: 科学的な計算精度を有料版だけに限定しない).
@MainActor
final class SessionStore {
    private let context: ModelContext
    private let retentionLimit: Int?

    init(context: ModelContext, retentionLimit: Int? = 3) {
        self.context = context
        self.retentionLimit = retentionLimit
    }

    /// Sessions newest-first.
    func allSessions() throws -> [MeasurementSessionRecord] {
        try context.fetch(
            FetchDescriptor<MeasurementSessionRecord>(
                sortBy: [SortDescriptor(\MeasurementSessionRecord.startedAt, order: .reverse)]
            )
        )
    }

    /// Inserts a record, then trims to the retention limit (drops the oldest).
    func save(_ record: MeasurementSessionRecord) throws {
        context.insert(record)
        try context.save()
        try enforceRetentionLimit()
    }

    func delete(_ record: MeasurementSessionRecord) throws {
        context.delete(record)
        try context.save()
    }

    func deleteAll() throws {
        for record in try allSessions() { context.delete(record) }
        try context.save()
    }

    /// Trims stored sessions to the retention limit, deleting the oldest first. No-op for
    /// an unlimited (premium) store.
    func enforceRetentionLimit() throws {
        guard let limit = retentionLimit, limit >= 0 else { return }
        let all = try allSessions()            // newest-first
        guard all.count > limit else { return }
        for record in all[limit...] { context.delete(record) }
        try context.save()
    }
}
