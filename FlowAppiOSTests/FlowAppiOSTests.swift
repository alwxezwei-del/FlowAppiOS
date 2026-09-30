import Testing
@testable import FlowAppiOS

struct FlowAppiOSTests {
    @Test func startsWithoutUserContent() async throws {
        let store = FlowStore(seedSamples: false)
        #expect(store.tasks.isEmpty)
        #expect(store.habits.isEmpty)
        #expect(store.categories.isEmpty == false)
    }
}
