import Foundation
import Week168Domain

public protocol AlarmScheduling: Sendable {
    func schedulePlannedTimeAlarm(entryID: EntryID, activityName: String, fireAt: Date) async
    func scheduleBudgetExhaustionNotice(activityID: ActivityID, activityName: String, fireAt: Date) async
    func cancelAll(for entryID: EntryID) async
}
