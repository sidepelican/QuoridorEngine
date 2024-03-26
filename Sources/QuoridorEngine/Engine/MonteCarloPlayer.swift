import Algorithms

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

public final class MonteCarloPlayer: PlayerController {
    public init(
        playerID: PlayerID,
        agent: GameAgent
    ) {
        self.playerID = playerID
        self.agent = agent
    }

    private let agent: GameAgent
    private let queue = QEDispatchQueue(label: "MonteCarloPlayer", qos: .userInitiated)
    private let mcts = MonteCarloTreeSearch()

    // MARK: - PlayerController

    public let playerID: PlayerID
    
    public func onRequestedTurnAction(evaluateAction: @escaping (MutatingAction) -> MutatingAction.Error?) {
        queue.async {
            let player = self.agent.currentState.currentPlayer
            let s = SuspendingClock.now
            self.mcts.setGameState(self.agent.currentState)
            let mutation = self.mcts.searchBestMove(simulationCount: 7500)

            if let error = evaluateAction(MutatingAction(from: mutation)) {
                print("\(error)")
            }
            
            self.mcts.root.children.sorted(by: { $0.winRatio >  $1.winRatio }).prefix(3).forEach { child in
                var buf = "child: \(child.mutation!) uct: \(child.uctValue)\n"
                buf += "       win/simulated: \(child.winCount)/\(child.simulatedCount - child.skippedCount) = \(child.winRatio)"
                if child.skippedCount > 0 { buf += " (skipped: \(child.skippedCount))" }
                print(buf)
            }
            print("elapsed:", s.duration(to: .now))
            print("estimated AI \(player) winRatio:", self.mcts.root.maxWinRateChild?.winRatio ?? "")
        }
    }
}

private let rolloutChunkSize: Int = 12

private final class MonteCarloTreeSearch {
    init() {
        var seeder = SplitMix64Generator()
        gs = (0..<rolloutChunkSize).map { _ in DefaultRandomGenerator(using: &seeder) }
    }

    private(set) var root: Node!
    private var totalSimulationsCount: Int = 0
    private var gs: [DefaultRandomGenerator]

    func setGameState(_ gameState: GameState) {
        if root != nil, let n = root.children.lazy.flatMap({ $0.children }).first(where: { $0.makeGame() == gameState }) {
            n.promoteAsRoot()
            root = n
            print("last node was promoted as root. children's simulated counts:", n.children.map(\.simulatedCount))
        } else {
            root = Node(gameState: gameState)
        }
    }

    func searchBestMove(simulationCount: Int) -> GameState.Mutation {
        // 初手は固定で前進
        let rootGame = root.makeGame()
        if rootGame.turnCount < 2 {
            let pawn = rootGame.board.pawn(ofID: rootGame.currentPlayer)
            let move = availableShortestMoves(
                availableMoves: rootGame.board.availableMoves(forPlayer: pawn.id),
                shortestPath: rootGame.board.pathFinder.pathToGoal(from: pawn.point, goal: pawn.goal, generator: &gs[0])
            ).unsafeRandomElement(using: &gs[0])
            return .movePawn(move)
        }

        let nextTotalSimulationsCount = totalSimulationsCount + simulationCount
        while totalSimulationsCount < nextTotalSimulationsCount {
            expansion()
        }

        var bestNode = root.maxWinRateChild!

        // ほぼ勝ち確の状態で移動する場合は必ず最短経路を選択する（無駄に遠回りして煽り行動をしうるため）
        // ほぼ負け確の状態もランダムで移動するよりはマシなので最短経路で移動する
        if !(0.045...0.98).contains(bestNode.winRatio), case .movePawn = bestNode.mutation {
            let board = rootGame.board
            let pawn = board.pawn(ofID: bestNode.actionPlayer)
            let shortestPath = board.pathFinder.pathToGoal(from: pawn.point, goal: pawn.goal, generator: &gs[0])

            if let shortest = root.children.first(where: { child in
                if child === bestNode { return false }
                if case .movePawn(let p) = child.mutation, p == shortestPath[1] {
                    return true
                }
                return false
            }) {
                print("ほぼ勝ち(or負け)確のため最短でない移動を最短パスに変更")
                bestNode = shortest
            }
        }

        // ほぼ負け確の状態での無意味なフェンス置きをやめさせる
        if bestNode.winRatio < 0.02, case .putFence = bestNode.mutation {
            let theActionHasMeans = rootGame.board.pawns.filter { $0.id != bestNode.actionPlayer }.contains { oppPawn in
                // フェンスを置くことによって相手の最短経路が伸びるかどうか検証
                let currentOppDistance = rootGame.board.pathFinder.distanceToGoal(pawn: oppPawn)
                let afterDistance = (try! rootGame.apply(bestNode.mutation.unsafelyUnwrapped).get()).board.pathFinder.distanceToGoal(pawn: oppPawn)
                return currentOppDistance < afterDistance
            }
            if !theActionHasMeans {
                if let moveNode = root.children.sorted(by: { $0.winRatio >  $1.winRatio }).first(where: { n -> Bool in
                    if case .movePawn = n.mutation { return true }
                    return false
                }) {
                    print("ほぼ負け確の状態での無意味なフェンス置きを移動に置換")
                    bestNode = moveNode
                }
            }
        }

        // 移動行動の中で勝率が並んでいる場合は最短経路を選択（何故勝率が並んでしまうかはよくわからない）
        if case .movePawn(let bestNodeMove) = bestNode.mutation {
            let threshold: Float = 0.02
            let siblings = root.children.filter { child -> Bool in
                if child === bestNode { return false }
                if case .movePawn = child.mutation, child.winRatio + threshold > bestNode.winRatio {
                    return true
                }
                return false
            }
            if !siblings.isEmpty {
                let board = rootGame.board
                let pawn = board.pawn(ofID: bestNode.actionPlayer)
                let shortestPath = board.pathFinder.pathToGoal(from: pawn.point, goal: pawn.goal, generator: &gs[0])

                // bestNodeがすでに最短パスのうちの1つであるならやらない
                if !(board.pathFinder.distanceToGoal(from: bestNodeMove, goal: pawn.goal) + 1 == shortestPath.count) {
                    if let shortest = siblings.first(where: { child -> Bool in
                        if case .movePawn(let p) = child.mutation, p == shortestPath[1] {
                            return true
                        }
                        return false
                    }) {
                        print("移動行動の中で勝率が並んでいるので最短経路のものを優先")
                        bestNode = shortest
                    }
                }
            }
        }

        return bestNode.mutation.unsafelyUnwrapped
    }

    // MARK: - expansion

    private func expansion() {
        let targetNodes = findNextRolloutCandidates(node: root)
        guard targetNodes.count == 1 else {
            concurrentRollout(candidateNodes: targetNodes)
            return
        }

        let targetNode = targetNodes[0]
        assert(totalSimulationsCount == 0 || (totalSimulationsCount > 0 && !targetNode.isRoot))

        // 開くべきノードが存在しない場合、新しいノードを追加する
        if (targetNode.isSimulated || targetNode.isRoot) && !targetNode.isTerminal {
            assert(targetNode.children.allSatisfy({ $0.isSimulated }), "シミュレート可能なノードがある場合はまずそちらをrolloutするべき")

            let game = targetNode.makeGame()
            let player = game.currentPlayer
            let pawn = game.board.pawn(ofID: player)
            let otherPlayersHasNoWalls = game.board.pawns.filter { $0.id != player }.allSatisfy { $0.fencesLeft == 0 }
            var newNodes: [Node] = []

            // 移動
            let availableMoves = game.board.availableMoves(forPlayer: player)
            if otherPlayersHasNoWalls {
                // 他のプレイヤーが全員壁を持っていない場合は妨害の心配がないため最短経路を選択する
                let moves = availableShortestMoves(
                    availableMoves: availableMoves,
                    shortestPath: game.board.pathFinder.pathToGoal(from: pawn.point, goal: pawn.goal, generator: &gs[0])
                )
                for move in moves {
                    newNodes.append(Node(mutation: .movePawn(move), actionPlayer: player, parent: targetNode))
                }
            } else {
                for move in availableMoves {
                    newNodes.append(Node(mutation: .movePawn(move), actionPlayer: player, parent: targetNode))
                }
            }

            // 壁設置
            if pawn.fencesLeft > 0 {
                // 他のプレイヤーが全員壁を持っていない場合は相手の進路の妨げとなりうる箇所に集中する。自分を守る必要性がないため
                let candidateFences: [FenceWithPoint]
                if otherPlayersHasNoWalls {
                    let oppPawn = game.board.pawns.filter { $0.id != player }.unsafeRandomElement(using: &gs[0])
                    let oppPath = game.board.pathFinder.pathToGoal(from: oppPawn.point, goal: oppPawn.goal, generator: &gs[0])
                    if pawn.fencesLeft == 1 {
                        // 最後のフェンスの場合、パスと平行に並べて選択肢を与える戦法が機能しないので確実にパスを阻害する場所だけを候補にする
                        candidateFences = pathBlockingFences(path: oppPath)
                    } else {
                        // パスと平行に並べて選択肢を与える戦法を与えるために全周囲を候補
                        candidateFences = oppPath.dropFirst().dropLast().flatMap { $0.makeAroundedFences() }.uniqued()
                    }
                } else {
                    candidateFences = nextCandidateFences(game: game, using: &gs[0])
                }

                newNodes += candidateFences
                    .lazy
                    .filter { game.board.canAddFence(at: $0.point, orientation: $0.orientation) }
                    .map { GameState.Mutation.putFence($0.point, $0.orientation) }
                    .map { Node(mutation: $0, actionPlayer: player, parent: targetNode) }
            }

            targetNode.children.append(contentsOf: newNodes)

            switch newNodes.count {
            case 0:
                preconditionFailure("ここには来ないはず")
            case 1:
                // 1個しか子ノードがないならシミュレートをスキップ
                newNodes[0].isTerminal = newNodes[0].makeGame().isFinished // 終端チェックだけは行う
                // back propagation
                totalSimulationsCount += 1
                for ancestor in sequence(first: newNodes[0], next: { $0.parent }) {
                    ancestor.simulatedCount += 1
                    ancestor.skippedCount += 1
                }
            default:
                // 追加したノードをまとめて並列でrolloutする
                concurrentRollout(candidateNodes: newNodes)
            }
            return
        }

        totalSimulationsCount += 1
        let (node, resultScene) = rollout(node: targetNode, using: &gs[0])
        // back propagation
        for ancestor in sequence(first: node, next: { $0.parent }) {
            ancestor.simulatedCount += 1
            if resultScene.isWin(for: ancestor.actionPlayer) {
                ancestor.winCount += 1
            }
        }
    }

    private let rolloutSyncQueue = QEDispatchQueue(label: "MonteCarloPlayer.rolloutSync", qos: .userInteractive)
    private func concurrentRollout(candidateNodes: [Node]) {
        // rolloutChunkSizeの数まで絞って並列でrolloutする
        let selectedNodes = candidateNodes.randomSample(count: rolloutChunkSize, using: &gs[0])
        var rolloutResults: [(node: Node, resultScene: GameState)?] = .init(repeating: nil, count: selectedNodes.count)

        QEDispatchQueue.concurrentPerform(iterations: selectedNodes.count) { i in
            var g = rolloutSyncQueue.sync {
                gs[i]
            }
            let result = rollout(node: selectedNodes[i], using: &g)
            rolloutSyncQueue.sync {
                gs[i] = g
                rolloutResults[i] = result
            }
        }

        // back propagation
        for (node, resultScene) in rolloutResults.compactMap({ $0 }) {
            for ancestor in sequence(first: node, next: { $0.parent }) {
                ancestor.simulatedCount += 1
                if resultScene.isWin(for: ancestor.actionPlayer) {
                    ancestor.winCount += 1
                }
            }
        }
        totalSimulationsCount += selectedNodes.count
    }

    private func findNextRolloutCandidates(node: Node) -> [Node] {
        var node = node
        while true {
            let unsimulated = node.children.filter({ !$0.isSimulated })
            if !unsimulated.isEmpty {
                return unsimulated
            }

            if node.children.isEmpty { return [node] }

            // looking at MaxUCTChild
            var maxNodes = [node.children[0]]
            var maxUct = node.children[0].uctValue
            for child in node.children.suffix(from: 1) {
                let uct = child.uctValue
                if uct > maxUct {
                    maxUct = uct
                    maxNodes = [child]
                } else if uct == maxUct {
                    maxNodes.append(child)
                }
            }
            node = maxNodes.unsafeRandomElement(using: &gs[0])
        }
    }
}

private func rollout<T: RandomNumberGenerator>(node: Node, using g: inout T) -> (node: Node, resultScene: GameState) {
    var game = node.makeGame()
    if game.isFinished {
        node.isTerminal = true
    }

    var lastPoints: [PlayerID: PawnPoint] = [:]

    while !game.isFinished {
        let pawn = game.board.pawn(ofID: game.currentPlayer)

        let rnd = Int.random(in: 0..<100, using: &g)
        if rnd < 30 {
            if pawn.fencesLeft > 0 {
                if let putFence = nextCandidateFences(game: game, using: &g).shuffled(using: &g).first(where: { p in
                    game.board.canAddFence(at: p.point, orientation: p.orientation)
                }) {
                    // ランダムにフェンスを置く
                    game = try! game.apply(.putFence(putFence.point, putFence.orientation)).get()
                    continue
                }
            } else {
                // フェンスを使い切っている場合
                let otherPlayersHasWalls = game.board.pawns.filter { $0.id != pawn.id }.contains { $0.fencesLeft > 0 }
                if otherPlayersHasWalls {
                    // 後ろ向きに動く（早期にフェンスを使い切ると弱いため、使い切りにくくなるよう弱い行動をする）
                    let availableMoves = game.board.availableMoves(forPlayer: pawn.id)
                    if let last = lastPoints[pawn.id], availableMoves.contains(last) {
                        game = try! game.apply(.movePawn(last)).get()
                        lastPoints.removeValue(forKey: pawn.id)
                        continue
                    }
                }
            }
        } else if rnd < 31 {
            // 完全にランダムに移動
            let moves = game.board.availableMoves(forPlayer: pawn.id)
            game = try! game.apply(.movePawn(moves.unsafeRandomElement(using: &g))).get()
            continue
        }

        if pawn.fencesLeft < 2 {
            lastPoints[pawn.id] = pawn.point
        }

        // 最短距離を移動する
        // 最短経路が複数ある場合、妨害されやすい経路とそうでない経路があるためランダムに選択させる
        let moves = availableShortestMoves(
            availableMoves: game.board.availableMoves(forPlayer: pawn.id),
            shortestPath: game.board.pathFinder.pathToGoal(from: pawn.point, goal: pawn.goal, generator: &g)
        )
        game = try! game.apply(.movePawn(moves.unsafeRandomElement(using: &g))).get()
    }

    return (node, game)
}

private func pathBlockingFences(path: [PawnPoint]) -> [FenceWithPoint] {
    path.windows(ofCount: 2).flatMap { w -> [FenceWithPoint] in
        let current = w[w.startIndex], next = w[w.index(after: w.startIndex)]
        switch PawnMove(current: current, next: next) {
        case .up:
            return [.init(x: current.x, y: current.y + 1, o: .horizontal),
                    .init(x: current.x + 1, y: current.y + 1, o: .horizontal)]
        case .down:
            return [.init(x: current.x, y: current.y, o: .horizontal),
                    .init(x: current.x + 1, y: current.y, o: .horizontal)]
        case .left:
            return [.init(x: current.x, y: current.y, o: .vertical),
                    .init(x: current.x, y: current.y + 1, o: .vertical)]
        case .right:
            return [.init(x: current.x + 1, y: current.y, o: .vertical),
                    .init(x: current.x + 1, y: current.y + 1, o: .vertical)]
        default:
            return []
        }
    }
}

private func nextCandidateFences<T: RandomNumberGenerator>(game: GameState, using generator: inout T) -> [FenceWithPoint] {
    var ret: [FenceWithPoint] = []
    var fenceMapIsEmpty = true

    // 既に置かれているフェンスの近く
    for (p, fence) in game.board.allFences {
        fenceMapIsEmpty = false
        switch fence.orientation {
        case .horizontal:
            ret.append(FenceWithPoint(x: p.x - 2, y: p.y, o: .horizontal))
            ret.append(FenceWithPoint(x: p.x + 2, y: p.y, o: .horizontal))
            ret.append(FenceWithPoint(x: p.x - 3, y: p.y, o: .horizontal))
            ret.append(FenceWithPoint(x: p.x + 3, y: p.y, o: .horizontal))
//                ret.append(FenceWithPoint(x: p.x, y: p.y - 1, o: .vertical))
            ret.append(FenceWithPoint(x: p.x - 1, y: p.y - 1, o: .vertical))
            ret.append(FenceWithPoint(x: p.x + 1, y: p.y - 1, o: .vertical))
//                ret.append(FenceWithPoint(x: p.x, y: p.y + 1, o: .vertical))
            ret.append(FenceWithPoint(x: p.x - 1, y: p.y + 1, o: .vertical))
            ret.append(FenceWithPoint(x: p.x + 1, y: p.y + 1, o: .vertical))
//                ret.append(FenceWithPoint(x: p.x + 1, y: p.y, o: .vertical))
//                ret.append(FenceWithPoint(x: p.x - 1, y: p.y, o: .vertical))
            ret.append(FenceWithPoint(x: p.x + 2, y: p.y, o: .vertical))
            ret.append(FenceWithPoint(x: p.x - 2, y: p.y, o: .vertical))
        case .vertical:
            ret.append(FenceWithPoint(x: p.x, y: p.y - 2, o: .vertical))
            ret.append(FenceWithPoint(x: p.x, y: p.y + 2, o: .vertical))
            ret.append(FenceWithPoint(x: p.x, y: p.y - 3, o: .vertical))
            ret.append(FenceWithPoint(x: p.x, y: p.y + 3, o: .vertical))
//                ret.append(FenceWithPoint(x: p.x - 1, y: p.y, o: .horizontal))
            ret.append(FenceWithPoint(x: p.x - 1, y: p.y - 1, o: .horizontal))
            ret.append(FenceWithPoint(x: p.x - 1, y: p.y + 1, o: .horizontal))
//                ret.append(FenceWithPoint(x: p.x + 1, y: p.y, o: .horizontal))
            ret.append(FenceWithPoint(x: p.x + 1, y: p.y - 1, o: .horizontal))
            ret.append(FenceWithPoint(x: p.x + 1, y: p.y + 1, o: .horizontal))
//                ret.append(FenceWithPoint(x: p.x, y: p.y + 1, o: .horizontal))
//                ret.append(FenceWithPoint(x: p.x, y: p.y - 1, o: .horizontal))
            ret.append(FenceWithPoint(x: p.x, y: p.y + 2, o: .horizontal))
            ret.append(FenceWithPoint(x: p.x, y: p.y - 2, o: .horizontal))
        }
    }

    let pawn = game.board.pawn(ofID: game.currentPlayer)

    // 外周に隣接する水平フェンス
    if game.turnCount >= 8 {
        // 残りフェンスがない状態ではやらない（閉路を作って大回りさせる用であり、終盤苦し紛れに壁で出す手ではない。壁として出す場合は他の候補に同等のものがあるので大丈夫なはず）
        if pawn.fencesLeft > 2 {
            // 横から水平にフェンス伸ばしがちで微妙なので縦の通路を閉じれるようの1箇所だけにしている
            let y = [Int32](arrayLiteral: 1, 2, 3).unsafeRandomElement(using: &generator)
            ret.append(FenceWithPoint(x: 1, y: y, o: .horizontal))
            ret.append(FenceWithPoint(x: BoardState.fenceSpaceWidth - 1, y: y, o: .horizontal))
            ret.append(FenceWithPoint(x: 1, y: BoardState.fenceSpaceHeight - 1 - y, o: .horizontal))
            ret.append(FenceWithPoint(x: BoardState.fenceSpaceWidth - 1, y: BoardState.fenceSpaceHeight - 1 - y, o: .horizontal))
        }
    }

    // ポーンの周囲
    if game.turnCount >= 4 {
        // 相手の妨害
        let opp = game.notCurrentPlayers.unsafeRandomElement(using: &generator)
        let oppPawn = game.board.pawn(ofID: opp)
        ret.append(contentsOf: oppPawn.point.makeAroundedFences())
    }
    if game.turnCount >= 7 || !fenceMapIsEmpty {
        // 自身の補助
        ret.append(contentsOf: pawn.point.makeAroundedFences())
    }

    // 定石と呼ばれるもの // ここに書いても選ばれない可能性が高いので確率で固定行動をさせたほうがいいかもしれない
    // https://quoridor.jp/wiki/?シラー氏
    if (game.turnCount == 4 || game.turnCount == 5) && fenceMapIsEmpty {
        let rand: Int32 = Bool.random(using: &generator) ? 1 : 0
        switch pawn.goal {
        case .minYEdge:
            ret.append(FenceWithPoint(x: BoardState.width / 2 + rand, y: BoardState.height - 1, o: .vertical))
        case .maxYEdge:
            ret.append(FenceWithPoint(x: BoardState.width / 2 + rand, y: 1, o: .vertical))
        }
    }
    // https://quoridor.jp/wiki/?最速の２段
    if game.turnCount == 2 { // 先行の2回目行動時のみ
        let rand: Int32 = Bool.random(using: &generator) ? -1 : 2
        switch pawn.goal {
        case .minYEdge:
            ret.append(FenceWithPoint(x: BoardState.width / 2 + rand, y: BoardState.height - 2, o: .horizontal))
        case .maxYEdge:
            ret.append(FenceWithPoint(x: BoardState.width / 2 + rand, y: 2, o: .horizontal))
        }
    }

    return ret.uniqued()
}

private func availableShortestMoves(availableMoves: [PawnPoint], shortestPath: [PawnPoint]) -> [PawnPoint] {
    if shortestPath.count > 2 && availableMoves.contains(shortestPath[2]) {
        return [shortestPath[2]]
    } else if shortestPath.count > 1 && availableMoves.contains(shortestPath[1]) {
        return [shortestPath[1]]
    } else {
        return availableMoves
    }
}

private let uctConst: Float = 0.5

private final class Node {
    let mutation: GameState.Mutation?
    let actionPlayer: PlayerID
    private(set) weak var parent: Node?
    var children: [Node] = []
    var winCount = 0
    var skippedCount = 0
    var simulatedCount = 0
    var isTerminal: Bool = false

    var isRoot: Bool {
        parent == nil
    }

    var isSimulated: Bool {
        simulatedCount > 0
    }

    var uctValue: Float {
        guard let parent = parent else { fatalError() }
        return winRatio + sqrt((uctConst * log(Float(parent.simulatedCount))) / Float(simulatedCount))
    }

    var winRatio: Float {
        Float(winCount) / Float(simulatedCount - skippedCount)
    }

    var maxWinRateChild: Node? {
        children.max { (lhs, rhs) -> Bool in
            lhs.winRatio < rhs.winRatio
        }
    }

    private var gameStateForRoot: GameState?

    func promoteAsRoot() {
        gameStateForRoot = makeGame()
        parent = nil
    }

    func makeGame() -> GameState {
        var game: GameState!
        for node in Array(sequence(first: self, next: { $0.parent })).reversed() {
            if node.isRoot {
                game = node.gameStateForRoot
            } else {
                game = try! game.apply(node.mutation!).get()
            }
        }
        return game
    }

    init(
        mutation: GameState.Mutation?,
        actionPlayer: PlayerID,
        parent: Node?
    ) {
        self.mutation = mutation
        self.actionPlayer = actionPlayer
        self.parent = parent
        self.gameStateForRoot = nil
    }

    init(
        gameState: GameState
    ) {
        self.mutation = nil
        self.actionPlayer = gameState.currentPlayer
        self.parent = nil
        self.gameStateForRoot = gameState
    }
}
