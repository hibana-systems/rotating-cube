import XCTest
@testable import RotatingCubeCore

final class RendererTimelineTests: XCTestCase {
    func testFrameCountsMatchThirtySecondLoop() {
        let timeline = RendererTimeline(loop: .init(durationSeconds: 30, simulationFPS: 20, outputFPS: 60))

        XCTAssertEqual(timeline.loop.simulationFrameCount, 600)
        XCTAssertEqual(timeline.loop.presentationFrameCount, 1800)
        XCTAssertEqual(timeline.framesPerSimulationStep, 3)
    }

    func testSampledTimeQuantizesPresentationFramesIntoSimulationSteps() {
        let timeline = RendererTimeline(loop: .init(durationSeconds: 30, simulationFPS: 20, outputFPS: 60))

        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 0), 0)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 1), 0)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 2), 0)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 3), 0.05, accuracy: 0.0001)
        XCTAssertEqual(timeline.sampledTime(forPresentationFrame: 1799), 29.95, accuracy: 0.0001)
    }

    func testElapsedTimeWrapsBackIntoPerfectLoop() {
        let timeline = RendererTimeline(loop: .init(durationSeconds: 30, simulationFPS: 20, outputFPS: 60))

        XCTAssertEqual(
            timeline.sampledTime(forElapsedTime: 30.10),
            timeline.sampledTime(forElapsedTime: 0.10),
            accuracy: 0.0001
        )
    }
}
