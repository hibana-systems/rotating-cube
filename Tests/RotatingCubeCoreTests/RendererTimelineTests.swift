import XCTest
@testable import RotatingCubeCore

final class RendererTimelineTests: XCTestCase {
    func testFrameCountsMatchThirtySecondLoopAtTwentyFourFPS() {
        let timeline = RendererTimeline(loop: .init(durationSeconds: 30, simulationFPS: 24, outputFPS: 24))

        XCTAssertEqual(timeline.loop.simulationFrameCount, 720)
        XCTAssertEqual(timeline.loop.presentationFrameCount, 720)
        XCTAssertEqual(timeline.framesPerSimulationStep, 1)
    }

    func testSampledTimeAdvancesEveryPresentationFrameAtTwentyFourFPS() {
        let timeline = RendererTimeline(loop: .init(durationSeconds: 30, simulationFPS: 24, outputFPS: 24))

        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 0), 0)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 1), 1.0 / 24.0, accuracy: 0.0001)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 2), 2.0 / 24.0, accuracy: 0.0001)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 719), 29.9583, accuracy: 0.0001)
    }

    func testElapsedTimeWrapsBackIntoPerfectLoop() {
        let timeline = RendererTimeline(loop: .init(durationSeconds: 30, simulationFPS: 24, outputFPS: 24))

        XCTAssertEqual(
            timeline.sampledTime(forElapsedTime: 30.10),
            timeline.sampledTime(forElapsedTime: 0.10),
            accuracy: 0.0001
        )
    }
}
