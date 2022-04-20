enum PawnMove: CaseIterable {
    case up, down, left, right

    func callAsFunction(_ p: PawnPoint) -> PawnPoint {
        switch self {
        case .up:
            return PawnPoint(x: p.x, y: p.y + 1)
        case .down:
            return PawnPoint(x: p.x, y: p.y - 1)
        case .left:
            return PawnPoint(x: p.x - 1, y: p.y)
        case .right:
            return PawnPoint(x: p.x + 1, y: p.y)
        }
    }

    init?(current: PawnPoint, next: PawnPoint) {
        let sub = next - current
        switch (sub.x, sub.y) {
        case (0, 1):
            self = .up
        case (0, -1):
            self = .down
        case (-1, 0):
            self = .left
        case (1, 0):
            self = .right
        default:
            return nil
        }
    }
}
