//
//  DataRetentionManager.swift
//  PostFit (MomCare)
//
//  Manages local and cloud data retention policies
//  Local: 90 days | Cloud: 1 year
//

import Foundation

@MainActor
class DataRetentionManager {
    static let shared = DataRetentionManager()

    // Retention policies
    private let localRetentionDays = 90
    private let cloudRetentionDays = 365

    private let cloudKit = CloudKitManager.shared
    private let userDefaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let lastCleanupDate = "lastDataCleanupDate"
        static let lastCloudCleanupDate = "lastCloudCleanupDate"
    }

    private init() {}

    // MARK: - Auto Sync on New Entry

    func syncNewEntry(_ entry: FoodEntry) async {
        #if DEBUG
        print("🔄 [Retention] Auto-syncing new entry to iCloud")
        #endif

        do {
            try await cloudKit.syncFoodEntries([entry])
        } catch {
            #if DEBUG
            print("❌ [Retention] Auto-sync failed: \(error)")
            #endif
        }
    }

    // MARK: - Cleanup Local Data

    func cleanupLocalData(from dailyNutritions: inout [DailyNutrition]) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -localRetentionDays, to: Date())!

        let initialCount = dailyNutritions.count

        #if DEBUG
        print("🧹 [Retention] Cleaning local data older than \(localRetentionDays) days (before \(cutoffDate))")
        print("📊 [Retention] Initial count: \(initialCount) days")
        #endif

        // Remove daily nutrition entries older than 90 days
        dailyNutritions.removeAll { nutrition in
            nutrition.date < cutoffDate
        }

        let removedCount = initialCount - dailyNutritions.count

        #if DEBUG
        print("✅ [Retention] Removed \(removedCount) old local entries")
        print("📊 [Retention] Remaining: \(dailyNutritions.count) days")
        #endif

        // Update last cleanup date
        userDefaults.set(Date(), forKey: Keys.lastCleanupDate)
    }

    // MARK: - Cleanup Cloud Data

    func cleanupCloudData() async {
        #if DEBUG
        print("🧹 [Retention] Cleaning cloud data older than \(cloudRetentionDays) days")
        #endif

        do {
            try await cloudKit.deleteCloudDataOlderThan(days: cloudRetentionDays)
            userDefaults.set(Date(), forKey: Keys.lastCloudCleanupDate)

            #if DEBUG
            print("✅ [Retention] Cloud cleanup completed")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Retention] Cloud cleanup failed: \(error)")
            #endif
        }
    }

    // MARK: - Full Sync

    func performFullSync(with dailyNutritions: [DailyNutrition]) async {
        #if DEBUG
        print("🔄 [Retention] Starting full sync...")
        #endif

        // Collect all entries from last 90 days
        var entriesToSync: [FoodEntry] = []

        for nutrition in dailyNutritions {
            entriesToSync.append(contentsOf: nutrition.entries)
        }

        #if DEBUG
        print("📤 [Retention] Syncing \(entriesToSync.count) entries to iCloud")
        #endif

        do {
            try await cloudKit.syncFoodEntries(entriesToSync)

            #if DEBUG
            print("✅ [Retention] Full sync completed")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Retention] Full sync failed: \(error)")
            #endif
        }
    }

    // MARK: - Fetch Historical Data

    func fetchHistoricalData(from startDate: Date, to endDate: Date) async throws -> [FoodEntry] {
        #if DEBUG
        print("📥 [Retention] Fetching historical data from iCloud")
        print("📅 [Retention] Date range: \(startDate) to \(endDate)")
        #endif

        let entries = try await cloudKit.fetchFoodEntries(from: startDate, to: endDate)

        #if DEBUG
        print("✅ [Retention] Fetched \(entries.count) historical entries")
        #endif

        return entries
    }

    // MARK: - Should Run Cleanup

    func shouldRunCleanup() -> Bool {
        guard let lastCleanup = userDefaults.object(forKey: Keys.lastCleanupDate) as? Date else {
            return true // Never run before
        }

        // Run cleanup once per day
        let daysSinceLastCleanup = Calendar.current.dateComponents([.day], from: lastCleanup, to: Date()).day ?? 0
        return daysSinceLastCleanup >= 1
    }

    func shouldRunCloudCleanup() -> Bool {
        guard let lastCleanup = userDefaults.object(forKey: Keys.lastCloudCleanupDate) as? Date else {
            return true // Never run before
        }

        // Run cloud cleanup once per week
        let daysSinceLastCleanup = Calendar.current.dateComponents([.day], from: lastCleanup, to: Date()).day ?? 0
        return daysSinceLastCleanup >= 7
    }

    // MARK: - Data Summary

    func getDataSummary(from dailyNutritions: [DailyNutrition]) -> DataSummary {
        let totalEntries = dailyNutritions.reduce(0) { $0 + $1.entries.count }
        let oldestDate = dailyNutritions.map { $0.date }.min()
        let newestDate = dailyNutritions.map { $0.date }.max()

        let daysCovered = dailyNutritions.count
        let estimatedLocalSize = totalEntries * 250 // bytes per entry
        let estimatedCloudSize = estimatedLocalSize * 4 // Assuming 1 year = 4× 90 days

        return DataSummary(
            totalEntries: totalEntries,
            daysCovered: daysCovered,
            oldestDate: oldestDate,
            newestDate: newestDate,
            localStorageBytes: estimatedLocalSize,
            cloudStorageBytes: estimatedCloudSize
        )
    }
}

// MARK: - Data Summary

struct DataSummary {
    let totalEntries: Int
    let daysCovered: Int
    let oldestDate: Date?
    let newestDate: Date?
    let localStorageBytes: Int
    let cloudStorageBytes: Int

    var localStorageMB: Double {
        Double(localStorageBytes) / 1_048_576
    }

    var cloudStorageMB: Double {
        Double(cloudStorageBytes) / 1_048_576
    }

    var formattedLocalSize: String {
        if localStorageBytes < 1024 {
            return "\(localStorageBytes) B"
        } else if localStorageBytes < 1_048_576 {
            return String(format: "%.1f KB", Double(localStorageBytes) / 1024)
        } else {
            return String(format: "%.2f MB", localStorageMB)
        }
    }

    var formattedCloudSize: String {
        if cloudStorageBytes < 1024 {
            return "\(cloudStorageBytes) B"
        } else if cloudStorageBytes < 1_048_576 {
            return String(format: "%.1f KB", Double(cloudStorageBytes) / 1024)
        } else {
            return String(format: "%.2f MB", cloudStorageMB)
        }
    }
}
