//
//  MomCareProgressViews.swift
//  PostFit (MomCare)
//
//  Progress indicators and tracking visualizations
//  Encouraging and positive progress displays
//

import SwiftUI

// MARK: - Circular Progress Ring
struct MomCareProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat
    let showPercentage: Bool

    @State private var animatedProgress: Double = 0

    init(
        progress: Double,
        color: Color = .momCarePrimary,
        lineWidth: CGFloat = 10,
        size: CGFloat = 100,
        showPercentage: Bool = true
    ) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
        self.showPercentage = showPercentage
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animatedProgress)

            // Percentage text
            if showPercentage {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.momCareNumberSmall)
                    .foregroundColor(.momCareTextPrimary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            animatedProgress = newValue
        }
        .accessibilityLabel("\(Int(progress * 100)) percent complete")
    }
}

// MARK: - Linear Progress Bar
struct MomCareProgressBar: View {
    let progress: Double
    let color: Color
    let height: CGFloat
    let showLabel: Bool
    let label: String?

    @State private var animatedProgress: Double = 0

    init(
        progress: Double,
        color: Color = .momCarePrimary,
        height: CGFloat = 8,
        showLabel: Bool = false,
        label: String? = nil
    ) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
        self.height = height
        self.showLabel = showLabel
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showLabel, let label = label {
                HStack {
                    Text(label)
                        .font(.momCareCaptionBold)
                        .foregroundColor(.momCareTextSecondary)

                    Spacer()

                    Text("\(Int(progress * 100))%")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextTertiary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color.opacity(0.15))
                        .frame(height: height)

                    // Progress
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color)
                        .frame(width: geometry.size.width * animatedProgress, height: height)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)
                }
            }
            .frame(height: height)
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            animatedProgress = newValue
        }
        .accessibilityLabel("\(label ?? "Progress"): \(Int(progress * 100)) percent")
    }
}

// MARK: - Hydration Progress (Water Bottle)
struct MomCareHydrationProgress: View {
    let current: Int
    let goal: Int
    let isBreastfeeding: Bool

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.0)
    }

    @State private var animatedProgress: Double = 0
    @State private var waveOffset: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            // Water bottle visualization
            ZStack {
                // Bottle shape background
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.momCareHydration.opacity(0.1))
                    .frame(width: 100, height: 160)

                // Water fill with wave animation
                GeometryReader { geometry in
                    let height = geometry.size.height * animatedProgress

                    ZStack(alignment: .bottom) {
                        // Wave effect
                        WaveShape(offset: waveOffset, percent: animatedProgress)
                            .fill(Color.momCareHydration.opacity(0.6))
                            .frame(height: height + 10)

                        // Main water fill
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.momCareHydration.opacity(0.8))
                            .frame(height: max(height - 5, 0))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .padding(4)
                }
                .frame(width: 100, height: 160)

                // Drop icon at top
                VStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.momCareHydration)
                        .opacity(animatedProgress < 0.85 ? 1 : 0)
                    Spacer()
                }
                .frame(height: 160)
                .padding(.top, 20)

                // Percentage overlay
                Text("\(current)/\(goal)")
                    .font(.momCareHeading3)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            }

            // Label
            VStack(spacing: 4) {
                Text("Glasses of Water")
                    .font(.momCareBodyBold)
                    .foregroundColor(.momCareTextPrimary)

                if isBreastfeeding {
                    Text("(Adjusted for breastfeeding)")
                        .font(.momCareCaption)
                        .foregroundColor(.momCareTextSecondary)
                }
            }
        }
        .onAppear {
            animatedProgress = progress
            startWaveAnimation()
        }
        .onChange(of: current) { _, _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = progress
            }
        }
    }

    private func startWaveAnimation() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            waveOffset = 360
        }
    }
}

// MARK: - Wave Shape for Water Animation
struct WaveShape: Shape {
    var offset: Double
    var percent: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(offset, percent) }
        set {
            offset = newValue.first
            percent = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let waveHeight: CGFloat = 5
        let yOffset: CGFloat = rect.height * (1 - percent)

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: yOffset))

        for x in stride(from: 0, to: rect.width, by: 1) {
            let relativeX = x / rect.width
            let sine = sin(relativeX * 4 * .pi + offset * .pi / 180)
            let y = yOffset + waveHeight * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Weekly Progress Chart
struct MomCareWeeklyProgress: View {
    let data: [Double] // 7 values for the week
    let color: Color
    let title: String

    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.momCareHeading3)
                .foregroundColor(.momCareTextPrimary)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                index < data.count && data[index] > 0
                                    ? color
                                    : color.opacity(0.2)
                            )
                            .frame(width: 28, height: barHeight(for: index))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05), value: data)

                        // Day label
                        Text(days[index])
                            .font(.momCareCaption)
                            .foregroundColor(
                                Calendar.current.component(.weekday, from: Date()) - 1 == index
                                    ? color
                                    : .momCareTextTertiary
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.momCareCardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard index < data.count else { return 10 }
        let maxHeight: CGFloat = 80
        let minHeight: CGFloat = 10
        return max(minHeight, maxHeight * data[index])
    }
}

// MARK: - Achievement Badge
struct MomCareAchievementBadge: View {
    let title: String
    let icon: String
    let color: Color
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? color : Color.momCareTextTertiary.opacity(0.3))
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(isUnlocked ? .white : .momCareTextTertiary)

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.momCareTextSecondary)
                        .offset(x: 20, y: 20)
                }
            }

            Text(title)
                .font(.momCareCaption)
                .foregroundColor(isUnlocked ? .momCareTextPrimary : .momCareTextTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 80)
        .accessibilityLabel("\(title) badge, \(isUnlocked ? "unlocked" : "locked")")
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 24) {
            HStack(spacing: 20) {
                MomCareProgressRing(
                    progress: 0.75,
                    color: .momCarePrimary,
                    size: 80
                )

                MomCareProgressRing(
                    progress: 0.45,
                    color: .momCareHydration,
                    size: 80
                )

                MomCareProgressRing(
                    progress: 0.90,
                    color: .momCareSuccess,
                    size: 80
                )
            }

            MomCareProgressBar(
                progress: 0.6,
                color: .momCareNutrition,
                showLabel: true,
                label: "Daily Calories"
            )
            .padding(.horizontal)

            MomCareHydrationProgress(
                current: 6,
                goal: 10,
                isBreastfeeding: true
            )

            MomCareWeeklyProgress(
                data: [0.8, 0.6, 1.0, 0.4, 0.9, 0.7, 0.3],
                color: .momCareExercise,
                title: "Exercise This Week"
            )
            .padding(.horizontal)

            HStack(spacing: 16) {
                MomCareAchievementBadge(
                    title: "First Week",
                    icon: "star.fill",
                    color: .momCareAccent,
                    isUnlocked: true
                )

                MomCareAchievementBadge(
                    title: "Hydration Hero",
                    icon: "drop.fill",
                    color: .momCareHydration,
                    isUnlocked: true
                )

                MomCareAchievementBadge(
                    title: "10K Steps",
                    icon: "figure.walk",
                    color: .momCareExercise,
                    isUnlocked: false
                )
            }
        }
        .padding()
    }
    .background(Color.momCareBackground)
}
