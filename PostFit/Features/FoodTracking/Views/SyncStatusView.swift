//
//  SyncStatusView.swift
//  PostFit (MomCare)
//
//  iCloud sync status and manual sync controls
//

import SwiftUI

struct SyncStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKit = CloudKitManager.shared
    private let retentionManager = DataRetentionManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Sync status header
                    syncStatusHeader

                    // Data summary
                    dataSummaryCard

                    // Manual sync button
                    syncActionsCard

                    // Info card
                    infoCard

                    Spacer()
                }
                .padding(20)
            }
            .background(Color.momCareBackground)
            .navigationTitle("iCloud Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Sync Status Header

    private var syncStatusHeader: some View {
        MomCareCard {
            VStack(spacing: 16) {
                // Icon
                Image(systemName: cloudKit.syncStatus.icon)
                    .font(.system(size: 48))
                    .foregroundColor(statusColor)

                // Status text
                Text(cloudKit.syncStatus.message)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextPrimary)
                    .multilineTextAlignment(.center)

                // Last sync
                if let lastSync = cloudKit.lastSyncDate {
                    Text("Last synced: \(lastSync, style: .relative) ago")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                } else {
                    Text("Never synced")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                }

                // Progress indicator
                if cloudKit.isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .momCarePrimary))
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var statusColor: Color {
        switch cloudKit.syncStatus {
        case .idle:
            return .momCareTextSecondary
        case .syncing:
            return .momCarePrimary
        case .success:
            return .momCareSuccess
        case .error:
            return .momCareWarning
        }
    }

    // MARK: - Data Summary

    private var dataSummaryCard: some View {
        MomCareCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Storage Info")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)

                VStack(spacing: 12) {
                    storageRow(
                        icon: "iphone",
                        title: "Local Storage",
                        subtitle: "Last 90 days",
                        value: "~90 KB",
                        color: .momCarePrimary
                    )

                    Divider()

                    storageRow(
                        icon: "icloud",
                        title: "iCloud Storage",
                        subtitle: "Last 1 year",
                        value: "~360 KB",
                        color: .blue
                    )
                }

                // Info note
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.momCareInfo)

                    Text("Older data is automatically cleaned up to keep your app fast and lightweight.")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                }
                .padding(.top, 8)
            }
        }
    }

    private func storageRow(icon: String, title: String, subtitle: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.momCareBodyBold)
                    .foregroundColor(.momCareTextPrimary)

                Text(subtitle)
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
            }

            Spacer()

            Text(value)
                .font(.momCareBodyBold)
                .foregroundColor(color)
        }
    }

    // MARK: - Sync Actions

    private var syncActionsCard: some View {
        MomCareCard {
            VStack(spacing: 16) {
                Text("Sync Actions")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    MomCarePrimaryButton("Sync Now", icon: "arrow.triangle.2.circlepath") {
                        Task {
                            // Trigger manual sync
                            // await retentionManager.performFullSync(with: [])
                        }
                    }
                    .disabled(cloudKit.isSyncing)

                    Text("Auto-sync happens when you add new food entries")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        MomCareCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.momCareAccent)

                    Text("How it works")
                        .font(.momCareHeading3)
                        .foregroundColor(.momCareTextPrimary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    infoPoint(
                        icon: "arrow.up.icloud",
                        text: "New entries automatically sync to iCloud"
                    )

                    infoPoint(
                        icon: "iphone.and.arrow.forward",
                        text: "Local data: Last 90 days (lightweight & fast)"
                    )

                    infoPoint(
                        icon: "icloud.and.arrow.down",
                        text: "Cloud data: Last 1 year (access history anytime)"
                    )

                    infoPoint(
                        icon: "trash",
                        text: "Old data auto-deleted to save space"
                    )
                }
            }
        }
    }

    private func infoPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.momCarePrimary)
                .frame(width: 20)

            Text(text)
                .font(.momCareBody)
                .foregroundColor(.momCareTextSecondary)
        }
    }
}

#Preview {
    SyncStatusView()
}
