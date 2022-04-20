public struct GameState: Equatable {
    public var players: [PlayerID] // この配列内の順がそのままターンの順番となる
    public var turnCount: Int
    public var board: BoardState

    public init(
        players: [PlayerID],
        turnCount: Int,
        board: BoardState
    ) {
        self.players = players
        self.turnCount = turnCount
        self.board = board
    }
    
    public var currentPlayer: PlayerID {
        players[turnCount % players.count]
    }

    public var notCurrentPlayers: [PlayerID] {
        var ret = players
        ret.remove(at: turnCount % players.count)
        return ret
    }
    
    public func isWin(for player: PlayerID) -> Bool {
        let pawn = board.pawn(ofID: player)
        return pawn.goal.inbound(p: pawn.point)
    }

    public var isFinished: Bool {
        board.pawns.contains { pawn -> Bool in
            pawn.goal.inbound(p: pawn.point)
        }
    }

    enum Mutation {
        case putFence(FencePoint, Fence.Orientation)
        case movePawn(PawnPoint)
    }
    func apply(_ mutation: Mutation) -> Result<GameState, MutatingAction.Error> {
        let newBoard: BoardState
        switch mutation {
        case .movePawn(let point):
            var board = self.board
            if !board.movePawn(ofID: currentPlayer, point: point) {
                return .failure(.cannotMove)
            }
            newBoard = board
        case .putFence(let point, let orientation):
            var board = self.board
            if !board.addFence(at: point, orientation: orientation, playerID: currentPlayer) {
                return .failure(.cannotPut)
            }
            newBoard = board
        }
        
        return .success(.init(
            players: players,
            turnCount: turnCount + 1,
            board: newBoard
        ))
    }
}
