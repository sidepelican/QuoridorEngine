extension BoardState {
    public func dump(withRoute routes: [PawnPoint] = []) {
        var buf = ""
        buf += pawns.map { "\($0.id): \($0.fencesLeft)" }.joined(separator: ", ") + "\n"
        for y in (0..<Self.height).reversed() {
            for x in 0..<Self.width {
                let p = PawnPoint(x: x, y: y)
                if let pawn = pawns.first(where: { $0.point == p }) {
                    buf += "[\(pawn.id)]"
                } else if routes.contains(p) {
                    if routes.first == p {
                        buf += "[s]"
                    } else {
                        buf += "[.]"
                    }
                } else {
                    buf += "[ ]"
                }
                if existsFence(between: .init(x: x, y: y), two: .init(x: x + 1, y: y)) {
                    buf += "|"
                } else {
                    buf += " "
                }
            }
            buf += "\(y)\n"
            if y != 0 {
                for x in 0..<Self.width {
                    let yokoExists = existsFence(between: .init(x: x, y: y), two: .init(x: x, y: y - 1))
                    let tateExists = existsFence(between: .init(x: x, y: y), two: .init(x: x + 1, y: y))
                    if yokoExists {
                        buf += "==="
                    } else {
                        buf += "   "
                    }
                    if tateExists {
                        buf += "|"
                    } else {
                        buf += " "
                    }
                }
                buf += "\n"
            }
        }
        for x in 0..<Self.width {
            buf += " \(x)  "
        }
        print(buf)
    }
}
