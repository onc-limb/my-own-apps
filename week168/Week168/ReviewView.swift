import SwiftUI

struct ReviewView: View {
    @Bindable var model: ReviewViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                AccessiblePicker("review.period", selection: $model.period) {
                    Text("review.week").tag(ReviewViewModel.Period.week)
                    Text("review.month").tag(ReviewViewModel.Period.month)
                }
                Text(model.title).font(.title2.bold())
                AccessibleStack { navigationButtons }
                .buttonStyle(.borderless)
                if model.period == .month {
                    Text(reviewText("review.weekCount", model.weeks.count))
                    Text("review.monthExplanation").font(.footnote)
                }
                if model.weeks.contains(where: { !$0.isCommitted }) {
                    Text("review.pending").font(.footnote)
                }
            }.disabled(model.isBusy)
            Section("review.budgeted") {
                rows(model.activities.filter { !$0.isOutside }, pending: model.weeks.contains { !$0.isCommitted })
            }
            Section("review.outside") {
                rows(model.activities.filter(\.isOutside), pending: model.weeks.contains { !$0.isCommitted })
            }
            if model.period == .month {
                Section("review.weekDetails") {
                    ForEach(model.weeks, id: \.week) { week in
                        DisclosureGroup(reviewDay(week.week.startDay)) {
                            if !week.isCommitted { Text("review.pending") }
                            rows(week.activities, pending: !week.isCommitted)
                        }
                    }
                }
            }
            if model.isBusy { ProgressView("home.loading") }
            if let issue = model.issue {
                Section {
                    Text(issue)
                    Button("action.retry") { Task { await model.refresh() } }
                }
            }
        }
        .navigationTitle("tab.review")
        .task { await model.refresh() }
        .onChange(of: model.period) { _, _ in Task { await model.refresh() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
    }

    @ViewBuilder private var navigationButtons: some View {
        Button("review.previous") { Task { await model.move(-1) } }
        Button("review.current") { Task { await model.move(nil) } }
        Button("review.next") { Task { await model.move(1) } }
    }

    @ViewBuilder private func rows(_ values: [ReviewActivity], pending: Bool) -> some View {
        if values.isEmpty { Text("review.empty").foregroundStyle(.secondary) }
        ForEach(values) { row in
            VStack(alignment: .leading, spacing: 8) {
                Text(row.activity.name).font(.headline)
                if row.path.count > 1 {
                    Text(row.path.joined(separator: " › ")).font(.caption).foregroundStyle(.secondary)
                }
                Text(reviewText("review.actual", row.totalMinutes))
                Text(reviewText("review.own", row.ownMinutes)).font(.footnote)
                ForEach(Array(AccessibilityPresentation.reviewDetails(row, pending: pending).enumerated()), id: \.offset) { _, detail in
                    Text(detail)
                        .foregroundStyle(row.status == "over" || row.status == "unmet" ? Color.red : Color.primary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(row.activity.name)
            .accessibilityValue(AccessibilityPresentation.reviewValue(row, pending: pending))
        }
    }
}
