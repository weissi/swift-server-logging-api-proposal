//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// This is the logging system itself, it's mostly used to obtain loggers and to set the type of the `LogHandler`
// implementation.
public enum Logging {
    private static let lock = ReadWriteLock()
    private static var factory: (String) -> LogHandler = StdoutLogHandler.init

    // Configures which `LogHandler` to use in the application.
    public static func bootstrap(_ factory: @escaping (String) -> LogHandler) {
        self.lock.withWriterLock {
            self.factory = factory
        }
    }

    public static func make(_ label: String) -> Logger {
        return self.lock.withReaderLock {
            Logger(self.factory(label))
        }
    }
}

// MARK: Log levels

extension Logging {
    public enum Level: Int {
        case trace
        case debug
        case info
        case warning
        case error
    }
}

extension Logging.Level: Comparable {
    public static func < (lhs: Logging.Level, rhs: Logging.Level) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: Metadata

extension Logging {
    public typealias Metadata = [String: MetadataValue]

    public enum MetadataValue {
        case string(String)
        case dictionary(Metadata)
        case array([Metadata.Value])
    }
}

extension Logging.Metadata.Value: Equatable {}

extension Logging.Metadata.Value: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension Logging.Metadata.Value: ExpressibleByStringInterpolation {
    #if !swift(>=5.0)
        public init(stringInterpolation strings: Logging.Metadata.Value...) {
            self = .string(strings.map { $0.description }.reduce("", +))
        }

        public init<T>(stringInterpolationSegment expr: T) {
            self = .string(String(stringInterpolationSegment: expr))
        }
    #endif
}

extension Logging.Metadata.Value: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = Logging.Metadata.Value

    public init(dictionaryLiteral elements: (String, Logging.Metadata.Value)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements))
    }
}

extension Logging.Metadata.Value: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Logging.Metadata.Value

    public init(arrayLiteral elements: Logging.Metadata.Value...) {
        self = .array(elements)
    }
}

extension Logging.Metadata.Value: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dictionary(let dict):
            return dict.mapValues { $0.description }.description
        case .array(let list):
            return list.map { $0.description }.description
        case .string(let str):
            return str
        }
    }
}
