public struct Fence: Equatable {
    @frozen public enum Orientation {
        case horizontal
        case vertical
    }

    public var orientation: Orientation

    public init(
        orientation: Orientation = .horizontal
    ) {
        self.orientation = orientation
    }
}

struct FenceWithPoint: Equatable {
    var point: FencePoint
    var orientation: Fence.Orientation {
        get {
            fence.orientation
        }
        set {
            fence.orientation = newValue
        }
    }
    var fence: Fence

    init(x: Int32, y: Int32, o: Fence.Orientation) {
        point = .init(x: x, y: y)
        fence = .init(orientation: o)
    }
}

extension PawnPoint {
    func makeAroundedFences() -> [FenceWithPoint] {
        [
            FenceWithPoint(x: x, y: y, o: .horizontal),
            FenceWithPoint(x: x + 1, y: y, o: .horizontal),
            FenceWithPoint(x: x, y: y, o: .vertical),
            FenceWithPoint(x: x, y: y + 1, o: .vertical),
            FenceWithPoint(x: x, y: y + 1, o: .horizontal),
            FenceWithPoint(x: x + 1, y: y + 1, o: .horizontal),
            FenceWithPoint(x: x + 1, y: y, o: .vertical),
            FenceWithPoint(x: x + 1, y: y + 1, o: .vertical),
        ]
    }
}
