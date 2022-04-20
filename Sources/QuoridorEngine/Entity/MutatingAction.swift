public enum MutatingAction: CustomStringConvertible {
    public enum Error: Swift.Error {
        case cannotPut
        case cannotMove
        case notImplemented
        case noHistory
    }

    case putFence(FencePoint, Fence.Orientation)
    case movePawn(PawnPoint)
    case undo

    public var description: String {
        switch self {
        case .putFence(let p, let o):
            return "putFence(\(p.x), \(p.y), \(o))"
        case .movePawn(let p):
            return "movePawn(\(p.x), \(p.y))"
        case .undo:
            return "undo"
        }
    }

    init(from mutation: GameState.Mutation) {
        switch mutation {
        case .movePawn(let point):
            self = .movePawn(point)
        case .putFence(let point, let orientation):
            self = .putFence(point, orientation)
        }
    }
}
