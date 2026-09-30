import Testing
@testable import FlowAppiOS

struct FlowAppiOSTests {
    @Test func sampleDataLoads() async throws {
        let store = FlowStore(seedSamples: true)
        #expect(store.tasks.isEmpty == false)
        #expect(store.habits.isEmpty == false)
    }
}
