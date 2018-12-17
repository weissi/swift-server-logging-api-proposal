import Foundation
import Logging

// MARK: Example library code

struct DataContainer {
    let data: String // this would be some user `T` type

    // would be W3C's `traceparent` for example
    let traceContext: TraceContext?
}


// there's a few ways to specify those, this is just an example;
//
// See others: https://github.com/opentracing/specification/blob/master/rfc/trace_identifiers.md
// Though this one is going to be the standardized one soon: https://w3c.github.io/trace-context/
struct TraceContext {
    let version: UInt8
    let traceId: (UInt64, UInt64) // one value in 128 bits
    let parentId: UInt64
    let flags: UInt8
}

extension TraceContext: CustomStringConvertible {
    public var description: String {
        let v = String(self.version, radix: 16, uppercase: true)
        let t1 = String(self.traceId.0, radix: 16, uppercase: true)
        let t2 = String(self.traceId.1, radix: 16, uppercase: true)
        let s = String(self.parentId, radix: 16, uppercase: true)
        let f = String(self.flags, radix: 16, uppercase: true)

        // rendering just an example, did not super closely follow any spec, but close enough:
        return "\(v)-\(t1)\(t2)-\(s)-\(f)"
    }
}

struct SomeContext {
    let id: String
    var log: Logger
}

class Library {

    // somewhere in library, per context
    // imagine we initialize it safely somewhere, always once,
    // it has the right context metadata (e.g. the above id), which remains the same for the lifetime of this context
    // but also we need to set things on it per invocation
    private var log: Logger

    // pseudo structure
    private var context: SomeContext

    init() {
        let id = "some-id"
        // assume we know the context id here:
        var log = Logging.make(id)
        log.metadata = ["id": "\(id)"]
        log.metadata["additional"] = "some-per-context-info" // could require "rendering into a string"

        self.log = log

        let context: SomeContext = SomeContext(id: id, log: self.log)
        self.context = context
    }

    private func extractMeta(from envelope: DataContainer, withBase metadata: LoggingMetadata) -> LoggingMetadata {
        var renderedMetadata: LoggingMetadata = [:]

        switch envelope.traceContext {
        case .some(let trace):
            renderedMetadata = [
                "per-data0": "some-metadata",
                "trace": trace // by allowing Any as value, we delay the rendering operation
            ]
        case .none:
            renderedMetadata = [
                "per-data0": "some-metadata",
            ]

        }

        return renderedMetadata
    }

    func handle(userCallback: (inout SomeContext, DataContainer) -> ()) {
        let perContextMetadata: LoggingMetadata = context.log.metadata

        let trace = TraceContext( // assume we have it, it came with the container
            version: 0,
            traceId: (790211418057950173, 9532127138774266268),
            parentId: 67667974448284343,
            flags: 0
        )
        let data = DataContainer(data: "example", traceContext: trace)

        let moreMetadata = extractMeta(from: data, withBase: perContextMetadata)
        var allMetadata: LoggingMetadata = perContextMetadata
        allMetadata.merge(moreMetadata, uniquingKeysWith: { (l, r) in r })

        context.log.metadata = allMetadata
        defer { context.log.metadata = perContextMetadata }

        // invoke user code, which may or may not log; if expensive to render metadata is logged we don't pay the price for it
        userCallback(&context, data)
    }
}

struct ExploringPerformanceExample {


    func main() {
        let outerLogger = Logging.make("outer")

        let library = Library()

        measureAndPrint(desc: "set one metadata") {
            library.handle { context, data in
                context.log.metadata["only-once"] = "ONLY_1"
                context.log.info("Hello")
            }

        }

        measureAndPrint(desc: "set 10 metadata") {
            library.handle { context, data in
                context.log.metadata["only-1"] = "ONLY"
                context.log.metadata["only-2"] = "ONLY"
                context.log.metadata["only-3"] = "ONLY"
                context.log.metadata["only-4"] = "ONLY"
                context.log.metadata["only-5"] = "ONLY"
                context.log.metadata["only-6"] = "ONLY"
                context.log.metadata["only-7"] = "ONLY"
                context.log.metadata["only-8"] = "ONLY"
                context.log.metadata["only-9"] = "ONLY"
                context.log.metadata["only-10"] = "ONLY"
                context.log.info("Hello")
            }
        }

        let traceExample = TraceContext(
            version: 0,
            traceId: (790211418057950173, 9532127138774266268),
            parentId: 67667974448284343,
            flags: 0
        )
        measureAndPrint(desc: "rendering traces") {
            let rendered = "\(traceExample)"
            print("rendered: \(rendered)")
        }

        measureAndPrint(desc: "only context metadata, no additional") {
            library.handle { context, data in
                // should not have the [exactly-once] logged
                context.log.info("Hello Second Time")
            }
        }

        measureAndPrint(desc: "user callback not logging at all") {
            library.handle { context, data in
                return () // no logging == should be no cost of rendering reprs
            }
        }

        measureAndPrint(desc: "override context value") {
            library.handle { context, data in
                // overrides value of "additional" for only this log statement
                context.log.metadata["additional"] = "OVERRIDDEN"
                context.log.info("Hello Second Time")
            }
        }

        measureAndPrint(desc: "100 logs") {
            for item in 0...100 {
                library.handle { context, data in
                    context.log.info("Hello \(item)")
                }
            }
        }
        measureAndPrint(desc: "no 10000 logs") {
            for _ in 0...100 {
                library.handle { context, data in
                    return () // no logging == no overhead from "rendering" some metadata
                }
            }
        }

        measureAndPrint(desc: "no context") {
            outerLogger.info("Example logging")
        }

        measureAndPrint(desc: "example") {
            outerLogger.withMetadata(["hello": "helloooooooo!"]) { scoped in
                scoped.info("EXAMPLE??????")
            }
        }

        /*
        [some-id][2018-12-17 05:50:14 +0000][info][only-once=ONLY_1 per-data=some-metadata id=some-id additional=some-per-context-info] Hello
        [some-id][2018-12-17 05:50:14 +0000][info][id=some-id per-data=some-metadata additional=some-per-context-info] Hello Second Time
        [some-id][2018-12-17 05:50:14 +0000][info][id=some-id per-data=some-metadata additional=OVERRIDDEN] Hello Second Time
        [other][2018-12-17 05:50:14 +0000][info][] Example logging
        [other][2018-12-17 05:50:14 +0000][info][] Example logging
        */
    }

}
