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

/// Ships with the logging module, used to multiplex to multiple logging handlers
public final class MultiplexLogging {
    private let factories: [(String) -> LogHandler]

    public init(_ factories: [(String) -> LogHandler]) {
        self.factories = factories
    }

    public func make(label: String) -> LogHandler {
        return MultiplexLogHandler(handlers: self.factories.map { $0(label) })
    }
}
