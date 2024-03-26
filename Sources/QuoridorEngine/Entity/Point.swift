#if canImport(simd)
import simd
#endif

public typealias PawnPoint = SwiftPawnPoint

public struct FencePoint: Equatable {
    public var x, y: Int32
    public init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }
}

public struct SwiftPawnPoint: Equatable, CustomDebugStringConvertible {
    public var x: Int32
    public var y: Int32

    public init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }

    @inlinable
    public func manhattan(to: Self) -> Int32 {
        abs(x - to.x) + abs(y - to.y) 
    }

    @inlinable
    public static func +(lhs: Self, rhs: Self) -> Self {
        return Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    @inlinable
    public static func -(lhs: Self, rhs: Self) -> Self {
        return Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public var debugDescription: String {
        "(\(x),\(y))"
    }
}

#if canImport(simd)
public struct SimdPawnPoint: Equatable, CustomDebugStringConvertible {
    public var x: Int32 {
        v.x
    }
    public var y: Int32 {
        v.y
    }

    public var v: vector_int2

    public init(v: vector_int2) {
        self.v = v
    }

    public init(x: Int32, y: Int32) {
        self.v = .init(x: x, y: y)
    }

    @inlinable
    public func manhattan(to: Self) -> Int32 {
        abs(v &- to.v).wrappedSum()
    }

    @inlinable
    public static func +(lhs: Self, rhs: Self) -> Self {
        return Self(v: lhs.v &+ rhs.v)
    }

    @inlinable
    public static func -(lhs: Self, rhs: Self) -> Self {
        return Self(v: lhs.v &- rhs.v)
    }

    public var debugDescription: String {
        "(\(x),\(y))"
    }
}

extension vector_int2 {
    init(_ p: PawnPoint) {
        self.init(x: p.x, y: p.y)
    }

    init(_ p: FencePoint) {
        self.init(x: p.x, y: p.y)
    }
}
#endif
