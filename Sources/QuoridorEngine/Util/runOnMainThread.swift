#if os(WASI)
func runOnMainThread(_ task: @escaping () -> ()) {
    task()
}

struct QEDispatchQueue {
    enum Qos {
        case background
        case utility
        case `default`
        case userInitiated
        case userInteractive
        case unspecified
    }

    static let main = QEDispatchQueue(label: "main", qos: .userInteractive)

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

@inlinable
func QEdispatchPreconditionOnMainQueue() {
}
#else
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

typealias QEDispatchQueue = DispatchQueue

@inlinable
func QEdispatchPreconditionOnMainQueue() {
    dispatchPrecondition(condition: .onQueue(.main))
}
#endif
