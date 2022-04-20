import Foundation
import QuoridorEngine

print("Quoridor!")

let agent = GameAgent()
let user = ConsoleController(playerID: "M", agent: agent)
let mc = MonteCarloPlayer(playerID: "M", agent: agent)
let mc2 = MonteCarloPlayer(playerID: "m", agent: agent)

agent.setup(player1: mc, player2: mc2, firstPlayerIsOne: .random())

class PrinterDelegate: GameAgentDelegate {
    func didUpdateGameState(_ agent: GameAgent) {
        agent.currentBoard.dump()
    }
}

let delegate = PrinterDelegate()
agent.delegate = delegate
agent.start()

withExtendedLifetime(delegate) {
    while !agent.currentState.isFinished {
#if canImport(Dispatch)
        RunLoop.main.run(until: Date() + 0.1)
#endif
    }
}
