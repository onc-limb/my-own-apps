import Foundation
import Week168Domain
import Week168UseCases

actor RecordingAlarms: AlarmScheduling {
    var planned: [(entryID: EntryID, name: String, fireAt: Date)] = []
    var budgets: [(activityID: ActivityID, name: String, fireAt: Date)] = []
    var cancelled: [EntryID] = []

    func schedulePlannedTimeAlarm(entryID: EntryID, activityName: String, fireAt: Date) {
        planned.append((entryID, activityName, fireAt))
    }
    func scheduleBudgetExhaustionNotice(activityID: ActivityID, activityName: String, fireAt: Date) {
        budgets.append((activityID, activityName, fireAt))
    }
    func cancelAll(for entryID: EntryID) { cancelled.append(entryID) }
    func reset() { planned = []; budgets = []; cancelled = [] }
}
