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

// This is the logger itself. It can either have value or reference semantics, depending on the `LogHandler`
// implementation.
public struct Logger {
    @usableFromInline
    var handler: LogHandler

    internal init(_ handler: LogHandler) {
        self.handler = handler
    }

    @inlinable
    func log(level: Logging.Level, message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        if self.logLevel <= level {
            self.handler.log(level: level, message: message(), metadata: metadata(), error: error, file: file, function: function, line: line)
        }
    }

    @inlinable
    public func trace(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .trace, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public func debug(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .debug, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public func info(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .info, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public func warning(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .warning, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public func error(_ message: @autoclosure () -> String, metadata: @autoclosure () -> Logging.Metadata? = nil, error: Error? = nil, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        self.log(level: .error, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
    }

    @inlinable
    public subscript(metadataKey metadataKey: String) -> Logging.Metadata.Value? {
        get {
            return self.handler[metadataKey: metadataKey]
        }
        set {
            self.handler[metadataKey: metadataKey] = newValue
        }
    }

    @inlinable
    public var metadata: Logging.Metadata {
        get {
            return self.handler.metadata
        }
        set {
            self.handler.metadata = newValue
        }
    }

    @inlinable
    public var logLevel: Logging.Level {
        get {
            return self.handler.logLevel
        }
        set {
            self.handler.logLevel = newValue
        }
    }
}
