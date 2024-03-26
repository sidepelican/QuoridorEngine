extension Collection {
    func randomElementForSmall<T: RandomNumberGenerator>(using generator: inout T) -> Element? {
        if count <= 1 {
            return first
        }

        return randomElement(using: &generator)
    }

    func unsafeRandomElement<T: RandomNumberGenerator>(using generator: inout T) -> Element {
        let random = Int.random(in: 0 ..< count, using: &generator)
        let idx = index(startIndex, offsetBy: random)
        return self[idx]
    }
}

extension Array where Element: Equatable {
    func uniqued() -> [Element] {
        var ret: [Element] = []
        for newElement in self {
            if !ret.contains(newElement) {
                ret.append(newElement)
            }
        }
        return ret
    }
}
