//
//  CloudKitManager.swift
//  PostFit (MomCare)
//
//  iCloud CloudKit sync manager
//  Syncs last 1 year of data to iCloud
//

import Foundation
import CloudKit

// MARK: - Cloud Sync Manager

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    // CloudKit containers - lazy initialization
    private var _container: CKContainer?
    private var _privateDatabase: CKDatabase?
    private var didAttemptInitialization = false

    // Sync state
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false

    // Record types
    enum RecordType: String {
        case foodEntry = "FoodEntry"
        case dailyNutrition = "DailyNutrition"
        case hydrationEntry = "HydrationEntry"
    }

    private init() {
        #if DEBUG
        print("☁️ [CloudKit] Manager created (lazy initialization)")
        #endif
    }

    // MARK: - Lazy Container Access

    private var container: CKContainer? {
        guard !didAttemptInitialization else { return _container }

        didAttemptInitialization = true

        // IMPORTANT: iCloud is currently disabled (entitlements commented out)
        // Do NOT attempt to create CKContainer to avoid entitlement errors
        #if DEBUG
        print("⚠️ [CloudKit] Disabled - iCloud entitlements are not active")
        #endif
        syncStatus = .error("iCloud sync disabled")

        // Return nil to prevent any CloudKit access
        return nil
    }

    private var privateDatabase: CKDatabase? {
        _ = container // Trigger lazy initialization
        return _privateDatabase
    }

    // MARK: - iCloud Account Status

    func checkiCloudStatus() async -> Bool {
        // Check if container is available (it won't be while entitlements are disabled)
        guard let container = container else {
            #if DEBUG
            print("⚠️ [CloudKit] CloudKit not available (entitlements disabled)")
            #endif
            syncStatus = .error("iCloud sync disabled")
            return false
        }

        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                #if DEBUG
                print("☁️ [CloudKit] iCloud account available")
                #endif
                return true
            case .noAccount:
                #if DEBUG
                print("⚠️ [CloudKit] No iCloud account")
                #endif
                syncStatus = .error("No iCloud account signed in")
                return false
            case .restricted:
                #if DEBUG
                print("⚠️ [CloudKit] iCloud restricted")
                #endif
                syncStatus = .error("iCloud access restricted")
                return false
            case .couldNotDetermine:
                #if DEBUG
                print("⚠️ [CloudKit] iCloud status undetermined")
                #endif
                syncStatus = .error("iCloud status unknown")
                return false
            @unknown default:
                #if DEBUG
                print("⚠️ [CloudKit] Unknown iCloud status")
                #endif
                syncStatus = .error("iCloud status unknown")
                return false
            }
        } catch {
            #if DEBUG
            print("❌ [CloudKit] Error checking account: \(error)")
            #endif
            syncStatus = .error(error.localizedDescription)
            return false
        }
    }

    // MARK: - Sync Food Entries

    func syncFoodEntries(_ entries: [FoodEntry]) async throws {
        guard await checkiCloudStatus() else {
            throw CloudSyncError.iCloudUnavailable
        }

        isSyncing = true
        syncStatus = .syncing

        #if DEBUG
        print("☁️ [CloudKit] Syncing \(entries.count) food entries...")
        #endif

        var successCount = 0

        for entry in entries {
            do {
                try await saveFoodEntry(entry)
                successCount += 1
            } catch {
                #if DEBUG
                print("❌ [CloudKit] Failed to sync entry: \(entry.name) - \(error)")
                #endif
            }
        }

        lastSyncDate = Date()
        isSyncing = false
        syncStatus = .success("Synced \(successCount) of \(entries.count) entries")

        #if DEBUG
        print("✅ [CloudKit] Sync completed: \(successCount)/\(entries.count)")
        #endif
    }

    // MARK: - Save Individual Entry

    private func saveFoodEntry(_ entry: FoodEntry) async throws {
        guard let privateDatabase = privateDatabase else {
            throw CloudSyncError.iCloudUnavailable
        }

        let record = CKRecord(recordType: RecordType.foodEntry.rawValue)
        record["id"] = entry.id.uuidString
        record["name"] = entry.name
        record["mealType"] = entry.mealType.rawValue
        record["calories"] = entry.calories as CKRecordValue
        record["protein"] = entry.protein as CKRecordValue
        record["carbohydrates"] = entry.carbohydrates as CKRecordValue
        record["fat"] = entry.fat as CKRecordValue
        record["fiber"] = entry.fiber as CKRecordValue
        record["sugar"] = entry.sugar as CKRecordValue
        record["sodium"] = entry.sodium as CKRecordValue
        record["iron"] = entry.iron as CKRecordValue
        record["calcium"] = entry.calcium as CKRecordValue
        record["servingSize"] = entry.servingSize
        record["servingCount"] = entry.servingCount as CKRecordValue
        record["isAIRecognized"] = entry.isAIRecognized ? 1 : 0
        record["timestamp"] = entry.timestamp as CKRecordValue

        if let notes = entry.notes {
            record["notes"] = notes
        }

        try await privateDatabase.save(record)
    }

    // MARK: - Fetch Historical Data

    func fetchFoodEntries(from startDate: Date, to endDate: Date) async throws -> [FoodEntry] {
        guard await checkiCloudStatus() else {
            throw CloudSyncError.iCloudUnavailable
        }

        guard let privateDatabase = privateDatabase else {
            throw CloudSyncError.iCloudUnavailable
        }

        #if DEBUG
        print("☁️ [CloudKit] Fetching entries from \(startDate) to \(endDate)")
        #endif

        let predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@",
            startDate as NSDate,
            endDate as NSDate
        )

        let query = CKQuery(recordType: RecordType.foodEntry.rawValue, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        let results = try await privateDatabase.records(matching: query)
        var entries: [FoodEntry] = []

        for (_, result) in results.matchResults {
            switch result {
            case .success(let record):
                if let entry = foodEntryFromRecord(record) {
                    entries.append(entry)
                }
            case .failure(let error):
                #if DEBUG
                print("❌ [CloudKit] Failed to fetch record: \(error)")
                #endif
            }
        }

        #if DEBUG
        print("✅ [CloudKit] Fetched \(entries.count) entries")
        #endif

        return entries
    }

    // MARK: - Convert CloudKit Record to FoodEntry

    private func foodEntryFromRecord(_ record: CKRecord) -> FoodEntry? {
        guard
            let idString = record["id"] as? String,
            let id = UUID(uuidString: idString),
            let name = record["name"] as? String,
            let mealTypeString = record["mealType"] as? String,
            let mealType = MealType(rawValue: mealTypeString),
            let calories = record["calories"] as? Int,
            let protein = record["protein"] as? Double,
            let carbs = record["carbohydrates"] as? Double,
            let fat = record["fat"] as? Double,
            let fiber = record["fiber"] as? Double,
            let sugar = record["sugar"] as? Double,
            let sodium = record["sodium"] as? Double,
            let iron = record["iron"] as? Double,
            let calcium = record["calcium"] as? Double,
            let servingSize = record["servingSize"] as? String,
            let servingCount = record["servingCount"] as? Double,
            let isAIInt = record["isAIRecognized"] as? Int,
            let timestamp = record["timestamp"] as? Date
        else {
            return nil
        }

        return FoodEntry(
            id: id,
            name: name,
            mealType: mealType,
            calories: calories,
            protein: protein,
            carbohydrates: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            iron: iron,
            calcium: calcium,
            servingSize: servingSize,
            servingCount: servingCount,
            isAIRecognized: isAIInt == 1,
            timestamp: timestamp,
            notes: record["notes"] as? String
        )
    }

    // MARK: - Delete Old Cloud Data

    func deleteCloudDataOlderThan(days: Int) async throws {
        guard let privateDatabase = privateDatabase else {
            throw CloudSyncError.iCloudUnavailable
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        #if DEBUG
        print("☁️ [CloudKit] Deleting cloud data older than \(days) days (before \(cutoffDate))")
        #endif

        let predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
        let query = CKQuery(recordType: RecordType.foodEntry.rawValue, predicate: predicate)

        let results = try await privateDatabase.records(matching: query)
        var deleteCount = 0

        for (recordID, _) in results.matchResults {
            do {
                try await privateDatabase.deleteRecord(withID: recordID)
                deleteCount += 1
            } catch {
                #if DEBUG
                print("❌ [CloudKit] Failed to delete record: \(error)")
                #endif
            }
        }

        #if DEBUG
        print("✅ [CloudKit] Deleted \(deleteCount) old records from cloud")
        #endif
    }
}

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success(String)
    case error(String)

    var message: String {
        switch self {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .success(let msg):
            return msg
        case .error(let msg):
            return msg
        }
    }

    var icon: String {
        switch self {
        case .idle:
            return "icloud"
        case .syncing:
            return "icloud.and.arrow.up"
        case .success:
            return "checkmark.icloud"
        case .error:
            return "exclamationmark.icloud"
        }
    }
}

// MARK: - Errors

enum CloudSyncError: Error, LocalizedError {
    case iCloudUnavailable
    case syncFailed
    case dataCorrupted

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        case .syncFailed:
            return "Failed to sync data to iCloud."
        case .dataCorrupted:
            return "Cloud data is corrupted."
        }
    }
}
