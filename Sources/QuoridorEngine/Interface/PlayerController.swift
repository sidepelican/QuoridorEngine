import Foundation

public protocol PlayerController {
    var playerID: PlayerID { get }
    func onRequestedTurnAction(evaluateAction: @escaping (MutatingAction) -> MutatingAction.Error?)
}
