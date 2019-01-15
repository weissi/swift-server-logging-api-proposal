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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    import Darwin
#else
    import Glibc
#endif

/// Ships with the logging module, really boring just prints something using the `print` function
internal final class StdoutLogHandler: LogHandler {
    private let lock = Lock()

    public init(label: String) {}

    private var _logLevel: Logging.Level = .info
    public var logLevel: Logging.Level {
        get {
            return self.lock.withLock { self._logLevel }
        }
        set {
            self.lock.withLock {
                self._logLevel = newValue
            }
        }
    }

    private var prettyMetadata: String?
    private var _metadata = Logging.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self._metadata)
        }
    }

    public func log(level: Logging.Level, message: String, metadata: Logging.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true ? self.prettyMetadata : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))
        print("\(self.timestamp()) \(level)\(prettyMetadata.map { " \($0)" } ?? "") \(message)\(error.map { " \($0)" } ?? "")")
    }

    public var metadata: Logging.Metadata {
        get {
            return self.lock.withLock { self._metadata }
        }
        set {
            self.lock.withLock { self._metadata = newValue }
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logging.Metadata.Value? {
        get {
            return self.lock.withLock { self._metadata[metadataKey] }
        }
        set {
            self.lock.withLock {
                self._metadata[metadataKey] = newValue
            }
        }
    }

    private func prettify(_ metadata: Logging.Metadata) -> String? {
        return !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        var timestamp = time(nil)
        let localTime = localtime(&timestamp)
        strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
        return buffer.map { UInt8($0) }.withUnsafeBufferPointer { ptr in
            String.decodeCString(ptr.baseAddress, as: UTF8.self, repairingInvalidCodeUnits: true)
            }?.0 ?? "\(timestamp)"
    }
}
