import Foundation
import Logging

/// Copied from NIO
public struct TimeAmount {

    #if arch(arm) || arch(i386)
    // Int64 is the correct type here but we don't want to break SemVer so can't change it for the 64-bit platforms.
    // To be fixed in NIO 2.0
    public typealias Value = Int64
    #else
    // 64-bit, keeping that at Int for SemVer in the 1.x line.
    public typealias Value = Int
    #endif

    /// The nanoseconds representation of the `TimeAmount`.
    public let nanoseconds: Value

    private init(_ nanoseconds: Value) {
        self.nanoseconds = nanoseconds
    }

    /// Creates a new `TimeAmount` for the given amount of nanoseconds.
    ///
    /// - parameters:
    ///     - amount: the amount of nanoseconds this `TimeAmount` represents.
    /// - returns: the `TimeAmount` for the given amount.
    public static func nanoseconds(_ amount: Value) -> TimeAmount {
        return TimeAmount(amount)
    }

    /// Creates a new `TimeAmount` for the given amount of microseconds.
    ///
    /// - parameters:
    ///     - amount: the amount of microseconds this `TimeAmount` represents.
    /// - returns: the `TimeAmount` for the given amount.
    public static func microseconds(_ amount: Value) -> TimeAmount {
        return TimeAmount(amount * 1000)
    }

    /// Creates a new `TimeAmount` for the given amount of milliseconds.
    ///
    /// - parameters:
    ///     - amount: the amount of milliseconds this `TimeAmount` represents.
    /// - returns: the `TimeAmount` for the given amount.
    public static func milliseconds(_ amount: Value) -> TimeAmount {
        return TimeAmount(amount * 1000 * 1000)
    }

    /// Creates a new `TimeAmount` for the given amount of seconds.
    ///
    /// - parameters:
    ///     - amount: the amount of seconds this `TimeAmount` represents.
    /// - returns: the `TimeAmount` for the given amount.
    public static func seconds(_ amount: Value) -> TimeAmount {
        return TimeAmount(amount * 1000 * 1000 * 1000)
    }

    /// Creates a new `TimeAmount` for the given amount of minutes.
    ///
    /// - parameters:
    ///     - amount: the amount of minutes this `TimeAmount` represents.
    /// - returns: the `TimeAmount` for the given amount.
    public static func minutes(_ amount: Value) -> TimeAmount {
        return TimeAmount(amount * 1000 * 1000 * 1000 * 60)
    }

    /// Creates a new `TimeAmount` for the given amount of hours.
    ///
    /// - parameters:
    ///     - amount: the amount of hours this `TimeAmount` represents.
    /// - returns: the `TimeAmount` for the given amount.
    public static func hours(_ amount: Value) -> TimeAmount {
        return TimeAmount(amount * 1000 * 1000 * 1000 * 60 * 60)
    }
}

/// "Pretty" time amount rendering, useful for human readable durations in tests
extension TimeAmount {
    // TODO build our own rather than extending the NIO one

    public var prettyDescription: String {
        return self.prettyDescription()
    }

    public func prettyDescription(precision: Int = 2) -> String {
        assert(precision > 0, "precision MUST BE > 0")
        var res = ""

        var remaining = self
        var i = 0
        while i < precision {
            let unit = chooseUnit(remaining.nanoseconds)

            let rounded: Int = remaining.nanoseconds / unit.rawValue
            if rounded > 0 {
                res += i > 0 ? " " : ""
                res += "\(rounded)\(unit.abbreviated)"

                remaining = TimeAmount.nanoseconds(remaining.nanoseconds - unit.timeAmount(rounded).nanoseconds)
                i += 1
            } else {
                break
            }
        }

        return res
    }

    private func chooseUnit(_ ns: Value) -> TimeUnit {
        //@formatter:off
        if ns / TimeUnit.days.rawValue > 0 {
            return TimeUnit.days
        } else if ns / TimeUnit.hours.rawValue > 0 {
            return TimeUnit.hours
        } else if ns / TimeUnit.minutes.rawValue > 0 {
            return TimeUnit.minutes
        } else if ns / TimeUnit.seconds.rawValue > 0 {
            return TimeUnit.seconds
        } else if ns / TimeUnit.milliseconds.rawValue > 0 {
            return TimeUnit.milliseconds
        } else if ns / TimeUnit.microseconds.rawValue > 0 {
            return TimeUnit.microseconds
        } else {
            return TimeUnit.nanoseconds
        }
        //@formatter:on
    }

    /// Represents number of nanoseconds within given time unit
    enum TimeUnit: Value {
        //@formatter:off
        case days = 86_400_000_000_000
        case hours = 3_600_000_000_000
        case minutes = 60_000_000_000
        case seconds = 1_000_000_000
        case milliseconds = 1_000_000
        case microseconds = 1_000
        case nanoseconds = 1
        //@formatter:on

        var abbreviated: String {
            switch self {
            case .nanoseconds: return "ns"
            case .microseconds: return "μs"
            case .milliseconds: return "ms"
            case .seconds: return "s"
            case .minutes: return "m"
            case .hours: return "h"
            case .days: return "d"
            }
        }

        func timeAmount(_ amount: Int) -> TimeAmount {
            switch self {
            case .nanoseconds: return .nanoseconds(amount)
            case .microseconds: return .microseconds(amount)
            case .milliseconds: return .milliseconds(amount)
            case .seconds: return .seconds(amount)
            case .minutes: return .minutes(amount)
            case .hours: return .hours(amount)
            case .days: return .hours(amount * 24)
            }
        }

    }
}

////// toy benchmark infra

public func measure(_ fn: () throws -> Void) rethrows -> [TimeInterval] {
    func measureOne(_ fn: () throws -> Void) rethrows -> TimeInterval {
        let start = Date()
        _ = try fn()
        let end = Date()
        return end.timeIntervalSince(start)
    }

    _ = try measureOne(fn) /* pre-heat and throw away */
    var measurements = Array(repeating: 0.0, count: 10)
    for i in 0..<10 {
        measurements[i] = try measureOne(fn)
    }
    return measurements
}

public func measureAndPrint(desc: String, fn: () throws -> Void) rethrows -> Void {
    print("measuring: \(desc): ")
    let measurements = try measure(fn)

    print(measurements.reduce("") { (acc, m: TimeInterval) in
        let prettyMeasurement = TimeAmount.nanoseconds(TimeAmount.Value(m * 1_000_000_000))
        return acc + "\(prettyMeasurement.prettyDescription), "
    })
}

////// end of toy benchmark infra
