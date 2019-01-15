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

internal final class MultiplexLogHandler: LogHandler {
    private let lock = Lock()
    private var handlers: [LogHandler]

    public init(handlers: [LogHandler]) {
        assert(handlers.count > 0)
        self.handlers = handlers
    }

    public var logLevel: Logging.Level {
        get {
            return self.handlers[0].logLevel
        }
        set {
            self.mutateHandlers {
                $0.logLevel = newValue
            }
        }
    }

    public func log(level: Logging.Level, message: String, metadata: Logging.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt) {
        self.handlers.forEach { handler in
            handler.log(level: level, message: message, metadata: metadata, error: error, file: file, function: function, line: line)
        }
    }

    public var metadata: Logging.Metadata {
        get {
            return self.handlers[0].metadata
        }
        set {
            self.mutateHandlers {
                $0.metadata = newValue
            }
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logging.Metadata.Value? {
        get {
            return self.handlers[0].metadata[metadataKey]
        }
        set {
            self.mutateHandlers {
                $0[metadataKey: metadataKey] = newValue
            }
        }
    }

    private func mutateHandlers(mutator: (inout LogHandler) -> Void) {
        var newHandlers = [LogHandler]()
        self.handlers.forEach {
            var handler = $0
            mutator(&handler)
            newHandlers.append(handler)
        }
        self.lock.withLock {
            self.handlers = newHandlers
        }
    }
}
