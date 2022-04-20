public struct FenceMap: Equatable {
    // INFO: 現実の動作として座標空間の外周にフェンスが設置されることはないため、その分を省いた領域を確保する
    private var fences: [Fence?] = .init(repeating: nil, count: Int(BoardState.fenceSpaceWidth - 2) * Int(BoardState.fenceSpaceHeight - 2))

    public init() {}

    public subscript(x: Int32, y: Int32) -> Fence? {
        get {
            guard 1..<BoardState.fenceSpaceWidth - 1 ~= x && 1..<BoardState.fenceSpaceHeight - 1 ~= y else {
                return nil
            }
            let offset = Int((x - 1) + (y - 1) * (BoardState.fenceSpaceWidth - 2))
            return fences[offset]
        }
        _modify {
            assert(1..<BoardState.fenceSpaceWidth - 1 ~= x && 1..<BoardState.fenceSpaceHeight - 1 ~= y)
            yield &fences[Int((x - 1) + (y - 1) * (BoardState.fenceSpaceWidth - 2))]
        }
    }
}
