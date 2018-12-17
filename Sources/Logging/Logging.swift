import Foundation

/// This is the protocol a custom logger implements.
public protocol LogHandler {
    // This is the custom logger implementation's log function. A user would not invoke this but rather go through
    // `Logger`'s `info`, `error`, or `warning` functions.
    //
    // An implementation does not need to check the log level because that has been done before by `Logger` itself.
    func log(level: LogLevel, message: String, file: String, function: String, line: UInt)

    // This adds metadata to a place the concrete logger considers appropriate. Some loggers
    // might not support this feature at all.
    subscript(metadataKey _: LoggingMetadata.Key) -> LoggingMetadata.Value? { get set }

    // All available metatdata
    var metadata: LoggingMetadata { get set } // removal of `?`, don't see the gain vs. using an empty map

    // The log level
    var logLevel: LogLevel { get set }
}

// This is the logger itself. It can either have value or reference semantics, depending on the `LogHandler`
// implementation.
public struct Logger {
    @usableFromInline
    var handler: LogHandler

    internal init(_ handler: LogHandler) {
        self.handler = handler
    }

    @inlinable
    func log(level: LogLevel, message: @autoclosure () -> String, file: String, function: String, line: UInt) {
        if self.logLevel <= level {
            self.handler.log(level: level, message: message(), file: file, function: function, line: line)
        }
    }

    @inlinable
    public func trace(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .trace, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public func debug(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .debug, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public func info(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .info, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public func warn(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .warn, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public func error(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: .error, message: message(), file: file, function: function, line: line)
    }

    @inlinable
    public subscript(metadataKey metadataKey: LoggingMetadata.Key) -> LoggingMetadata.Value? {
        get {
            return self.handler[metadataKey: metadataKey]
        }
        set {
            self.handler[metadataKey: metadataKey] = newValue
        }
    }

    @inlinable
    public var metadata: LoggingMetadata {
        get {
            return self.handler.metadata
        }
        set {
            self.handler.metadata = newValue
        }
    }

    @inlinable
    public var logLevel: LogLevel {
        get {
            return self.handler.logLevel
        }
        set {
            self.handler.logLevel = newValue
        }
    }
}

public extension Logger {
    public func withMetadata(_ additionalMetadata: @escaping @autoclosure () -> LoggingMetadata, _ block: (Logger) -> Void) {
        let l = Logger(ProxyLogHandler(underlying: self.handler, additionalMetadata: additionalMetadata))

        return block(l)
    }
}

public enum LogLevel: Int {
    case trace
    case debug
    case info
    case warn
    case error
}

// logging with String value, "before"
//    measuring: 100 logs:
//    // [some-id][2018-12-17 10:26:41 +0000][info][id=some-id trace=0-AF7651916CD43DD8448EB211C80319C-F067AA0BA902B7-0 per-data0=some-metadata additional=some-per-context-info] Hello 100
//    7ms 655μs, 7ms 50μs, 6ms 155μs, 5ms 825μs, 21ms 72μs, 6ms 314μs, 6ms 96μs, 10ms 315μs, 5ms 653μs, 7ms 46μs,
//    measuring: no 100 logs:
//    1ms 223μs, 1ms 295μs, 1ms 260μs, 1ms 340μs, 1ms 386μs, 1ms 419μs, 1ms 525μs, 1ms 476μs, 1ms 482μs, 1ms 608μs,
//
// String:String, with didSet rendering
//    measuring: 100 logs:
//    // 2018-12-17 11:35:49 +0000 id=some-id additional=some-per-context-info per-data0=some-metadata trace=0-AF7651916CD43DD8448EB211C80319C-F067AA0BA902B7-0 Hello 100
//    10ms 915μs, 6ms 531μs, 6ms 68μs, 5ms 735μs, 5ms 870μs, 9ms 493μs, 6ms 564μs, 7ms 400μs, 10ms 455μs, 7ms 205μs,
//    measuring: no 10000 logs:
//    1ms 643μs, 1ms 592μs, 1ms 671μs, 1ms 579μs, 1ms 602μs, 1ms 565μs, 1ms 560μs, 1ms 539μs, 1ms 510μs, 1ms 499μs,
//
// String:Any, avoiding didSet, rendering only when actually printing
//    measuring: 100 logs:
//    // [2018-12-17 12:04:45 +0000][info][additional=some-per-context-info trace=0-AF7651916CD43DD8448EB211C80319C-F067AA0BA902B7-0 per-data0=some-metadata id=some-id] Hello 100
//    20ms 89μs, 6ms 877μs, 8ms 257μs, 10ms 628μs, 6ms 299μs, 5ms 718μs, 5ms 723μs, 5ms 362μs, 8ms 759μs, 6ms 155μs,
//    measuring: no 10000 logs:
//    675μs 82ns, 394μs 940ns, 393μs 986ns, 393μs 986ns, 393μs 986ns, 394μs 940ns, 395μs 59ns, 394μs 940ns, 395μs 59ns, 486μs 16ns,
public typealias LoggingMetadata = [String: Any]
// public typealias LoggingMetadata = [String: String]

extension LogLevel: Comparable {
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// This is the logging system itself, it's mostly used to obtain loggers and to set the type of the `LogHandler`
// implementation.
public enum Logging {
    private static let lock = NSLock()
    private static var _factory: (String) -> LogHandler = StdoutLogger.init

    // Configures which `LogHandler` to use in the application.
    public static func bootstrap(_ factory: @escaping (String) -> LogHandler) {
        self.lock.withLock {
            self._factory = factory
        }
    }

    // TODO: make sounds a bit off, `Logging.get()`
    public static func make(_ label: String) -> Logger {
        return self.lock.withLock { Logger(self._factory(label)) }
    }
}

/// Ships with the logging module, really boring just prints something using the `print` function
public final class StdoutLogger: LogHandler {
    private let lock = NSLock()

    private let label: String

    public init(label: String) {
        self.label = label
        self._metadata = LoggingMetadata()
    }

    private var _logLevel: LogLevel = .info
    public var logLevel: LogLevel {
        get {
            return self.lock.withLock { self._logLevel }
        }
        set {
            self.lock.withLock {
                self._logLevel = newValue
            }
        }
    }

    private var _metadata: LoggingMetadata
    public func log(level: LogLevel, message: String, file _: String, function _: String, line _: UInt) {
        if level >= self.logLevel {
            let prettyMetadata = !(self._metadata.isEmpty) ? self._metadata.map { "\($0)=\($1)" }.joined(separator: " ") : ""
            print("[\(Date())][\(level)][\(prettyMetadata)] \(message)")
        }
    }

    public var metadata: LoggingMetadata {
        get {
            return self.lock.withLock { self._metadata }
        }
        set {
            self.lock.withLock { self._metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: LoggingMetadata.Key) -> LoggingMetadata.Value? {
        get {
            return self.lock.withLock { self._metadata[metadataKey] }
        }
        set {
            self.lock.withLock {
                self._metadata[metadataKey] = newValue
            }
        }
    }
}

final class ProxyLogHandler: LogHandler {
    private var underlying: LogHandler
    private let additionalMetadata: () -> LoggingMetadata

    init(underlying: LogHandler, additionalMetadata: @escaping @autoclosure () -> LoggingMetadata) {
        self.underlying = underlying
        self.additionalMetadata = additionalMetadata
    }

    func log(level: LogLevel, message: String, file: String, function: String, line: UInt) {
        if level >= self.logLevel {
            self.underlying.metadata = self.additionalMetadata()
            self.underlying.log(level: level, message: message, file: file, function: function, line: line)
        }
    }

    private var _logLevel: LogLevel = .info
    public var logLevel: LogLevel {
        get {
            return self.underlying.logLevel
        }
        set {
            self.underlying.logLevel = newValue
        }
    }

    public var metadata: LoggingMetadata {
        get {
            return self.underlying.metadata
        }
        set {
            self.underlying.self.metadata = newValue
        }
    }

    public subscript(metadataKey metadataKey: LoggingMetadata.Key) -> LoggingMetadata.Value? {
        get {
            return self.underlying.metadata[metadataKey]
        }
        set {
            self.underlying.metadata[metadataKey] = newValue
        }
    }
}


private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return body()
    }
}
