//
//  HydrationView.swift
//  PostFit (MomCare)
//
//  Hydration tracking with breastfeeding adjustments
//  Smart reminders and visual progress
//

import SwiftUI

// MARK: - Hydration View
struct HydrationView: View {
    @State private var glassesConsumed = 6
    @State private var dailyGoal = 10 // Adjusted for breastfeeding
    @State private var isBreastfeeding = true
    @State private var showAddDrink = false
    @State private var selectedDrinkType: DrinkType = .water
    @State private var hydrationHistory: [HydrationEntry] = []

    private var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(glassesConsumed) / Double(dailyGoal), 1.0)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Main hydration display
                    HydrationProgressCard(
                        glasses: glassesConsumed,
                        goal: dailyGoal,
                        isBreastfeeding: isBreastfeeding
                    )

                    // Quick add buttons
                    QuickAddSection(
                        onAddGlass: { addGlass() },
                        onAddCustom: { showAddDrink = true }
                    )

                    // Today's log
                    TodayHydrationLog(entries: hydrationHistory)

                    // Weekly overview
                    WeeklyHydrationChart()

                    // Tips
                    HydrationTipsSection(isBreastfeeding: isBreastfeeding)

                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.momCareBackground)
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddDrink = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.momCareHydration)
                    }
                }
            }
            .sheet(isPresented: $showAddDrink) {
                AddDrinkSheet(onAdd: { entry in
                    hydrationHistory.append(entry)
                    glassesConsumed += entry.amount / 250
                })
            }
        }
    }

    private func addGlass() {
        let entry = HydrationEntry(amount: 250, drinkType: .water)
        hydrationHistory.append(entry)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            glassesConsumed += 1
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Hydration Progress Card
struct HydrationProgressCard: View {
    let glasses: Int
    let goal: Int
    let isBreastfeeding: Bool

    @State private var animatedGlasses = 0

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(glasses) / Double(goal), 1.0)
    }

    var body: some View {
        MomCareCard(padding: 24) {
            VStack(spacing: 24) {
                // Water bottle visualization
                MomCareHydrationProgress(
                    current: glasses,
                    goal: goal,
                    isBreastfeeding: isBreastfeeding
                )

                // Stats row
                HStack(spacing: 24) {
                    HydrationStatItem(
                        value: "\(glasses * 250)",
                        unit: "ml",
                        label: "Consumed"
                    )

                    Divider()
                        .frame(height: 40)

                    HydrationStatItem(
                        value: "\(max((goal - glasses) * 250, 0))",
                        unit: "ml",
                        label: "Remaining"
                    )

                    Divider()
                        .frame(height: 40)

                    HydrationStatItem(
                        value: "\(Int(progress * 100))",
                        unit: "%",
                        label: "Progress"
                    )
                }

                // Encouragement message
                HydrationEncouragementMessage(progress: progress)
            }
        }
    }
}

struct HydrationStatItem: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.momCareNumberSmall)
                    .foregroundColor(.momCareTextPrimary)

                Text(unit)
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
            }

            Text(label)
                .font(.momCareCaption)
                .foregroundColor(.momCareTextSecondary)
        }
    }
}

struct HydrationEncouragementMessage: View {
    let progress: Double

    private var message: String {
        switch progress {
        case 0..<0.25:
            return "Let's get started! Staying hydrated helps with energy."
        case 0.25..<0.5:
            return "Good start! Keep sipping throughout the day."
        case 0.5..<0.75:
            return "Halfway there! You're doing great."
        case 0.75..<1.0:
            return "Almost there! Just a few more glasses."
        default:
            return "Amazing! You've reached your hydration goal!"
        }
    }

    private var icon: String {
        progress >= 1.0 ? "star.fill" : "drop.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.momCareHydration)

            Text(message)
                .font(.momCareBody)
                .foregroundColor(.momCareTextSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.momCareHydration.opacity(0.1))
        )
    }
}

// MARK: - Quick Add Section
struct QuickAddSection: View {
    let onAddGlass: () -> Void
    let onAddCustom: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.momCareHeading3)
                .foregroundColor(.momCareTextPrimary)

            HStack(spacing: 12) {
                // Quick add water button
                QuickAddButton(
                    title: "Glass of Water",
                    subtitle: "250ml",
                    icon: "drop.fill",
                    color: .momCareHydration,
                    action: onAddGlass
                )

                // Custom add button
                QuickAddButton(
                    title: "Other Drink",
                    subtitle: "Log custom",
                    icon: "plus",
                    color: .momCareSecondary,
                    action: onAddCustom
                )
            }
        }
    }
}

struct QuickAddButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    Text(subtitle)
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.momCareCardBackground)
                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Today's Hydration Log
struct TodayHydrationLog: View {
    let entries: [HydrationEntry]

    private var groupedEntries: [(String, Int)] {
        // Group by hour
        var groups: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        for entry in entries {
            let timeKey = formatter.string(from: entry.timestamp)
            groups[timeKey, default: 0] += entry.amount
        }

        return groups.map { ($0.key, $0.value) }.sorted { entry1, entry2 in
            guard let date1 = formatter.date(from: entry1.0),
                  let date2 = formatter.date(from: entry2.0) else { return false }
            return date1 > date2
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Log")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)

                Spacer()

                Text("\(entries.count) entries")
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
            }

            if entries.isEmpty {
                EmptyLogCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(groupedEntries.prefix(5), id: \.0) { time, amount in
                        HydrationLogRow(time: time, amount: amount)
                    }
                }
            }
        }
    }
}

struct EmptyLogCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop")
                .font(.system(size: 32))
                .foregroundColor(.momCareTextTertiary)

            Text("No drinks logged yet today")
                .font(.momCareBody)
                .foregroundColor(.momCareTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.momCareCardBackground)
        )
    }
}

struct HydrationLogRow: View {
    let time: String
    let amount: Int

    var body: some View {
        HStack {
            Image(systemName: "drop.fill")
                .font(.system(size: 14))
                .foregroundColor(.momCareHydration)

            Text(time)
                .font(.momCareBody)
                .foregroundColor(.momCareTextPrimary)

            Spacer()

            Text("\(amount)ml")
                .font(.momCareCaption)
                .foregroundColor(.momCareTextSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.momCareCardBackground)
        )
    }
}

// MARK: - Weekly Hydration Chart
struct WeeklyHydrationChart: View {
    // Sample data
    private let weekData: [Double] = [0.8, 0.7, 1.0, 0.6, 0.9, 0.75, 0.5]
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        MomCareCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("This Week")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)

                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 8) {
                            // Bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(weekData[index] >= 1.0 ? Color.momCareHydration : Color.momCareHydration.opacity(0.4))
                                .frame(width: 28, height: barHeight(for: weekData[index]))

                            // Day label
                            Text(days[index])
                                .font(.system(size: 10))
                                .foregroundColor(.momCareTextTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(for value: Double) -> CGFloat {
        let maxHeight: CGFloat = 80
        let minHeight: CGFloat = 10
        return max(minHeight, maxHeight * value)
    }
}

// MARK: - Hydration Tips Section
struct HydrationTipsSection: View {
    let isBreastfeeding: Bool

    private var tips: [HydrationTip] {
        var allTips = [
            HydrationTip(
                icon: "clock.fill",
                title: "Morning Boost",
                text: "Start your day with a glass of water to rehydrate after sleep."
            ),
            HydrationTip(
                icon: "bell.fill",
                title: "Set Reminders",
                text: "We'll remind you to drink water throughout the day."
            )
        ]

        if isBreastfeeding {
            allTips.insert(HydrationTip(
                icon: "heart.fill",
                title: "Breastfeeding Hydration",
                text: "Drink a glass of water each time you nurse to support milk production."
            ), at: 0)
        }

        return allTips
    }

    struct HydrationTip {
        let icon: String
        let title: String
        let text: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hydration Tips")
                .font(.momCareHeading3)
                .foregroundColor(.momCareTextPrimary)

            ForEach(tips.indices, id: \.self) { index in
                HydrationTipCard(tip: tips[index])
            }
        }
    }
}

struct HydrationTipCard: View {
    let tip: HydrationTipsSection.HydrationTip

    var body: some View {
        MomCareCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tip.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.momCareHydration)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(.momCareBodyBold)
                        .foregroundColor(.momCareTextPrimary)

                    Text(tip.text)
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                        .lineSpacing(4)
                }
            }
        }
    }
}

// MARK: - Add Drink Sheet
struct AddDrinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (HydrationEntry) -> Void

    @State private var selectedDrinkType: DrinkType = .water
    @State private var amount: Double = 250

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Drink type selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Drink Type")
                        .font(.momCareHeading3)
                        .foregroundColor(.momCareTextPrimary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(DrinkType.allCases, id: \.self) { type in
                            DrinkTypeButton(
                                type: type,
                                isSelected: selectedDrinkType == type
                            ) {
                                selectedDrinkType = type
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Amount slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Amount")
                            .font(.momCareHeading3)
                            .foregroundColor(.momCareTextPrimary)

                        Spacer()

                        Text("\(Int(amount))ml")
                            .font(.momCareNumberSmall)
                            .foregroundColor(.momCareHydration)
                    }

                    Slider(value: $amount, in: 100...500, step: 50)
                        .tint(.momCareHydration)

                    HStack {
                        Text("100ml")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextTertiary)

                        Spacer()

                        Text("500ml")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextTertiary)
                    }
                }
                .padding(.horizontal, 20)

                // Quick amounts
                HStack(spacing: 12) {
                    QuickAmountButton(amount: 150, selectedAmount: $amount)
                    QuickAmountButton(amount: 250, selectedAmount: $amount)
                    QuickAmountButton(amount: 350, selectedAmount: $amount)
                    QuickAmountButton(amount: 500, selectedAmount: $amount)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Add button
                MomCarePrimaryButton("Add \(Int(amount))ml of \(selectedDrinkType.rawValue)", icon: "plus") {
                    let entry = HydrationEntry(amount: Int(amount), drinkType: selectedDrinkType)
                    onAdd(entry)
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .padding(.top, 24)
            .background(Color.momCareBackground)
            .navigationTitle("Add Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.momCareTextSecondary)
                }
            }
        }
    }
}

struct DrinkTypeButton: View {
    let type: DrinkType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .momCareHydration : .momCareTextTertiary)

                Text(type.rawValue)
                    .font(.momCareCaption)
                    .foregroundColor(isSelected ? .momCareTextPrimary : .momCareTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.momCareHydration.opacity(0.15) : Color.momCareCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.momCareHydration : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct QuickAmountButton: View {
    let amount: Int
    @Binding var selectedAmount: Double

    private var isSelected: Bool {
        Int(selectedAmount) == amount
    }

    var body: some View {
        Button(action: {
            selectedAmount = Double(amount)
        }) {
            Text("\(amount)ml")
                .font(.momCareCaptionBold)
                .foregroundColor(isSelected ? .white : .momCareTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.momCareHydration : Color.momCareCardBackground)
                )
        }
    }
}

// MARK: - Preview
#Preview {
    HydrationView()
}
