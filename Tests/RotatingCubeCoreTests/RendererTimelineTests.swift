import XCTest
@testable import RotatingCubeCore

final class RendererTimelineTests: XCTestCase {
    func testFrameCountsMatchThirtySecondLoopAtThirtyFPS() {
        let timeline = RendererTimeline(loop: .init(durationSeconds: 30, simulationFPS: 30, outputFPS: 30))

        XCTAssertEqual(timeline.loop.simulationFrameCount, 900)
        XCTAssertEqual(timeline.loop.presentationFrameCount, 900)
        XCTAssertEqual(timeline.framesPerSimulationStep, 1)
    }

    func testSampledTimeAdvancesEveryPresentationFrameAtThirtyFPS() {
        let timeline = RendererTimeline(loop: .init(durationSeconds: 30, simulationFPS: 30, outputFPS: 30))

        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 0), 0)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 1), 1.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 2), 2.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 899), 29.9667, accuracy: 0.0001)
    }

    func testElapsedTimeWrapsBackIntoPerfectLoop() {
        let timeline = RendererTimeline(loop: .init(durationSeconds: 30, simulationFPS: 30, outputFPS: 30))

        XCTAssertEqual(
            timeline.sampledTime(forElapsedTime: 30.10),
            timeline.sampledTime(forElapsedTime: 0.10),
            accuracy: 0.0001
        )
    }
}
