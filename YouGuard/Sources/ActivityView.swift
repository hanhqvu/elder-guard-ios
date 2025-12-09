//
//  ActivityView.swift
//  ElderGuard
//
//  Created by Hanh Vu on 2025/11/29.
//

import Charts
import SwiftUI

// MARK: - Data Models

struct ActivityData: Identifiable {
	let id = UUID()
	let date: Date
	let standingDuration: Double // in hours
	let sittingDuration: Double
	let lyingDuration: Double

	var totalDuration: Double {
		standingDuration + sittingDuration + lyingDuration
	}
}

enum TimePeriod: String, CaseIterable {
	case daily = "D"
	case weekly = "W"
	case monthly = "M"
}

enum ActivityType: String, CaseIterable {
	case standing = "Standing"
	case sitting = "Sitting"
	case lying = "Lying"

	var color: Color {
		switch self {
			case .standing: return .green
			case .sitting: return .blue
			case .lying: return .orange
		}
	}
}

struct ActivityStatus {
	let average: Double
	let statusText: String
	let statusColor: Color
	let icon: String
}

// MARK: - Mock Data Generator

class ActivityDataGenerator {
	// D: Last 24 hours by hour
	// Average: 7.7h lying (32%), 10.4h sitting (43.3%), 3.1h standing (12.9%) = 21.2h (rest 11.2%)
	// Total 24h = 100%, Current day: standing much below average
	static func generateDailyData() -> [ActivityData] {
		let calendar = Calendar.current
		let now = Date()

		return (0 ..< 24).map { hourIndex in
			let hourOffset = 23 - hourIndex
			let date = calendar.date(byAdding: .hour, value: -hourOffset, to: now)!

			// Each hour = 1/24 of the day
			// Target: ~1.5h standing (6.25%), ~10.5h sitting (43.75%), ~12h lying (50%)
			let standing = Double.random(in: 0.05 ... 0.08) // ~1.5h total
			let sitting = Double.random(in: 0.42 ... 0.46) // ~10.5h total
			let lying = 1.0 - standing - sitting // Remaining time to make 100%

			return ActivityData(
				date: date,
				standingDuration: standing,
				sittingDuration: sitting,
				lyingDuration: lying
			)
		}
	}

	// W: Last 7 days by day
	// Average: 7.7h lying (32%), 10.4h sitting (43.3%), 3.1h standing (12.9%) = 21.2h
	// Total 24h = 100%, Shows gradual decline in standing over the week
	static func generateWeeklyData() -> [ActivityData] {
		let calendar = Calendar.current
		let today = Date()

		return (0 ..< 7).map { dayIndex in
			let dayOffset = 6 - dayIndex
			let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!

			// Progress from 0 (7 days ago) to 1 (today)
			let progress = Double(dayIndex) / 6.0

			// Standing: starts near average (3.0h), declines to much below (1.5h)
			let standing = (3.0 - (progress * 1.5)) + Double.random(in: -0.2 ... 0.2)
			// Sitting: stays around average (10.4h)
			let sitting = 10.4 + Double.random(in: -0.3 ... 0.3)
			// Lying: calculated to make total = 24h
			let lying = 24.0 - standing - sitting

			return ActivityData(
				date: date,
				standingDuration: standing,
				sittingDuration: sitting,
				lyingDuration: lying
			)
		}
	}

	// M: Last 30 days by day
	// Average: 7.7h lying (32%), 10.4h sitting (43.3%), 3.1h standing (12.9%) = 21.2h
	// Total 24h = 100%, Trend: Standing declines gradually then sharply
	static func generateMonthlyData() -> [ActivityData] {
		let calendar = Calendar.current
		let today = Date()

		return (0 ..< 30).map { dayIndex in
			let dayOffset = 29 - dayIndex // Reverse to go from oldest to newest
			let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!

			// Calculate trend factors (0.0 to 1.0)
			let progress = Double(dayIndex) / 29.0

			// Standing: starts above average (3.5h), gradual decline first 20 days, sharp decline last 10 days to 1.5h
			let standing: Double
			if progress < 0.67 { // First 20 days: gradual decline
				standing = (3.5 - (progress * 1.0)) + Double.random(in: -0.2 ... 0.2) // From 3.5h to ~2.8h
			} else { // Last 10 days: sharp decline
				let sharpProgress = (progress - 0.67) / 0.33
				standing = (2.8 - (sharpProgress * 1.3)) + Double.random(in: -0.2 ... 0.2) // From 2.8h to 1.5h
			}

			// Sitting stays relatively stable around average
			let sitting = 10.4 + Double.random(in: -0.3 ... 0.3)

			// Lying: calculated to make total = 24h (will naturally increase as standing decreases)
			let lying = 24.0 - standing - sitting

			return ActivityData(
				date: date,
				standingDuration: standing,
				sittingDuration: sitting,
				lyingDuration: lying
			)
		}
	}
}

// MARK: - Helper Views

struct ActivityBarChart: View {
	let title: String
	let activityData: [ActivityData]
	let activityType: ActivityType
	let selectedPeriod: TimePeriod
	let animateChart: Bool
	let dateUnit: Calendar.Component
	let dateFormat: Date.FormatStyle

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(title)
				.font(.subheadline)
				.foregroundColor(.secondary)

			Chart(activityData) { data in
				BarMark(
					x: .value("Date", data.date, unit: dateUnit),
					y: .value("Hours", animateChart ? getDuration(for: data) : 0)
				)
				.foregroundStyle(activityType.color)
			}
			.frame(height: 150)
			.chartXAxis {
				AxisMarks(values: selectedPeriod == .weekly ? .stride(by: dateUnit, count: 1) : .automatic) { _ in
					AxisValueLabel(format: dateFormat)
				}
			}
		}
	}

	private func getDuration(for data: ActivityData) -> Double {
		switch activityType {
			case .standing: return data.standingDuration
			case .sitting: return data.sittingDuration
			case .lying: return data.lyingDuration
		}
	}
}

// MARK: - Activity View

struct ActivityView: View {
	@State private var selectedPeriod: TimePeriod = .daily
	@State private var animateChart: Bool = false

	private var activityData: [ActivityData] {
		switch selectedPeriod {
			case .daily:
				return ActivityDataGenerator.generateDailyData()
			case .weekly:
				return ActivityDataGenerator.generateWeeklyData()
			case .monthly:
				return ActivityDataGenerator.generateMonthlyData()
		}
	}

	private var pieChartData: [(type: ActivityType, duration: Double)] {
		// Use average per period to show percentage distribution
		let count = Double(activityData.count)
		let avgStanding = activityData.reduce(0) { $0 + $1.standingDuration } / count
		let avgSitting = activityData.reduce(0) { $0 + $1.sittingDuration } / count
		let avgLying = activityData.reduce(0) { $0 + $1.lyingDuration } / count

		return [
			(.standing, avgStanding),
			(.sitting, avgSitting),
			(.lying, avgLying)
		]
	}

	private var averageData: (standing: Double, sitting: Double, lying: Double) {
		let count = Double(activityData.count)
		let avgStanding = activityData.reduce(0) { $0 + $1.standingDuration } / count
		let avgSitting = activityData.reduce(0) { $0 + $1.sittingDuration } / count
		let avgLying = activityData.reduce(0) { $0 + $1.lyingDuration } / count

		return (avgStanding, avgSitting, avgLying)
	}

	private func calculatePercentages(data: [(type: ActivityType, duration: Double)], total: Double) -> [Int] {
		guard total > 0 else { return Array(repeating: 0, count: data.count) }

		// Calculate raw percentages and round them
		var percentages = data.map { Int(round(($0.duration / total) * 100)) }

		// Adjust to ensure sum = 100
		var sum = percentages.reduce(0, +)
		var diff = 100 - sum

		// Find index of largest value to add/subtract difference
		if diff != 0 {
			let maxIndex = percentages.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
			percentages[maxIndex] += diff
		}

		return percentages
	}

	var body: some View {
		ScrollView {
			VStack(spacing: 20) {
				// Period Picker
				Picker("Time Period", selection: $selectedPeriod) {
					ForEach(TimePeriod.allCases, id: \.self) { period in
						Text(period.rawValue).tag(period)
					}
				}
				.pickerStyle(.segmented)
				.padding(.horizontal)

				// Pie Chart Group Box
				GroupBox {
					VStack(alignment: .leading, spacing: 10) {
						Text("Activity Distribution")
							.font(.headline)

						pieChartView
					}
					.padding()
				}
				.padding(.horizontal)

				// Standing Bar Chart Group Box
				GroupBox {
					ActivityBarChart(
						title: "Standing Duration",
						activityData: activityData,
						activityType: .standing,
						selectedPeriod: selectedPeriod,
						animateChart: animateChart,
						dateUnit: dateUnit,
						dateFormat: dateFormat
					)
					.padding()
				}
				.padding(.horizontal)

				// Sitting Bar Chart Group Box
				GroupBox {
					ActivityBarChart(
						title: "Sitting Duration",
						activityData: activityData,
						activityType: .sitting,
						selectedPeriod: selectedPeriod,
						animateChart: animateChart,
						dateUnit: dateUnit,
						dateFormat: dateFormat
					)
					.padding()
				}
				.padding(.horizontal)

				// Lying Bar Chart Group Box
				GroupBox {
					ActivityBarChart(
						title: "Lying Duration",
						activityData: activityData,
						activityType: .lying,
						selectedPeriod: selectedPeriod,
						animateChart: animateChart,
						dateUnit: dateUnit,
						dateFormat: dateFormat
					)
					.padding()
				}
				.padding(.horizontal)

				// Highlight Section
				highlightSection
					.padding(.horizontal)
			}
			.padding(.vertical)
		}
		.navigationTitle("Activity Tracking")
		.onAppear {
			withAnimation(.easeOut(duration: 1.0)) {
				animateChart = true
			}
		}
		.onChange(of: selectedPeriod) { _, _ in
			animateChart = false
			withAnimation(.easeOut(duration: 1.0)) {
				animateChart = true
			}
		}
	}

	// MARK: - Pie Chart

	private var pieChartView: some View {
		VStack {
			let total = pieChartData.reduce(0) { $0 + $1.duration }
			let percentages = calculatePercentages(data: pieChartData, total: total)

			Chart(Array(pieChartData.enumerated()), id: \.element.type) { index, item in
				let percentage = percentages[index]

				SectorMark(
					angle: .value("Duration", animateChart ? item.duration : 0),
					angularInset: 1.5
				)
				.foregroundStyle(item.type.color)
				.annotation(position: .overlay) {
					Text("\(percentage)%")
						.font(.caption)
						.fontWeight(.bold)
						.foregroundColor(.white)
						.opacity(animateChart ? 1 : 0)
				}
			}
			.frame(height: 250)

			// Legend
			HStack(spacing: 20) {
				ForEach(ActivityType.allCases, id: \.self) { type in
					HStack(spacing: 5) {
						Circle()
							.fill(type.color)
							.frame(width: 12, height: 12)
						Text(type.rawValue)
							.font(.caption)
					}
				}
			}
			.padding(.top, 10)
		}
	}

	// MARK: - Highlight Section

	private var highlightSection: some View {
		GroupBox {
			VStack(spacing: 12) {
				Text("Tổng quan")
					.font(.headline)
					.frame(maxWidth: .infinity, alignment: .leading)

				Text(comparisonPeriodText)
					.font(.subheadline)
					.foregroundColor(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)

				Divider()

				activityInsightCard(
					type: .standing,
					current: currentPeriodData.standing,
					previous: previousPeriodData.standing
				)

				activityInsightCard(
					type: .sitting,
					current: currentPeriodData.sitting,
					previous: previousPeriodData.sitting
				)

				activityInsightCard(
					type: .lying,
					current: currentPeriodData.lying,
					previous: previousPeriodData.lying
				)
			}
			.padding()
		}
	}

	private var comparisonPeriodText: String {
		return "So sánh với dữ liệu của những người trong độ tuổi của bạn"
	}

	private var currentPeriodData: (standing: Double, sitting: Double, lying: Double) {
		switch selectedPeriod {
			case .daily:
				// Sum of last 24 hours
				let standing = activityData.reduce(0) { $0 + $1.standingDuration }
				let sitting = activityData.reduce(0) { $0 + $1.sittingDuration }
				let lying = activityData.reduce(0) { $0 + $1.lyingDuration }
				return (standing, sitting, lying)
			case .weekly, .monthly:
				// Last data point
				let standing = activityData.last?.standingDuration ?? 0
				let sitting = activityData.last?.sittingDuration ?? 0
				let lying = activityData.last?.lyingDuration ?? 0
				return (standing, sitting, lying)
		}
	}

	private var previousPeriodData: (standing: Double, sitting: Double, lying: Double) {
		switch selectedPeriod {
			case .daily:
				// Generate yesterday's data (24 hours before)
				let calendar = Calendar.current
				let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
				let yesterdayData = (0 ..< 24).map { hourIndex -> ActivityData in
					let hourOffset = 23 - hourIndex
					let date = calendar.date(byAdding: .hour, value: -hourOffset, to: yesterday)!
					return ActivityData(
						date: date,
						standingDuration: Double.random(in: 0.18 ... 0.28),
						sittingDuration: Double.random(in: 0.35 ... 0.45),
						lyingDuration: Double.random(in: 0.30 ... 0.40)
					)
				}
				let standing = yesterdayData.reduce(0) { $0 + $1.standingDuration }
				let sitting = yesterdayData.reduce(0) { $0 + $1.sittingDuration }
				let lying = yesterdayData.reduce(0) { $0 + $1.lyingDuration }
				return (standing, sitting, lying)
			case .weekly:
				// Week ago (index 0 is 7 days ago)
				let standing = activityData.first?.standingDuration ?? 0
				let sitting = activityData.first?.sittingDuration ?? 0
				let lying = activityData.first?.lyingDuration ?? 0
				return (standing, sitting, lying)
			case .monthly:
				// First day of month (30 days ago)
				let standing = activityData.first?.standingDuration ?? 0
				let sitting = activityData.first?.sittingDuration ?? 0
				let lying = activityData.first?.lyingDuration ?? 0
				return (standing, sitting, lying)
		}
	}

	private func activityInsightCard(type: ActivityType, current: Double, previous _: Double) -> some View {
		let status = getActivityStatus(for: type, current: current)

		return GroupBox {
			HStack(alignment: .top, spacing: 12) {
				// Icon
				Image(systemName: status.icon)
					.font(.title2)
					.foregroundColor(status.statusColor)
					.frame(width: 30)

				VStack(alignment: .leading, spacing: 6) {
					// Activity name
					Text(type.rawValue)
						.font(.headline)

					// Description
					Text(descriptionText(for: type, current: current, average: status.average))
						.font(.subheadline)
						.foregroundColor(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
			.padding(12)
		}
	}

	private func getActivityStatus(for type: ActivityType, current: Double) -> ActivityStatus {
		switch type {
			case .standing:
				let avg = 3.1
				let diff = current - avg
				let percentDiff = (diff / avg) * 100

				if percentDiff < -30 {
					return ActivityStatus(average: avg, statusText: "Thấp hơn trung bình nhiều", statusColor: .red, icon: "chart.line.downtrend.xyaxis")
				} else if percentDiff < -10 {
					return ActivityStatus(average: avg, statusText: "Dưới trung bình", statusColor: .orange, icon: "chart.line.downtrend.xyaxis")
				} else if percentDiff > 10 {
					return ActivityStatus(average: avg, statusText: "Trên trung bình", statusColor: .green, icon: "chart.line.uptrend.xyaxis")
				} else {
					return ActivityStatus(average: avg, statusText: "Bằng trung bình", statusColor: .green, icon: "chart.line.flattrend.xyaxis")
				}

			case .sitting:
				let avg = 10.4
				let diff = current - avg
				let percentDiff = (diff / avg) * 100

				if percentDiff > 20 {
					return ActivityStatus(average: avg, statusText: "Cao hơn trung bình nhiều", statusColor: .red, icon: "chart.line.uptrend.xyaxis")
				} else if percentDiff > 10 {
					return ActivityStatus(average: avg, statusText: "Trên trung bình", statusColor: .orange, icon: "chart.line.uptrend.xyaxis")
				} else if percentDiff < -10 {
					return ActivityStatus(average: avg, statusText: "Dưới trung bình", statusColor: .green, icon: "chart.line.downtrend.xyaxis")
				} else {
					return ActivityStatus(average: avg, statusText: "Bằng trung bình", statusColor: .green, icon: "chart.line.flattrend.xyaxis")
				}

			case .lying:
				let avg = 7.7
				let diff = current - avg
				let percentDiff = (diff / avg) * 100

				if percentDiff > 20 {
					return ActivityStatus(average: avg, statusText: "Cao hơn trung bình nhiều", statusColor: .red, icon: "chart.line.uptrend.xyaxis")
				} else if percentDiff > 10 {
					return ActivityStatus(average: avg, statusText: "Trên trung bình", statusColor: .orange, icon: "chart.line.uptrend.xyaxis")
				} else if percentDiff < -10 {
					return ActivityStatus(average: avg, statusText: "Dưới trung bình", statusColor: .green, icon: "chart.line.downtrend.xyaxis")
				} else {
					return ActivityStatus(average: avg, statusText: "Bằng trung bình", statusColor: .green, icon: "chart.line.flattrend.xyaxis")
				}
		}
	}

	private func descriptionText(for type: ActivityType, current: Double, average: Double) -> String {
		// Vietnamese contextual health messages based on actual data
		let diff = current - average

		switch type {
			case .standing:
				if diff < -1.0 { // More than 1 hour below average
					return "Bạn cần đứng nhiều hơn - hiện tại thấp hơn nhiều so với mức khuyến nghị"
				} else if diff < -0.3 {
					return "Thời gian đứng của bạn đang dưới mức trung bình"
				} else if diff > 0.3 {
					return "Thời gian đứng của bạn đang tốt, trên mức trung bình"
				} else {
					return "Thời gian đứng của bạn đang ở mức trung bình"
				}

			case .sitting:
				if diff > 2.0 { // More than 2 hours above average
					return "Bạn đang ngồi quá nhiều - nên giảm bớt và vận động thêm để cải thiện sức khỏe"
				} else if diff > 1.0 {
					return "Thời gian ngồi của bạn cao hơn mức khuyến nghị"
				} else if diff < -1.0 {
					return "Thời gian ngồi của bạn thấp hơn mức trung bình, rất tốt"
				} else {
					return "Thời gian ngồi của bạn nằm trong khoảng trung bình"
				}

			case .lying:
				if diff > 1.5 { // More than 1.5 hours above average
					return "Bạn nằm nghỉ quá nhiều - hãy tăng cường vận động để duy trì sức khỏe tốt hơn"
				} else if diff > 0.7 {
					return "Thời gian nằm nghỉ cao hơn mức trung bình"
				} else if diff < -0.7 {
					return "Thời gian nằm nghỉ thấp hơn mức trung bình"
				} else {
					return "Thời gian nằm nghỉ ở mức cân bằng, tốt cho sức khỏe"
				}
		}
	}

	// MARK: - Helpers

	private var dateUnit: Calendar.Component {
		switch selectedPeriod {
			case .daily: return .hour
			case .weekly: return .day
			case .monthly: return .day
		}
	}

	private var dateFormat: Date.FormatStyle {
		switch selectedPeriod {
			case .daily:
				return .dateTime.hour()
			case .weekly:
				return .dateTime.weekday(.abbreviated)
			case .monthly:
				return .dateTime.day()
		}
	}
}

#Preview {
	NavigationStack {
		ActivityView()
	}
}
