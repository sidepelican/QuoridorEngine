public final class PathFinder {
    private let fenceMap: FenceMap
    init(fenceMap: FenceMap) {
        self.fenceMap = fenceMap
    }

    deinit {
        lastNodeMap?.dealloc()
    }

    public func distanceToGoal(pawn: Pawn) -> Int {
        distanceToGoal(from: pawn.point, goal: pawn.goal)
    }

    public func distanceToGoal(from: PawnPoint, goal: GoalSide) -> Int {
        var nopGenerator = NotRandomGenerator()
        let (goal, nodeMap) = pathToGoal(from: from, goal: goal, generator: &nopGenerator)
        defer { nodeMap.dealloc() }
        guard let goalPoint = goal else {
            return 0
        }

        return sequence(first: goalPoint, next: { nodeMap[$0].previous }).reduce(0) { r, _ in r + 1 }
    }

    public func pathToGoal<T: RandomNumberGenerator>(
        from: PawnPoint,
        goal: GoalSide,
        generator: inout T
    ) -> [PawnPoint] {
        let (goal, nodeMap) = pathToGoal(from: from, goal: goal, generator: &generator)
        defer { nodeMap.dealloc() }
        guard let goalPoint = goal else {
            return []
        }

        return Array(sequence(first: goalPoint, next: { nodeMap[$0].previous })).reversed()
    }

    public func hasPathToGoal(pawn: Pawn) -> Bool {
        hasPathToGoal(from: pawn.point, goal: pawn.goal)
    }

    private var lastNodeMap: NodeMap?
    public func hasPathToGoal(from: PawnPoint, goal: GoalSide) -> Bool {
        if let nodeMap = lastNodeMap, nodeMap[from].visited {
            let checkY: Int32
            switch goal {
            case .minYEdge:
                checkY = 0
            case .maxYEdge:
                checkY = BoardState.height - 1
            }
            if (0..<BoardState.width).contains(where: { x -> Bool in
                nodeMap[PawnPoint(x: x, y: checkY)].visited
            }) {
                return true
            }
        }

        var nopGenerator = NotRandomGenerator()
        let (goal, nodeMap) = pathToGoal(from: from, goal: goal, generator: &nopGenerator)
        lastNodeMap?.dealloc()
        lastNodeMap = nodeMap
        return goal != nil
    }

    private func pathToGoal<T: RandomNumberGenerator>(
        from: PawnPoint,
        goal: GoalSide,
        generator: inout T
    ) -> (goalPoint: PawnPoint?, NodeMap) {
        let arounds: [PawnMove] = Bool.random(using: &generator)
            ? [.up, .down, .left, .right]
            : [.left, .right, .up, .down]

        var nodeMap = NodeMap()
        nodeMap[from].visited = true

        var queue: [PawnPoint] = []
        queue.reserveCapacity(30)
        queue.append(from)

        while !queue.isEmpty {
            let current = queue.removeFirst()

            for move in arounds {
                let nextPoint = move(current)
                guard BoardState.isInside(nextPoint) else { continue }
                if nodeMap[nextPoint].visited {
                    continue
                }
                if hasFence(from: current, move: move) { continue }

                if !nodeMap[nextPoint].visited {
                    nodeMap[nextPoint].visited = true
                    nodeMap[nextPoint].previous = current
                    if goal.inbound(p: nextPoint) {
                        return (nextPoint, nodeMap)
                    }
                    queue.append(nextPoint)
                }
            }
        }

        return (nil, nodeMap)
    }

    private func hasFence(from: PawnPoint, move: PawnMove) -> Bool {
        switch move {
        case .up:
            if let fence = fenceMap[from.x, from.y + 1], fence.orientation == .horizontal { return true }
            if let fence = fenceMap[from.x + 1, from.y + 1], fence.orientation == .horizontal { return true }
        case .down:
            if let fence = fenceMap[from.x, from.y], fence.orientation == .horizontal { return true }
            if let fence = fenceMap[from.x + 1, from.y], fence.orientation == .horizontal { return true }
        case .left:
            if let fence = fenceMap[from.x, from.y], fence.orientation == .vertical { return true }
            if let fence = fenceMap[from.x, from.y + 1], fence.orientation == .vertical { return true }
        case .right:
            if let fence = fenceMap[from.x + 1, from.y], fence.orientation == .vertical { return true }
            if let fence = fenceMap[from.x + 1, from.y + 1], fence.orientation == .vertical { return true }
        }
        return false
    }
}

private struct Node {
    var visited: Bool = false
    var previous: PawnPoint?
}

private struct NodeMap {
    private let nodes: UnsafeMutableBufferPointer<Node> = {
        let ptr = UnsafeMutableBufferPointer<Node>.allocate(capacity: Int(BoardState.width * BoardState.height))
        ptr.initialize(repeating: Node())
        return ptr
    }()
    subscript(p: PawnPoint) -> Node {
        get {
            nodes[Int(p.x + p.y * BoardState.width)]
        }
        _modify {
            yield &nodes[Int(p.x + p.y * BoardState.width)]
        }
    }

    func dealloc() {
        nodes.deallocate()
    }
}
