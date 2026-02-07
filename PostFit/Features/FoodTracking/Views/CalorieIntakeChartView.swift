//
//  CalorieIntakeChartView.swift
//  PostFit (MomCare)
//
//  Interactive 30-day calorie intake chart using Swift Charts
//  Shows daily calorie intake with goal lines and postpartum-specific indicators
//
//  Features:
//  - Line chart with area gradient showing daily calorie intake
//  - Data points with larger marker for current day
//  - Smooth curve interpolation for better visualization
//  - Dashed line style for estimated days (no meals logged)
//  - Goal line with breastfeeding adjustment
//  - Minimum calorie threshold indicator
//  - Tap interaction for day details
//  - Animated entrance
//

import SwiftUI
import Charts

// MARK: - Calorie Intake Chart View

/// Main chart view displaying 30 days of calorie intake data
struct CalorieIntakeChartView: View {
    @StateObject private var viewModel = CalorieChartViewModel()
    @State private var chartHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .loading:
                loadingView

            case .loaded(let data):
                chartContent(data: data)

            case .empty:
                emptyStateView

            case .error(let error):
                errorView(error: error)
            }
        }
        .task {
            await viewModel.loadChartData()
        }
    }

    // MARK: - Chart Content

    @ViewBuilder
    private func chartContent(data: CalorieChartData) -> some View {
        MomCareCard(padding: 16, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                chartHeader(data: data)

                // Chart
                chartView(data: data)
                    .frame(height: chartHeight)

                // Summary stats
                if let summary = viewModel.summary {
                    summaryView(summary: summary)
                }

                // Encouragement message
                if let summary = viewModel.summary {
                    encouragementBanner(message: summary.encouragementMessage)
                }
            }
        }
        .sheet(isPresented: $viewModel.showDetailPopover) {
            if let selectedDay = viewModel.selectedDay {
                DayDetailSheet(day: selectedDay, isBreastfeeding: data.isBreastfeeding)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Chart Header

    private func chartHeader(data: CalorieChartData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calorie Intake")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)

                Text("Last 30 days")
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)
            }

            Spacer()

            // Legend button
            Menu {
                Toggle(isOn: $viewModel.chartOptions.showGoalLine) {
                    Label("Daily Goal", systemImage: "target")
                }

                Toggle(isOn: $viewModel.chartOptions.showMinimumLine) {
                    Label("Minimum (1800 cal)", systemImage: "exclamationmark.triangle")
                }

                if data.isBreastfeeding {
                    Toggle(isOn: $viewModel.chartOptions.showBreastfeedingAdjustment) {
                        Label("Breastfeeding Bonus", systemImage: "heart.fill")
                    }
                }

                Divider()

                // Info about estimated data
                if data.hasEstimatedData {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Estimated Days")
                                .font(.momCareCaption)
                            Text("Dashed line = no meals logged")
                                .font(.system(size: 11))
                                .foregroundColor(.momCareTextTertiary)
                        }
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .opacity(0.5)
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.momCareTextSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.momCareSecondaryBackground))
            }
        }
    }

    // MARK: - Main Chart View

    private func chartView(data: CalorieChartData) -> some View {
        Chart {
            // Draw area under the line for visual appeal
            ForEach(data.dailyData) { day in
                AreaMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Calories", viewModel.isAnimating ? day.totalCalories : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            lineColor(for: day, data: data).opacity(0.3),
                            lineColor(for: day, data: data).opacity(0.05)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(day.isEstimated ? 0.35 : 1.0)
            }

            // Draw the main line
            ForEach(data.dailyData) { day in
                LineMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Calories", viewModel.isAnimating ? day.totalCalories : 0)
                )
                .foregroundStyle(lineColor(for: day, data: data))
                .lineStyle(StrokeStyle(
                    lineWidth: day.isEstimated ? 2 : 3,
                    dash: day.isEstimated ? [5, 3] : []
                ))
                .interpolationMethod(.catmullRom)
            }

            // Draw data points for each day
            ForEach(data.dailyData) { day in
                PointMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Calories", viewModel.isAnimating ? day.totalCalories : 0)
                )
                .foregroundStyle(lineColor(for: day, data: data))
                .symbolSize(day.isToday ? 80 : (day.isEstimated ? 30 : 50))
                .opacity(day.isEstimated ? 0.5 : 1.0)
            }

            // Goal line
            if viewModel.chartOptions.showGoalLine {
                RuleMark(
                    y: .value("Goal", data.adjustedCalorieGoal)
                )
                .foregroundStyle(Color.momCareSuccess.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Goal: \(data.adjustedCalorieGoal)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.momCareSuccess)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.momCareSuccess.opacity(0.15))
                        )
                }
            }

            // Minimum calorie line
            if viewModel.chartOptions.showMinimumLine {
                RuleMark(
                    y: .value("Minimum", NutritionConstants.minimumPostpartumCalories)
                )
                .foregroundStyle(Color.momCareWarning.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .annotation(position: .bottom, alignment: .leading) {
                    Text("Min: 1800")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.momCareWarning)
                }
            }

            // Highlight selected day
            if let selectedDay = viewModel.selectedDay {
                RuleMark(
                    x: .value("Selected", selectedDay.date, unit: .day)
                )
                .foregroundStyle(Color.momCarePrimary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.system(size: 10))
                            .foregroundColor(.momCareTextTertiary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...max(data.maxCalories + 200, 2500))
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let x = value.location.x
                                if let date: Date = proxy.value(atX: x) {
                                    // Find the closest day
                                    if let day = data.dailyData.first(where: {
                                        Calendar.current.isDate($0.date, inSameDayAs: date)
                                    }) {
                                        viewModel.selectDay(day)
                                    }
                                }
                            }
                    )
            }
        }
        .animation(.spring(response: NutritionConstants.chartAnimationDuration, dampingFraction: 0.7), value: viewModel.isAnimating)
    }

    // MARK: - Line Color Logic

    private func lineColor(for day: DailyCalorieData, data: CalorieChartData) -> Color {
        // Highlight today
        if day.isToday && viewModel.chartOptions.highlightToday {
            return .momCarePrimary
        }

        // Color based on goal achievement
        if day.entriesCount == 0 {
            return .momCareTextTertiary
        }

        let goalProgress = day.goalProgress

        if goalProgress >= 1.0 {
            return .momCareSuccess
        } else if day.meetsMinimumRequirement {
            return .momCareNutrition
        } else {
            return .momCareWarning
        }
    }

    // MARK: - Summary View

    private func summaryView(summary: ChartSummary) -> some View {
        HStack(spacing: 16) {
            // Average calories
            SummaryStatItem(
                title: "Daily Avg",
                value: "\(summary.averageCalories)",
                unit: "cal",
                color: summary.meetsMinimum ? .momCareSuccess : .momCareWarning
            )

            Divider()
                .frame(height: 32)

            // Days met goal
            SummaryStatItem(
                title: "Goal Met",
                value: "\(summary.daysMetGoal)",
                unit: "/ \(summary.daysWithData) days",
                color: .momCareNutrition
            )

            Divider()
                .frame(height: 32)

            // Achievement rate
            SummaryStatItem(
                title: "Success",
                value: summary.goalAchievementText,
                unit: "",
                color: summary.goalAchievementRate >= 0.7 ? .momCareSuccess : .momCareAccent
            )
        }
        .padding(.vertical, 8)
    }

    // MARK: - Encouragement Banner

    private func encouragementBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 16))
                .foregroundColor(.momCarePrimary)

            Text(message)
                .font(.momCareCaption)
                .foregroundColor(.momCareTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.momCarePrimary.opacity(0.08))
        )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        MomCareCard(padding: 16, cornerRadius: 20) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calorie Intake")
                            .font(.momCareHeading3)
                            .foregroundColor(.momCareTextPrimary)

                        Text("Last 30 days")
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextTertiary)
                    }
                    Spacer()
                }

                // Placeholder chart
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<15, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.momCareTextTertiary.opacity(0.2))
                            .frame(width: 16, height: CGFloat.random(in: 40...120))
                            .shimmering()
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)

                ProgressView()
                    .tint(.momCarePrimary)
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        MomCareCard(padding: 24, cornerRadius: 20) {
            VStack(spacing: 16) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48))
                    .foregroundColor(.momCareTextTertiary)

                Text("No Nutrition Data Yet")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)

                Text("Start logging your meals to see your calorie intake trends over the past 30 days.")
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)
                    .multilineTextAlignment(.center)

                MomCarePrimaryButton("Log Your First Meal", icon: "plus.circle.fill") {
                    // Action to add meal
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Error View

    private func errorView(error: Error) -> some View {
        MomCareCard(padding: 24, cornerRadius: 20) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 48))
                    .foregroundColor(.momCareError)

                Text("Unable to Load Chart")
                    .font(.momCareHeading3)
                    .foregroundColor(.momCareTextPrimary)

                Text(error.localizedDescription)
                    .font(.momCareBody)
                    .foregroundColor(.momCareTextSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.momCareButtonSecondary)
                        .foregroundColor(.momCarePrimary)
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Summary Stat Item

struct SummaryStatItem: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.momCareCaption)
                .foregroundColor(.momCareTextTertiary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.momCareNumberSmall)
                    .foregroundColor(color)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(.momCareTextTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    let day: DailyCalorieData
    let isBreastfeeding: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Date header
                VStack(spacing: 4) {
                    Text(day.fullDateLabel)
                        .font(.momCareHeading2)
                        .foregroundColor(.momCareTextPrimary)

                    if day.isToday {
                        Text("Today")
                            .font(.momCareCaptionBold)
                            .foregroundColor(.momCarePrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.momCarePrimary.opacity(0.15))
                            )
                    }
                }

                // Calorie summary
                VStack(spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(day.totalCalories)")
                            .font(.momCareNumberLarge)
                            .foregroundColor(day.meetsMinimumRequirement ? .momCareSuccess : .momCareWarning)

                        Text("calories")
                            .font(.momCareBody)
                            .foregroundColor(.momCareTextSecondary)
                    }

                    // Estimated data indicator
                    if day.isEstimated {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.line.downtrend.xyaxis")
                                .font(.system(size: 12))
                                .foregroundColor(.momCareWarning)
                            Text("Estimated (no meals logged)")
                                .font(.momCareCaption)
                                .foregroundColor(.momCareTextSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.momCareWarning.opacity(0.1))
                        )
                    } else {
                        Text(day.dataSourceDescription)
                            .font(.momCareCaption)
                            .foregroundColor(.momCareTextTertiary)
                    }

                    // Progress bar
                    MomCareProgressBar(
                        progress: min(day.goalProgress, 1.0),
                        color: day.meetsMinimumRequirement ? .momCareNutrition : .momCareWarning,
                        height: 10,
                        showLabel: true,
                        label: "Goal: \(day.calorieGoal) cal"
                    )
                    .padding(.horizontal, 32)
                }

                // Stats grid
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        DetailStatCard(
                            icon: "target",
                            title: "Daily Goal",
                            value: "\(day.calorieGoal) cal",
                            color: .momCareSuccess
                        )

                        DetailStatCard(
                            icon: "fork.knife",
                            title: "Meals Logged",
                            value: "\(day.entriesCount)",
                            color: .momCareNutrition
                        )
                    }

                    if isBreastfeeding && day.breastfeedingAdjustment > 0 {
                        HStack(spacing: 16) {
                            DetailStatCard(
                                icon: "heart.fill",
                                title: "Breastfeeding Bonus",
                                value: "+\(day.breastfeedingAdjustment) cal",
                                color: .momCarePrimary
                            )

                            DetailStatCard(
                                icon: "checkmark.circle",
                                title: "Minimum Met",
                                value: day.meetsMinimumRequirement ? "Yes" : "No",
                                color: day.meetsMinimumRequirement ? .momCareSuccess : .momCareWarning
                            )
                        }
                    }
                }
                .padding(.horizontal)

                // Status message
                statusMessage

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.momCarePrimary)
                }
            }
        }
    }

    private var statusMessage: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.system(size: 20))
                .foregroundColor(statusColor)

            Text(statusText)
                .font(.momCareBody)
                .foregroundColor(.momCareTextSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(statusColor.opacity(0.1))
        )
        .padding(.horizontal)
    }

    private var statusIcon: String {
        if day.entriesCount == 0 {
            return "questionmark.circle"
        } else if day.goalProgress >= 1.0 {
            return "star.fill"
        } else if day.meetsMinimumRequirement {
            return "checkmark.circle"
        } else {
            return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        if day.entriesCount == 0 {
            return .momCareTextTertiary
        } else if day.goalProgress >= 1.0 {
            return .momCareSuccess
        } else if day.meetsMinimumRequirement {
            return .momCareNutrition
        } else {
            return .momCareWarning
        }
    }

    private var statusText: String {
        if day.entriesCount == 0 {
            return "No meals logged for this day"
        } else if day.goalProgress >= 1.0 {
            return "You met your calorie goal!"
        } else if day.meetsMinimumRequirement {
            return "Good nutrition! Keep nourishing yourself."
        } else {
            return "Try to reach at least 1,800 calories for healthy recovery."
        }
    }
}

// MARK: - Detail Stat Card

struct DetailStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.momCareCaption)
                    .foregroundColor(.momCareTextTertiary)

                Text(value)
                    .font(.momCareBodyBold)
                    .foregroundColor(.momCareTextPrimary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.momCareCardBackground)
                .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: phase
                    )
                }
            )
            .onAppear {
                phase = 1
            }
            .clipped()
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Preview

#Preview("Loaded State") {
    ScrollView {
        CalorieIntakeChartView()
            .padding()
    }
    .background(Color.momCareBackground)
}

#Preview("With Sample Data") {
    let viewModel = CalorieChartViewModel.preview

    ScrollView {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .loaded(let data):
                MomCareCard(padding: 16, cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Calorie Intake Chart Preview")
                            .font(.momCareHeading3)

                        Chart {
                            ForEach(data.dailyData) { day in
                                AreaMark(
                                    x: .value("Date", day.date, unit: .day),
                                    y: .value("Calories", day.totalCalories)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.momCareNutrition.opacity(0.3),
                                            Color.momCareNutrition.opacity(0.05)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }

                            ForEach(data.dailyData) { day in
                                LineMark(
                                    x: .value("Date", day.date, unit: .day),
                                    y: .value("Calories", day.totalCalories)
                                )
                                .foregroundStyle(day.isToday ? Color.momCarePrimary : Color.momCareNutrition)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                                .interpolationMethod(.catmullRom)
                            }

                            ForEach(data.dailyData) { day in
                                PointMark(
                                    x: .value("Date", day.date, unit: .day),
                                    y: .value("Calories", day.totalCalories)
                                )
                                .foregroundStyle(day.isToday ? Color.momCarePrimary : Color.momCareNutrition)
                                .symbolSize(day.isToday ? 80 : 50)
                            }

                            RuleMark(y: .value("Goal", data.adjustedCalorieGoal))
                                .foregroundStyle(Color.momCareSuccess.opacity(0.8))
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        }
                        .frame(height: 200)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.day())
                            }
                        }
                    }
                }
            default:
                Text("Not loaded")
            }
        }
        .padding()
    }
    .background(Color.momCareBackground)
}
