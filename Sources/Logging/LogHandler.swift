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

/// This is the protocol a custom logger implements.
public protocol LogHandler {
    // This is the custom logger implementation's log function. A user would not invoke this but rather go through
    // `Logger`'s `info`, `error`, or `warning` functions.
    //
    // An implementation does not need to check the log level because that has been done before by `Logger` itself.
    func log(level: Logging.Level, message: String, metadata: Logging.Metadata?, error: Error?, file: StaticString, function: StaticString, line: UInt)

    // This adds metadata to a place the concrete logger considers appropriate. Some loggers
    // might not support this feature at all.
    subscript(metadataKey _: String) -> Logging.Metadata.Value? { get set }

    // All available metadata
    var metadata: Logging.Metadata { get set }

    // The log level
    var logLevel: Logging.Level { get set }
}
