import Foundation
import Observation
import SwiftData
import SwiftUI
import UserNotifications
import Week168Domain
import Week168Persistence
import Week168UseCases

// The client boundary lets tests exercise the actual OS scheduler without delivery or permission dialogs.
@MainActor
protocol NotificationCenterClient: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemNotificationCenter: NotificationCenterClient {
    private let center: UNUserNotificationCenter
    // UNUserNotificationCenter holds its delegate weakly.
    private let delegate = ForegroundNotificationDelegate()

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        center.delegate = delegate
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@MainActor @Observable
final class NotificationAlarmScheduler: AlarmScheduling {
    private let center: any NotificationCenterClient
    private let now: @Sendable () -> Date
    @TaskLocal private static var suppressedSchedulers: Set<UUID> = []
    private let schedulerID = UUID()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private var issues: [String: String] = [:]
    var issueKey: String? { issues.keys.sorted().first.flatMap { issues[$0] } }

    init(center: any NotificationCenterClient, now: @escaping @Sendable () -> Date = { .now }) {
        self.center = center
        self.now = now
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional: true
        #if os(iOS)
        case .ephemeral: true
        #endif
        default: false
        }
    }

    func showsWarning(for entry: TimeEntry?) -> Bool {
        entry?.endedAt == nil && entry?.plannedMinutes != nil && !isAuthorized
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.authorizationStatus()
    }

    func suppressingAuthorizationRequest(_ operation: @MainActor () async throws -> Void) async rethrows {
        // D-101: suppress only this refresh's call chain, including service actor hops.
        // An unrelated user operation must still be able to request permission while refresh awaits I/O.
        try await Self.$suppressedSchedulers.withValue(Self.suppressedSchedulers.union([schedulerID])) {
            try await operation()
        }
    }

    func reportRefreshFailure() { issues["refresh"] = "notifications.error.refresh" }
    func clearRefreshFailure() { issues.removeValue(forKey: "refresh") }

    func schedulePlannedTimeAlarm(entryID: EntryID, activityName: String, fireAt: Date) async {
        await schedule(identifier: "planned-\(entryID.rawValue.uuidString)",
                       title: "notifications.planned.title", body: "notifications.planned.body",
                       activityName: activityName, fireAt: fireAt)
    }

    func scheduleBudgetExhaustionNotice(activityID: ActivityID, activityName: String, fireAt: Date) async {
        await schedule(identifier: "budget-notice", title: "notifications.budget.title",
                       body: "notifications.budget.body", activityName: activityName, fireAt: fireAt)
    }

    func cancelAll(for entryID: EntryID) async {
        // D-097 relies on INV-4: at most one running entry, hence at most one budget notice.
        // Week168Service cancels the running entry before every reschedule. If either premise
        // changes, this fixed budget identifier and entry-based cancellation must be revisited.
        let identifiers = ["planned-\(entryID.rawValue.uuidString)", "budget-notice"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        for identifier in identifiers { issues.removeValue(forKey: identifier) }
    }

    private func schedule(identifier: String, title: String, body: String, activityName: String, fireAt: Date) async {
        guard fireAt > now() else { return }
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            guard !Self.suppressedSchedulers.contains(schedulerID) else { return }
            do {
                let granted = try await center.requestAuthorization()
                await refreshAuthorizationStatus()
                guard granted else { return }
            } catch {
                issues[identifier] = "notifications.error.authorization"
                return
            }
        }
        guard isAuthorized else { return }
        // Asking permission can take longer than the remaining planned duration.
        let interval = fireAt.timeIntervalSince(now())
        guard interval > 0 else { return }
        let content = UNMutableNotificationContent()
        // The SDK exposes the brief's deferred-localization API on NSString, not String.
        content.title = NSString.localizedUserNotificationString(forKey: title, arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: body, arguments: [activityName])
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        do {
            try await center.add(request)
            issues.removeValue(forKey: identifier)
        } catch {
            // Notification delivery must never throw into a successfully saved recording operation.
            issues[identifier] = "notifications.error.schedule"
        }
    }
}

extension EnvironmentValues {
    @Entry var notifications: NotificationAlarmScheduler? = nil
}

struct OpenNotificationSettingsButton: View {
    @Environment(\.openURL) private var openURL
    var body: some View {
        Button("notifications.openSettings") {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        }
        .accessibilityLabel(Text("a11y.notificationSettings"))
    }
}

@MainActor @Observable
private final class AppDependencies {
    private(set) var container: ModelContainer?
    private(set) var home: HomeViewModel?
    private(set) var allocation: AllocationViewModel?
    private(set) var management: ActivitiesEntriesViewModel?

    private(set) var review: ReviewViewModel?
    private(set) var settings: SettingsViewModel?

    let notifications = NotificationAlarmScheduler(center: SystemNotificationCenter())
    private var service: Week168Service?
    private var refreshingNotifications = false

    init() { open() }

    func refreshNotifications() async {
        guard !refreshingNotifications, let service else { return }
        refreshingNotifications = true
        defer { refreshingNotifications = false }
        await notifications.suppressingAuthorizationRequest {
            await notifications.refreshAuthorizationStatus()
            do {
                try await service.refreshAlarms()
                notifications.clearRefreshFailure()
            }
            catch { notifications.reportRefreshFailure() }
        }
    }

    func open() {
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Week168", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let container = try Week168Store.makeContainer(at: directory.appendingPathComponent("Week168.store"))
            let store = Week168Store(container: container)
            let service = Week168Service(store: store, clock: SystemClock(), alarms: notifications)
            self.service = service
            self.container = container
            home = HomeViewModel(store: store, service: service)
            allocation = AllocationViewModel(store: store, service: service)
            management = ActivitiesEntriesViewModel(store: store, service: service)
            review = ReviewViewModel(store: store, service: service)
            settings = SettingsViewModel(store: store, service: service)
            Task { await refreshNotifications() }
        } catch {
            // Keep the localized recovery screen visible; never replace persisted data with an empty store.
            home = nil
            allocation = nil
            management = nil
            review = nil
            settings = nil
        }
    }
}

@main
@MainActor
struct Week168App: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            if let home = dependencies.home, let allocation = dependencies.allocation,
               let management = dependencies.management, let review = dependencies.review,
               let settings = dependencies.settings {
                ContentView(model: home, allocationModel: allocation, managementModel: management,
                            reviewModel: review, settingsModel: settings)
                    .environment(\.notifications, dependencies.notifications)
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active { Task { await dependencies.refreshNotifications() } }
                    }
            } else {
                ContentUnavailableView {
                    Label("error.title", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("error.storage")
                } actions: {
                    Button("action.retry") { dependencies.open() }
                }
            }
        }
    }
}
