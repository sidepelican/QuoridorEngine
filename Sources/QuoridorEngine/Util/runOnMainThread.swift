#if canImport(Dispatch)
import Foundation
import Dispatch

func runOnMainThread(_ task: @escaping () -> ()) {
    if Thread.isMainThread {
        task()
    } else {
        DispatchQueue.main.async {
            task()
        }
    }
}
#else
struct DispatchQueue {
    enum Qos {
        case background
        case utility
        case `default`
        case userInitiated
        case userInteractive
        case unspecified
    }

    static let main = DispatchQueue(label: "main", qos: .userInteractive)

    var label: String
    var qos: Qos

    func sync(execute block: () -> Void) {
        block()
    }

    func sync<T>(execute work: () throws -> T) rethrows -> T {
        try work()
    }

    func async(_ task: @escaping () -> ()) {
        task()
    }

    static func concurrentPerform(iterations: Int, execute work: (Int) -> Void) {
        for i in 0..<iterations {
            work(i)
        }
    }
}

func runOnMainThread(_ task: @escaping () -> ()) {
    task()
}

enum DispatchCondition {
    case onQueue(DispatchQueue)
}

func dispatchPrecondition(condition: DispatchCondition) {
}
#endif
