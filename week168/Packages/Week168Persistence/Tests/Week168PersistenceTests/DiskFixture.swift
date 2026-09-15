import Foundation
import SwiftData
import Testing
@testable import Week168Persistence
import Week168Domain

final class DiskFixture {
    let directory: URL
    let url: URL
    var container: ModelContainer?
    var store: Week168Store?

    init() throws {
        // Keep test artifacts inside Packages even when the host temp directory is outside it.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/test-stores")
        directory = root.appendingPathComponent(UUID().uuidString)
        url = directory.appendingPathComponent("store.sqlite")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try open()
    }

    func open() throws {
        let container = try Week168Store.makeContainer(at: url)
        self.container = container
        store = Week168Store(container: container)
    }

    func reopen() throws {
        store = nil
        container = nil
        #expect(FileManager.default.fileExists(atPath: url.path))
        try open()
    }

    deinit {
        store = nil
        container = nil
        try? FileManager.default.removeItem(at: directory)
    }
}
