typealias DefaultRandomGenerator = Xoshiro256Generator

struct SplitMix64Generator: RandomNumberGenerator {
    private var state: UInt64

    init() {
        state = UInt64.random(in: UInt64.min...UInt64.max)
    }

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        self.state &+= 0x9e3779b97f4a7c15
        var z: UInt64 = self.state
        z = (z ^ (z &>> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z &>> 27)) &* 0x94d049bb133111eb
        return z ^ (z &>> 31)
    }
}

struct Xoshiro256Generator: RandomNumberGenerator {
    typealias State = (UInt64, UInt64, UInt64, UInt64)

    private var state: State

    init() {
        var seedGenerator = SystemRandomNumberGenerator()
        // > http://prng.di.unimi.it
        // > We suggest to use SplitMix64 to initialize the state of our generators starting from a 64-bit seed, as research has shown that initialization must be performed with a generator radically different in nature from the one initialized to avoid correlation on similar seeds.
        // とのことなので、64ビットのシードにはシステムを使い、そのシードからStateへの拡張にはSplitMix64を使う
        var stateGenerator = SplitMix64Generator(seed: seedGenerator.next())
        self.init(using: &stateGenerator)
    }

    init<T: RandomNumberGenerator>(using generator: inout T) {
        state = (
            generator.next(),
            generator.next(),
            generator.next(),
            generator.next()
        )
    }

    init(seed: State) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // Derived from domain implementation of xoshiro256** here:
        // http://xoshiro.di.unimi.it
        // by David Blackman and Sebastiano Vigna
        let x = state.1 &* 5
        let result = ((x &<< 7) | (x &>> 57)) &* 9
        let t = state.1 &<< 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3
        state.2 ^= t
        state.3 = (state.3 &<< 45) | (state.3 &>> 19)
        return result
    }
}

struct NotRandomGenerator: RandomNumberGenerator {
    mutating func next() -> UInt64 {
        return 1
    }
}
