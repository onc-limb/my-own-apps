import Testing
@testable import Week168Domain

/// ドメイン層のテストはすべてこのターゲットに置く（D-081）。
/// `swift test` だけで走るため、シミュレータも Xcode も不要。
@Suite("Week168Domain の骨格")
struct PlaceholderTests {
    @Test("モジュールをテストから読み込める")
    func moduleIsImportable() {
        #expect(true)
    }
}
