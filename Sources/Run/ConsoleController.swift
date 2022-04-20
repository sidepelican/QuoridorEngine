import QuoridorEngine

class ConsoleController: PlayerController {
    let playerID: PlayerID
    let agent: GameAgent

    init(playerID: PlayerID, agent: GameAgent) {
        self.playerID = playerID
        self.agent = agent
    }

    func onRequestedTurnAction(evaluateAction: @escaping (MutatingAction) -> MutatingAction.Error?) {
        var action: MutatingAction?
        repeat {
            print("> ", terminator: "")
            let input = readLine() ?? ""
            let components = input.components(separatedBy: .whitespaces)
            switch components.first {
            case "h":
                action = .movePawn(agent.currentBoard.pawn(ofID: playerID).point + PawnPoint(x: -1, y: 0))
            case "j":
                action = .movePawn(agent.currentBoard.pawn(ofID: playerID).point + PawnPoint(x: 0, y: -1))
            case "k":
                action = .movePawn(agent.currentBoard.pawn(ofID: playerID).point + PawnPoint(x: 0, y: 1))
            case "l":
                action = .movePawn(agent.currentBoard.pawn(ofID: playerID).point + PawnPoint(x: 1, y: 0))
            case "move", "m":
                if components.count == 2 {
                    let xy = components[1].split(separator: ",")
                    if xy.count == 2 {
                        action = .movePawn(PawnPoint(x: Int32(xy[0])!, y: Int32(xy[1])!))
                    }
                }
            case "put", "p":
                if components.count == 3 {
                    let xy = components[1].split(separator: ",")
                    if xy.count == 2 {
                        let o = components[2] == "h" ? Fence.Orientation.horizontal : .vertical
                        action = .putFence(FencePoint(x: Int32(xy[0])!, y: Int32(xy[1])!), o)
                    }
                }
            case "undo":
                action = .undo
            case "":
                agent.currentBoard.dump()
                continue
            case "help":
                print("""
h: move left
j: move down
k: move up
l: move right
move <x>,<y>: move to (x,y)
put <x>,<y> <orientation>: put fenct to (x,y), orientation: h | v
undo: undo
""")
                continue
            default:
                break
            }
            if action == nil {
                print("command parse error")
            }
        } while action == nil

        if let error = evaluateAction(action!) {
            print("\(error)")
        }
    }
}
