import Foundation
import Observation
import Week168Domain
import Week168Persistence
import Week168UseCases

struct RestorePreview: Identifiable {
    let id = UUID()
    let replacement: StoreBackup
    let previous: StoreBackup
    var message: String { reviewText("settings.restoreImpact", previous.entries.count, previous.activities.count) }
}

struct SharedBackup: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor @Observable
final class SettingsViewModel {
    private let store: Week168Store
    private let service: Week168Service
    private(set) var settings: CalendarSettings?
    private(set) var isBusy = false
    var capacity = ""
    var dayStartHour = 4
    var weekStartWeekday = 2
    var timeZoneIdentifier = "Asia/Tokyo"
    var allTime = true
    var from = Date.now
    var to = Date.now
    var issue: String?
    var notice: String?
    var restorePreview: RestorePreview?
    var sharedBackup: SharedBackup?
    private var sharedDirectory: URL?

    init(store: Week168Store, service: Week168Service) { self.store = store; self.service = service }

    func refresh(now: Date = .now) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            if try await store.loadSettings() == nil { _ = try await service.homeSections(recentLimit: 8) }
            let backup = try await store.backup()
            let saved = try CalendarSettings.validated(timeZoneIdentifier: backup.settings.timeZoneIdentifier,
                dayStartHour: backup.settings.dayStartHour, weekStartWeekday: backup.settings.weekStartWeekday)
            settings = saved
            dayStartHour = saved.dayStartHour; weekStartWeekday = saved.weekStartWeekday
            timeZoneIdentifier = saved.timeZoneIdentifier
            let week = TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: now, settings: saved), settings: saved)
            capacity = BudgetResolver.resolve(week: week, entries: backup.budgets, capacities: backup.capacities)
                .capacityMinutes.map(String.init) ?? ""
            issue = nil
        } catch { issue = String(localized: "settings.error.load") }
    }

    func saveCalendar() async {
        guard !isBusy else { return }
        isBusy = true; issue = nil; notice = nil
        do {
            let value = try CalendarSettings.validated(timeZoneIdentifier: timeZoneIdentifier,
                dayStartHour: dayStartHour, weekStartWeekday: weekStartWeekday)
            try await service.updateCalendarSettings(value)
            settings = value
            notice = String(localized: "settings.saved")
        } catch { issue = String(localized: "settings.error.calendar") }
        isBusy = false
        if issue == nil { await refresh() }
    }

    func saveCapacity(now: Date = .now) async {
        guard !isBusy, let settings else { return }
        let text = capacity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty || Int(text).map({ $0 >= 0 && $0 <= Int.max / 64 }) == true else {
            issue = String(localized: "settings.error.capacity"); return
        }
        isBusy = true; issue = nil; notice = nil
        defer { isBusy = false }
        do {
            let week = TimeAxis.logicalWeek(of: TimeAxis.logicalDay(of: now, settings: settings), settings: settings)
            try await service.setCapacity(minutes: Int(text), from: week)
            notice = String(localized: "settings.saved")
        } catch { issue = String(localized: "settings.error.save") }
    }

    func export(now: Date = .now) async {
        guard !isBusy else { return }
        isBusy = true; issue = nil; notice = nil
        defer { isBusy = false }
        do {
            let backup = try await store.backup()
            // DatePicker displays civil date labels in the app timezone, independent of day-start hour.
            let first = allTime ? nil : dateLabel(from, settings: backup.settings)
            let last = allTime ? nil : dateLabel(to, settings: backup.settings)
            let bytes = try await Task.detached {
                try ReviewExport.encode(backup: backup, from: first, to: last, now: now)
            }.value
            clearSharedFile()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            sharedDirectory = directory
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(identifier: backup.settings.timeZoneIdentifier)
            formatter.dateFormat = "yyyyMMdd-HHmm"
            let url = directory.appendingPathComponent("Week168-\(formatter.string(from: now)).json")
            try bytes.write(to: url, options: .atomic)
            sharedBackup = SharedBackup(url: url)
        } catch { issue = String(localized: "settings.error.export") }
    }

    func prepareImport(_ url: URL, now: Date = .now) async {
        guard !isBusy else { return }
        isBusy = true; issue = nil; notice = nil; restorePreview = nil
        defer { isBusy = false }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let replacement = try await Task.detached {
                try BackupJSON.decode(Data(contentsOf: url), now: now)
            }.value
            let previous = try await store.backup()
            restorePreview = RestorePreview(replacement: replacement, previous: previous)
        } catch { issue = String(localized: "settings.error.import") }
    }

    func restore(_ preview: RestorePreview) async {
        guard !isBusy else { return }
        isBusy = true; issue = nil; notice = nil
        do {
            try await service.restore(preview.replacement, replacing: preview.previous)
            restorePreview = nil
            notice = String(localized: "settings.restored")
        } catch BackupError.staleConfirmation {
            restorePreview = nil
            issue = String(localized: "settings.error.stale")
        } catch {
            restorePreview = nil
            issue = String(localized: "settings.error.restore")
        }
        isBusy = false
        if issue == nil { await refresh() }
    }

    func clearSharedFile() {
        if let sharedDirectory { try? FileManager.default.removeItem(at: sharedDirectory) }
        sharedDirectory = nil
    }

    private func dateLabel(_ date: Date, settings: CalendarSettings) -> LogicalDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: settings.timeZoneIdentifier) ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return LogicalDay(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}
