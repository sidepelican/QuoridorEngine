public enum GoalSide: Equatable {
    case minYEdge
    case maxYEdge

    func inbound(p: PawnPoint) -> Bool {
        switch self {
        case .minYEdge:
            return p.y == 0
        case .maxYEdge:
            return p.y == BoardState.height - 1
        }
    }
}
