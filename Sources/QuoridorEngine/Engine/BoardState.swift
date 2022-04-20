import Algorithms
import Foundation

//
// 盤面の左下を原点とする。GL座標空間と同じ
//
public struct BoardState: Equatable {
    public static func == (lhs: BoardState, rhs: BoardState) -> Bool {
        return lhs.fenceMap == rhs.fenceMap
            && lhs.pawns == rhs.pawns
    }

    public static let width: Int32 = 9
    public static let height: Int32 = 9
    public static let fenceSpaceWidth = width + 1
    public static let fenceSpaceHeight = height + 1

    static func isInside(_ point: PawnPoint) -> Bool {
        0..<Self.width ~= point.x && 0..<Self.height ~= point.y
    }

    public static func isInside(_ point: FencePoint) -> Bool {
        1..<BoardState.fenceSpaceWidth - 1 ~= point.x &&
            1..<BoardState.fenceSpaceHeight - 1 ~= point.y
    }

    public private(set) var fenceMap: FenceMap = .init()
    public var allFences: [(FencePoint, Fence)] {
        product(0..<Self.fenceSpaceWidth, 0..<Self.fenceSpaceHeight).compactMap { x, y in
            if let fence = fenceMap[x, y] {
                return (FencePoint(x: x, y: y), fence)
            }
            return nil
        }
    }
    public private(set) var pawns: [Pawn]
    private(set) var pathFinder: PathFinder!

    public init(pawns: [Pawn]) {
        assert(pawns.map(\.id).uniqued() == pawns.map(\.id))
        self.pawns = pawns
        pathFinder = PathFinder(fenceMap: fenceMap)
    }

    public mutating func setCustomFenceMap(_ newFenceMap: FenceMap) {
        fenceMap = newFenceMap
        pathFinder = PathFinder(fenceMap: newFenceMap)
    }

    public func pawn(ofID id: PlayerID) -> Pawn {
        pawns.first(where: { $0.id == id })!
    }
    
    public func canMovePawn(ofID id: PlayerID, to toPoint: PawnPoint) -> Bool {
        // 場外はNG
        guard Self.isInside(toPoint) else { return false }
        
        let pawn = self.pawn(ofID: id)
        let manhattan = pawn.point.manhattan(to: toPoint)
        // マンハッタン距離が1 → 壁か別のポーンがいなければOK
        if manhattan == 1 {
            return !existsFence(between: pawn.point, two: toPoint) // 壁がない
                && !pawns.contains(where: { $0.point == toPoint }) // 他ポーンがいない
        }

        if manhattan == 2 {
            // [ ] [o] [ ]
            // [ ] [B] [ ]
            // [ ] [A] [ ]
            // 単純な飛び越え
            //
            //     === ===
            // [o] [B] [o]
            // [ ] [A] [ ]
            // [ ] [ ] [ ]
            // 正面に他ポーンがいて、その背後に壁がある場合は左右に飛び越え
            let directions: [PawnPoint] = [.init(x: 0, y: 1), .init(x: 0, y: -1), .init(x: 1, y: 0), .init(x: -1, y: 0)]
            for (otherPawn, advance) in product(pawns.filter({ $0.id != pawn.id }), directions) {
                // 正面にポーンがいる
                guard pawn.point + advance == otherPawn.point
                        // 自身と他ポーン間に壁はない
                        && !existsFence(between: pawn.point, two: otherPawn.point)
                        // 他ポーンと対象地点間に壁はない
                        && !existsFence(between: otherPawn.point, two: toPoint) else { continue }

                // その裏に壁があるか、場外か
                let advancedOtherPawnPoint = otherPawn.point + advance
                let existsNoEntry = existsFence(between: otherPawn.point, two: advancedOtherPawnPoint) || !Self.isInside(advancedOtherPawnPoint)
                if existsNoEntry {
                    // 対象地点が正面でないかつ、他ポーンとの距離が1
                    if advancedOtherPawnPoint != toPoint
                        && otherPawn.point.manhattan(to: toPoint) == 1 {
                        return true
                    }
                } else {
                    // 対象地点が正面であることを確認
                    if advancedOtherPawnPoint == toPoint {
                        return true
                    }
                }
            }
        }

        return false
    }

    mutating func movePawn(ofID id: PlayerID, point: PawnPoint) -> Bool {
        guard canMovePawn(ofID: id, to: point) else { return false }
        let i = pawns.firstIndex(where: { $0.id == id })!
        pawns[i].point = point
        return true
    }

    public func canAddFence(at: FencePoint, orientation: Fence.Orientation) -> Bool {
        // 場外系
        guard Self.isInside(at) else { return false }

        // 重なる系
        if fenceMap[at.x, at.y] != nil { return false }

        // 衝突系
        switch orientation {
        case .horizontal:
            if let fence = fenceMap[at.x - 1, at.y], fence.orientation == .horizontal { return false }
            if let fence = fenceMap[at.x + 1, at.y], fence.orientation == .horizontal { return false }
        case .vertical:
            if let fence = fenceMap[at.x, at.y - 1], fence.orientation == .vertical { return false }
            if let fence = fenceMap[at.x, at.y + 1], fence.orientation == .vertical { return false }
        }

        // 特定のプレイヤーの道を塞いでしまう系
        let leadingContacts = orientation == .horizontal
            ? at.x == 1 || fenceMap[at.x - 2, at.y]?.orientation == .horizontal
            || fenceMap[at.x - 1, at.y]?.orientation == .vertical || fenceMap[at.x - 1, at.y - 1]?.orientation == .vertical || fenceMap[at.x - 1, at.y + 1]?.orientation == .vertical
            : at.y == 1 || fenceMap[at.x, at.y - 2]?.orientation == .vertical
            || fenceMap[at.x, at.y - 1]?.orientation == .horizontal || fenceMap[at.x - 1, at.y - 1]?.orientation == .horizontal || fenceMap[at.x + 1, at.y - 1]?.orientation == .horizontal
        let trailingContacts = orientation == .horizontal
            ? at.x == Self.fenceSpaceWidth - 2 || fenceMap[at.x + 2, at.y]?.orientation == .horizontal
            || fenceMap[at.x + 1, at.y]?.orientation == .vertical || fenceMap[at.x + 1, at.y - 1]?.orientation == .vertical || fenceMap[at.x + 1, at.y + 1]?.orientation == .vertical
            : at.y == Self.fenceSpaceHeight - 2 || fenceMap[at.x, at.y + 2]?.orientation == .vertical
            || fenceMap[at.x, at.y + 1]?.orientation == .horizontal || fenceMap[at.x - 1, at.y + 1]?.orientation == .horizontal || fenceMap[at.x + 1, at.y + 1]?.orientation == .horizontal
        let middleContacts = orientation == .horizontal
            ? fenceMap[at.x, at.y + 1]?.orientation == .vertical || fenceMap[at.x, at.y - 1]?.orientation == .vertical
            : fenceMap[at.x + 1, at.y]?.orientation == .horizontal || fenceMap[at.x - 1, at.y]?.orientation == .horizontal
        // 新たに追加するフェンスが道を塞ぐ可能性があるかどうか
        if (leadingContacts && trailingContacts)
            || (leadingContacts && middleContacts)
            || (middleContacts && trailingContacts) {
            var copyFences = fenceMap
            copyFences[at.x, at.y] = Fence(orientation: orientation)
            let pathFinder = PathFinder(fenceMap: copyFences)

            guard pawns.allSatisfy({ pathFinder.hasPathToGoal(pawn: $0) }) else {
                return false
            }
        }

        return true
    }

    mutating func addFence(at: FencePoint, orientation: Fence.Orientation, playerID: PlayerID) -> Bool {
        guard canAddFence(at: at, orientation: orientation) else { return false }
        let i = pawns.firstIndex(where: { $0.id == playerID })!
        if pawns[i].fencesLeft == 0 { return false }
        pawns[i].fencesLeft -= 1
        fenceMap[at.x, at.y] = Fence(orientation: orientation)
        pathFinder = PathFinder(fenceMap: fenceMap)
        return true
    }

    public func existsFence(between one: PawnPoint, two: PawnPoint) -> Bool {
        guard Self.isInside(one) && Self.isInside(two)
                && one.manhattan(to: two) == 1
        else {
            return false
        }

        var (one, two) = (one, two)
        if !(one.x <= two.x && one.y <= two.y) {
            swap(&one, &two)
        }

        // 縦か横か判定
        let isHorizontalDirection = one.y == two.y

        // pawn座標をfence座標に変換しつつ判定
        if isHorizontalDirection {
            // 例えばポーン座標で(0, 0), (1, 0)間の場合はフェンス座標で[1, 0]と[1, 1]に縦フェンスがあるかどうかを調べる
            if let fence = fenceMap[one.x + 1, one.y], fence.orientation == .vertical { return true }
            if let fence = fenceMap[one.x + 1, one.y + 1], fence.orientation == .vertical { return true }
        } else {
            if let fence = fenceMap[one.x, one.y + 1], fence.orientation == .horizontal { return true }
            if let fence = fenceMap[one.x + 1, one.y + 1], fence.orientation == .horizontal { return true }
        }

        return false
    }

    public func availableMoves(forPlayer playerID: PlayerID) -> [PawnPoint] {
        let pawn = self.pawn(ofID: playerID)

        let arounds: [PawnPoint] = [
            .init(x: 0, y: 1),
            .init(x: 0, y: -1),
            .init(x: 1, y: 0),
            .init(x: -1, y: 0),
        ]

        let hopArounds: [PawnPoint] = [
            .init(x: -1, y: -1),
            .init(x: -1, y: 1),
            .init(x: 1, y: -1),
            .init(x: 1, y: 1),
            .init(x: 0, y: 2),
            .init(x: 0, y: -2),
            .init(x: 2, y: 0),
            .init(x: -2, y: 0),
        ]

        let aroundPoints = arounds.map { $0 + pawn.point }
        let existsBesidePawn = aroundPoints.contains(where: { aroundPoint in
            pawns.contains(where: { $0.point == aroundPoint })
        })
        if existsBesidePawn {
            return chain(aroundPoints, hopArounds.lazy.map { $0 + pawn.point }).filter { p in
                canMovePawn(ofID: playerID, to: p)
            }
        } else {
            return aroundPoints.filter { p in
                canMovePawn(ofID: playerID, to: p)
            }
        }
    }
}
