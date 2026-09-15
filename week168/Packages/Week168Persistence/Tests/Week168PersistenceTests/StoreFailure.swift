import Foundation
import SwiftData
@testable import Week168Persistence

struct StoreFailure: Error, Equatable {
    let attempt: Int
}

extension Week168Store {
    func failNextSaves(_ count: Int) {
        var attempt = 0
        saveOperation = { context in
            attempt += 1
            if attempt <= count { throw StoreFailure(attempt: attempt) }
            try context.save()
        }
    }
}
