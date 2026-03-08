import Foundation

public struct RendererTimeline: Sendable, Equatable {
    public let loop: LoopSettings

    public init(loop: LoopSettings) {
        self.loop = loop
    }

    public var framesPerSimulationStep: Int {
        loop.outputFPS / loop.simulationFPS
    }

    public func sampledTime(forPresentationFrame frameIndex: Int) -> Double {
        let wrappedFrame = ((frameIndex % loop.presentationFrameCount) + loop.presentationFrameCount)
            % loop.presentationFrameCount
        let simulationFrame = wrappedFrame / framesPerSimulationStep
        return Double(simulationFrame) / Double(loop.simulationFPS)
    }

    public func sampledTime(forElapsedTime elapsedTime: Double) -> Double {
        let wrappedTime = elapsedTime.truncatingRemainder(dividingBy: loop.durationSeconds)
        let positiveWrappedTime = wrappedTime < 0 ? wrappedTime + loop.durationSeconds : wrappedTime
        let simulationFrame = Int(
            floor(positiveWrappedTime * Double(loop.simulationFPS))
        ) % max(loop.simulationFrameCount, 1)
        return Double(simulationFrame) / Double(loop.simulationFPS)
    }
}
