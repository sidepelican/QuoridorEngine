public struct PlayerID: Hashable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
    var value: String

    public init(stringLiteral value: StringLiteralType) {
        self.value = value
    }

    public init(stringInterpolation: DefaultStringInterpolation) {
        value = stringInterpolation.description
    }

    public var description: String { value }
}
