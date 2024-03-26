public protocol GameAgentDelegate: AnyObject {
    func didUpdateGameState(_ agent: GameAgent)
}

public final class GameAgent {
    public weak var delegate: GameAgentDelegate?

    public var currentState: GameState {
        history.last!
    }
    public var currentBoard: BoardState {
        currentState.board
    }
    
    private var currentPlayer: PlayerController {
        players.first { $0.playerID == currentState.currentPlayer }!
    }

    private var players: [PlayerController]
    private var history: [GameState]

    public init() {
        players = []
        history = []
    }

    // for debugging
    public init(
        players: [PlayerController],
        game: GameState
    ) {
        self.players = players
        history = [game]
    }

    // MARK: - Public

    public func setup(
        player1: PlayerController,
        player2: PlayerController,
        firstPlayerIsOne: Bool
    ) {
        if firstPlayerIsOne {
            players = [player1, player2]
        } else {
            players = [player2, player1]
        }
        history = [GameState(
            players: players.map(\.playerID),
            turnCount: 0,
            board: BoardState(pawns: [
                Pawn(id: player1.playerID, goal: .maxYEdge, point: .init(x: 4, y: 0)),
                Pawn(id: player2.playerID, goal: .minYEdge, point: .init(x: 4, y: 8)),
            ])
        )]
    }

    public func start() {
        precondition(!players.isEmpty)
        precondition(!history.isEmpty)
        runOnMainThread {
            self.delegate?.didUpdateGameState(self)
            self.requestActionToTurnPlayer()
        }
    }

    // MARK: - Private

    private func requestActionToTurnPlayer() {
        QEdispatchPreconditionOnMainQueue()
        let actionContext = EvaluateActionContext(
            agent: self,
            state: currentState
        )
        currentPlayer.onRequestedTurnAction(evaluateAction: actionContext.callAsFunction)
    }

    private func evaluateAction(state: GameState, action: MutatingAction) -> MutatingAction.Error? {
        if currentState != state { return nil }

        let actionResult: Result<GameState, MutatingAction.Error>
        switch action {
        case .movePawn(let point):
            actionResult = state.apply(.movePawn(point))
        case .putFence(let point, let orientation):
            actionResult = state.apply(.putFence(point, orientation))
        case .undo:
            if history.count < 3 {
                actionResult = .failure(.noHistory)
            } else {
                history.removeLast(2)
                runOnMainThread {
                    self.delegate?.didUpdateGameState(self)
                }
                QEDispatchQueue.main.async {
                    self.requestActionToTurnPlayer()
                }
                return nil
            }
        }

        let newState: GameState
        switch actionResult {
        case .success(let state):
            newState = state
        case .failure(let error):
            QEDispatchQueue.main.async {
                self.requestActionToTurnPlayer()
            }
            return error
        }

        // ステート更新
        history.append(newState)
        runOnMainThread {
            self.delegate?.didUpdateGameState(self)
        }

        // 勝利確認
        if let winner = newState.players.first(where: { newState.isWin(for: $0) }) {
            print("\(winner) is win")
            return nil
        }

        QEDispatchQueue.main.async {
            self.requestActionToTurnPlayer()
        }
        return nil
    }

    private struct EvaluateActionContext {
        weak var agent: GameAgent?
        var state: GameState
        func callAsFunction(_ action: MutatingAction) -> MutatingAction.Error? {
            return agent?.evaluateAction(state: state, action: action)
        }
    }
}
