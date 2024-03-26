public struct Pawn: Equatable {
    public var id: PlayerID
    public var goal: GoalSide
    public var point: PawnPoint
    public var fencesLeft: Int

    public init(
        id: PlayerID,
        goal: GoalSide,
        point: PawnPoint,
        fencesLeft: Int = 10
    ) {
        self.id = id
        self.goal = goal
        self.point = point
        self.fencesLeft = fencesLeft
    }
}
