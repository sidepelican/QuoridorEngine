@testable import QuoridorEngine
import XCTest

final class PathFinderTests: XCTestCase {
    var finder: PathFinder!
    var g = DefaultRandomGenerator()

    override func setUp() {
        var board = BoardState(pawns: [
            .init(id: "A", goal: .maxYEdge, point: .init(x: 1, y: 1), fencesLeft: 999)
        ])
        _ = board.addFence(at: .init(x: 1, y: 1), orientation: .horizontal, playerID: "A")
        _ = board.addFence(at: .init(x: 3, y: 2), orientation: .vertical, playerID: "A")
        _ = board.addFence(at: .init(x: 3, y: 1), orientation: .horizontal, playerID: "A")
        _ = board.addFence(at: .init(x: 6, y: 5), orientation: .vertical, playerID: "A")
        _ = board.addFence(at: .init(x: 1, y: 8), orientation: .horizontal, playerID: "A")
        _ = board.addFence(at: .init(x: 2, y: 8), orientation: .vertical, playerID: "A")
        _ = board.addFence(at: .init(x: 5, y: 1), orientation: .vertical, playerID: "A")
        _ = board.addFence(at: .init(x: 5, y: 3), orientation: .vertical, playerID: "A")
        _ = board.addFence(at: .init(x: 4, y: 4), orientation: .horizontal, playerID: "A")
        _ = board.addFence(at: .init(x: 2, y: 4), orientation: .horizontal, playerID: "A")
        _ = board.addFence(at: .init(x: 1, y: 3), orientation: .vertical, playerID: "A")
        _ = board.addFence(at: .init(x: 5, y: 6), orientation: .horizontal, playerID: "A")
        _ = board.addFence(at: .init(x: 4, y: 6), orientation: .vertical, playerID: "A")
        _ = board.addFence(at: .init(x: 7, y: 4), orientation: .horizontal, playerID: "A")
        _ = board.addFence(at: .init(x: 8, y: 3), orientation: .vertical, playerID: "A")
        _ = board.addFence(at: .init(x: 7, y: 6), orientation: .horizontal, playerID: "A")
        _ = board.addFence(at: .init(x: 8, y: 5), orientation: .vertical, playerID: "A")
        finder = board.pathFinder
    }

    func testReachable() {
        XCTAssertEqual(finder.pathToGoal(
            from: .init(x: 0, y: 0),
            goal: .maxYEdge,
            generator: &g
        ).count, 23)

        XCTAssertEqual(finder.pathToGoal(
            from: .init(x: 7, y: 3),
            goal: .maxYEdge,
            generator: &g
        ).count, 10)

        XCTAssertEqual(finder.pathToGoal(
            from: .init(x: 6, y: 2),
            goal: .maxYEdge,
            generator: &g
        ).count, 10)

        XCTAssertEqual(finder.pathToGoal(
            from: .init(x: 0, y: 3),
            goal: .minYEdge,
            generator: &g
        ).count, 11)
    }

//    func testReachableMeasure() {
//        measure {
//            for _ in 0..<3000 {
//                _ = finder.pathToGoal(
//                    from: .init(x: .random(in: 0..<BoardState.width, using: &g), y: .random(in: 0..<BoardState.height, using: &g)),
//                    goal: Bool.random(using: &g) ? .maxYEdge : .minYEdge,
//                    generator: &g
//                )
//            }
//        }
//    }

    func testUnreachable() {
        XCTAssertEqual(finder.pathToGoal(
            from: .init(x: 1, y: 8),
            goal: .minYEdge,
            generator: &g
        ).count, 0)

        XCTAssertEqual(finder.pathToGoal(
            from: .init(x: 7, y: 4),
            goal: .minYEdge,
            generator: &g
        ).count, 0)

        XCTAssertEqual(finder.pathToGoal(
            from: .init(x: 6, y: 5),
            goal: .maxYEdge,
            generator: &g
        ).count, 0)
    }
}
