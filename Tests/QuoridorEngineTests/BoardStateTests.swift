@testable import QuoridorEngine
import XCTest

final class BoardStateTests: XCTestCase {
    lazy var board: BoardState = {
        var board = BoardState(pawns: [
            .init(id: "A", goal: .maxYEdge, point: .init(x: 4, y: 7)),
            .init(id: "X", goal: .maxYEdge, point: .init(x: 4, y: 6)),
            .init(id: "Y", goal: .maxYEdge, point: .init(x: 5, y: 7)),
            .init(id: "B", goal: .maxYEdge, point: .init(x: 4, y: 0)),
            .init(id: "M", goal: .maxYEdge, point: .init(x: 1, y: 1)),
            .init(id: "N", goal: .maxYEdge, point: .init(x: 0, y: 1)),
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
        _ = board.addFence(at: .init(x: 1, y: 3), orientation: .vertical, playerID: "X")
        _ = board.addFence(at: .init(x: 5, y: 6), orientation: .horizontal, playerID: "X")
        _ = board.addFence(at: .init(x: 4, y: 6), orientation: .vertical, playerID: "X")
        _ = board.addFence(at: .init(x: 7, y: 4), orientation: .horizontal, playerID: "X")
        _ = board.addFence(at: .init(x: 8, y: 3), orientation: .vertical, playerID: "X")
        _ = board.addFence(at: .init(x: 7, y: 6), orientation: .horizontal, playerID: "X")
        _ = board.addFence(at: .init(x: 8, y: 5), orientation: .vertical, playerID: "X")
//        board.dump()
        return board
    }()

    func testCanAddFence() {
        XCTAssertTrue(board.canAddFence(at: .init(x: 7, y: 5), orientation: .horizontal))
        XCTAssertTrue(board.canAddFence(at: .init(x: 7, y: 5), orientation: .vertical))
        XCTAssertTrue(board.canAddFence(at: .init(x: 3, y: 3), orientation: .horizontal))
        XCTAssertTrue(board.canAddFence(at: .init(x: 2, y: 2), orientation: .vertical))
        XCTAssertTrue(board.canAddFence(at: .init(x: 4, y: 1), orientation: .vertical))
        XCTAssertTrue(board.canAddFence(at: .init(x: 4, y: 2), orientation: .vertical))
        XCTAssertTrue(board.canAddFence(at: .init(x: 4, y: 3), orientation: .vertical))
    }

//    func testMeasureAvailableMoves() {
//        let players = (0..<10000).map { _ in board.pawns.randomElement()!.id }
//        measure {
//            players.forEach { p in
//                _ = board.availableMoves(forPlayer: p)
//            }
//        }
//    }

    func testCannotAddFence() {
        // 場外系
        XCTAssertFalse(board.canAddFence(at: .init(x: 0, y: 1), orientation: .vertical))
        XCTAssertFalse(board.canAddFence(at: .init(x: 3, y: 9), orientation: .horizontal))
        XCTAssertFalse(board.canAddFence(at: .init(x: 3, y: 9), orientation: .vertical))

        // 衝突系
        XCTAssertFalse(board.canAddFence(at: .init(x: 1, y: 4), orientation: .vertical))
        XCTAssertFalse(board.canAddFence(at: .init(x: 8, y: 4), orientation: .horizontal))

        // 重なり系
        XCTAssertFalse(board.canAddFence(at: .init(x: 2, y: 4), orientation: .horizontal))
        XCTAssertFalse(board.canAddFence(at: .init(x: 2, y: 4), orientation: .vertical))

        // 道を塞いでしまう系
        XCTAssertFalse(board.canAddFence(at: .init(x: 4, y: 2), orientation: .horizontal))

    }

    func testCannotAddFence2() {
        // 道を塞いでしまう系
        var board = BoardState(pawns: [
            .init(id: "M", goal: .minYEdge, point: .init(x: 3, y: 7)),
        ])
        _ = board.addFence(at: .init(x: 4, y: 8), orientation: .vertical, playerID: "M")
        _ = board.addFence(at: .init(x: 3, y: 7), orientation: .horizontal, playerID: "M")
        XCTAssertFalse(board.canAddFence(at: .init(x: 3, y: 8), orientation: .vertical))
    }
    
    func testNoFencesLeft() {
        XCTAssertFalse(board.addFence(at: .init(x: 8, y: 5), orientation: .vertical, playerID: "A"))
        XCTAssertTrue(board.addFence(at: .init(x: 7, y: 5), orientation: .horizontal, playerID: "X"))
    }

    func testCanMove() {
        // 自身と同じ場所
        XCTAssertFalse(board.canMovePawn(ofID: "A", to: .init(x: 4, y: 7)))
        
        // 場外
        XCTAssertFalse(board.canMovePawn(ofID: "B", to: .init(x: 4, y: -1)))

        // 普通の1マス移動
        XCTAssertTrue(board.canMovePawn(ofID: "A", to: .init(x: 4, y: 8)))
        XCTAssertFalse(board.canMovePawn(ofID: "A", to: .init(x: 5, y: 7)))
        XCTAssertFalse(board.canMovePawn(ofID: "X", to: .init(x: 3, y: 4)))

        // 直線飛び越え
        XCTAssertTrue(board.canMovePawn(ofID: "A", to: .init(x: 6, y: 7)))
        XCTAssertFalse(board.canMovePawn(ofID: "A", to: .init(x: 4, y: 5)))
        XCTAssertFalse(board.canMovePawn(ofID: "A", to: .init(x: 2, y: 7)))

        // 壁あり飛び越え
        XCTAssertTrue(board.canMovePawn(ofID: "A", to: .init(x: 5, y: 6)))
        XCTAssertFalse(board.canMovePawn(ofID: "A", to: .init(x: 5, y: 8)))
        XCTAssertFalse(board.canMovePawn(ofID: "A", to: .init(x: 3, y: 6)))
        XCTAssertFalse(board.canMovePawn(ofID: "A", to: .init(x: 3, y: 8)))

        // 場外を壁とした飛び越え
        XCTAssertTrue(board.canMovePawn(ofID: "M", to: .init(x: 0, y: 2)))
        XCTAssertFalse(board.canMovePawn(ofID: "M", to: .init(x: 0, y: 0)))
    }
}
