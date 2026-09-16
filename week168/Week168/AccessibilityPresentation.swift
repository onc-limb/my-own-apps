import Foundation
import SwiftUI
import Week168Domain

// Presentation only: judgments come from the existing domain summaries.
enum AccessibilityPresentation {
    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: String(localized: String.LocalizationValue(key)), arguments: arguments)
    }

    static func outside(_ activity: Activity, tree: ActivityTree) -> Bool {
        activity.budgetMode == .excluded || tree.ancestors(of: activity.id).contains {
            tree.node($0)?.budgetMode == .excluded
        }
    }

    static func status(_ summary: ActivitySummary?, outside: Bool, pending: Bool) -> String {
        if outside { return String(localized: "a11y.outside") }
        if pending { return String(localized: "a11y.pending") }
        guard let summary, let budget = summary.budgetMinutes else {
            return String(localized: "timer.noBudget")
        }
        if let deviation = summary.deviationMinutes, deviation > 0 {
            return text(summary.direction == .goal ? "status.unmet" : "status.exceeded", HomeTime.minutes(deviation))
        }
        return text("a11y.remaining", HomeTime.minutes(max(0, budget - summary.totalMinutes)))
    }

    static func homeValue(_ activity: Activity, snapshot: HomeSnapshot, state: HomePresentation) -> String {
        var parts: [String] = []
        if let parent = activity.parentID {
            parts.append(text("activity.parent", snapshot.tree.node(parent)?.name ?? String(localized: "activity.unknown")))
        }
        if activity.isArchived { parts.append(String(localized: "activity.archived")) }
        if snapshot.running?.activityID == activity.id { parts.append(String(localized: "home.running")) }
        if let summary = state.summaries[activity.id] {
            parts.append(text("activity.actual", HomeTime.minutes(summary.totalMinutes)))
            if state.isCommitted, !outside(activity, tree: snapshot.tree), let budget = summary.budgetMinutes {
                parts.append(text(summary.direction == .goal ? "activity.goalBudget" : "activity.capBudget", HomeTime.minutes(budget)))
            }
        }
        parts.append(status(state.summaries[activity.id], outside: outside(activity, tree: snapshot.tree),
                            pending: state.commitmentState == .pending))
        return parts.joined(separator: ", ")
    }

    enum ReviewDetailKind { case plain, deviation }

    struct ReviewDetail {
        let kind: ReviewDetailKind
        let text: String

        init(_ text: String, kind: ReviewDetailKind = .plain) {
            self.kind = kind
            self.text = text
        }
    }

    static func reviewDetails(_ row: ReviewActivity, pending: Bool) -> [ReviewDetail] {
        if row.isOutside { return [ReviewDetail(String(localized: "a11y.outside"))] }
        var parts: [ReviewDetail] = []
        if let budget = row.committedMinutes {
            parts.append(ReviewDetail(reviewText("review.budget", budget)))
            if let direction = row.direction {
                parts.append(ReviewDetail(String(localized: String.LocalizationValue(direction == .cap ? "allocation.cap" : "allocation.goal"))))
            }
            if row.status == "over" || row.status == "unmet" {
                parts.append(ReviewDetail(reviewText(row.status == "over" ? "review.over" : "review.unmet", row.deviationMinutes), kind: .deviation))
            } else {
                parts.append(ReviewDetail(String(localized: String.LocalizationValue(row.status == "within" ? "review.within" : "review.notJudged"))))
                if row.status == "within" {
                    parts.append(ReviewDetail(text("a11y.remaining", HomeTime.minutes(max(0, budget - row.totalMinutes)))))
                }
            }
        } else { parts.append(ReviewDetail(String(localized: "review.shared"))) }
        if pending { parts.append(ReviewDetail(String(localized: "a11y.pending"))) }
        return parts
    }

    static func reviewValue(_ row: ReviewActivity, pending: Bool) -> String {
        var parts = [reviewText("review.actual", row.totalMinutes), reviewText("review.own", row.ownMinutes)]
        if row.path.count > 1 { parts.insert(text("a11y.path", row.path.joined(separator: ", ")), at: 0) }
        return (parts + reviewDetails(row, pending: pending).map(\.text)).joined(separator: ", ")
    }

    static func runningValue(_ running: TimeEntry, snapshot: HomeSnapshot, at now: Date) -> String {
        let state = snapshot.presentation(at: now)
        var parts = [text("a11y.elapsed", HomeTime.elapsed(since: running.startedAt, at: now))]
        if let activity = snapshot.tree.node(running.activityID) {
            parts.append(homeValue(activity, snapshot: snapshot, state: state))
            if state.isCommitted, !outside(activity, tree: snapshot.tree), let parent = activity.parentID, let summary = state.summaries[parent],
               let budget = summary.budgetMinutes {
                parts.append(text("timer.parentRemaining", snapshot.tree.node(parent)?.name ?? String(localized: "activity.unknown"),
                                  HomeTime.minutes(budget - summary.totalMinutes)))
                parts.append(status(summary, outside: false, pending: false))
            }
        }
        if let minutes = running.plannedMinutes {
            let remaining = minutes - Int(max(0, now.timeIntervalSince(running.startedAt)) / 60)
            parts.append(text(remaining >= 0 ? "timer.plan" : "timer.planExceeded",
                              HomeTime.minutes(minutes), HomeTime.minutes(abs(remaining))))
        } else { parts.append(String(localized: "timer.noPlan")) }
        return parts.joined(separator: ", ")
    }
}

struct AccessibleRunningSummary<Content: View>: View {
    let running: TimeEntry
    let snapshot: HomeSnapshot
    @ViewBuilder let content: () -> Content
    @State private var readingDate = Date.now
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        content()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityPresentation.text("a11y.running", snapshot.tree.node(running.activityID)?.name
                ?? String(localized: "activity.unknown")))
            // ASSUMPTION: Refresh the spoken elapsed time when focus returns to the summary.
            // The visual TimelineView never supplies the accessibility clock. Read once on focus,
            // then keep that reading stable until the user visits the summary again.
            .accessibilityValue(AccessibilityPresentation.runningValue(running, snapshot: snapshot, at: readingDate))
            .accessibilityFocused($isFocused)
            .accessibilityIdentifier("timer.summary")
            .onChange(of: isFocused) { _, focused in
                if focused { readingDate = .now }
            }
            .onChange(of: running) { _, _ in readingDate = .now }
    }
}

// Avoid compressing/truncating horizontally arranged controls at accessibility text sizes.
struct AccessibleStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    @ViewBuilder let content: () -> Content

    var body: some View {
        if size.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12, content: content)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { content().fixedSize() }
                VStack(alignment: .leading, spacing: 12, content: content)
            }
        }
    }
}

struct AccessibleDatePicker: View {
    let title: LocalizedStringKey
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents

    init(_ title: LocalizedStringKey, selection: Binding<Date>, displayedComponents: DatePickerComponents) {
        self.title = title
        _selection = selection
        self.displayedComponents = displayedComponents
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).accessibilityHidden(true)
            // Separate date and time controls so neither gets squeezed off a narrow screen.
            if displayedComponents.contains(.date) {
                DatePicker(title, selection: $selection, displayedComponents: .date).labelsHidden()
                    .accessibilityLabel(Text(title))
            }
            if displayedComponents.contains(.hourAndMinute) {
                DatePicker(title, selection: $selection, displayedComponents: .hourAndMinute).labelsHidden()
                    .accessibilityLabel(Text(title))
            }
        }
    }
}

struct AccessiblePicker<Selection: Hashable, Content: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Selection
    let accessibilityName: String?
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var size

    init(_ title: LocalizedStringKey, selection: Binding<Selection>, accessibilityName: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        _selection = selection
        self.accessibilityName = accessibilityName
        self.content = content
    }

    var body: some View {
        if size.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).fixedSize(horizontal: false, vertical: true).accessibilityHidden(true)
                Picker(title, selection: $selection, content: content)
                    .labelsHidden()
                    .accessibilityLabel(accessibilityName.map { Text(verbatim: $0) } ?? Text(title))
            }
        } else {
            Picker(title, selection: $selection, content: content)
                .accessibilityLabel(accessibilityName.map { Text(verbatim: $0) } ?? Text(title))
        }
    }
}

struct AccessibleTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let accessibilityName: String?
    @Environment(\.dynamicTypeSize) private var size

    init(_ title: LocalizedStringKey, text: Binding<String>, accessibilityName: String? = nil) {
        self.title = title
        _text = text
        self.accessibilityName = accessibilityName
    }

    var body: some View {
        if size.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).fixedSize(horizontal: false, vertical: true).accessibilityHidden(true)
                TextField("", text: $text).accessibilityLabel(accessibilityName.map { Text(verbatim: $0) } ?? Text(title))
            }
        } else {
            TextField(title, text: $text)
                .accessibilityLabel(accessibilityName.map { Text(verbatim: $0) } ?? Text(title))
        }
    }
}
