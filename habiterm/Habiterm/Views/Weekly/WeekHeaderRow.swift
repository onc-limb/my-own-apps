import SwiftUI

struct WeekHeaderRow: View {

    // MARK: - Properties

    private let dates = CalendarHelper.pastSevenDays()

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Habit name column spacer
            Color.clear
                .frame(width: 100)

            ForEach(dates, id: \.self) { date in
                dayColumn(for: date)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(accessibilityText(for: date))
            }
        }
    }

    // MARK: - Subviews

    private func dayColumn(for date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)

        return VStack(spacing: 2) {
            Text(weekdayText(for: date))
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)

            Text(dayNumberText(for: date))
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
        }
        .foregroundStyle(isToday ? .primary : .secondary)
        .background {
            if isToday {
                Circle()
                    .fill(.blue.opacity(0.15))
                    .frame(width: 36, height: 36)
            }
        }
    }

    // MARK: - Formatting

    private func weekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    private func dayNumberText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func accessibilityText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    WeekHeaderRow()
        .padding()
}
