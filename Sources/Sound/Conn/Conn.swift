//
// Created by Griffin Byatt on 8/27/18.
//

import NIO
import NIOHTTP1
import Foundation

open class Conn {
    public var reqHead: HTTPRequestHead
    public var path: Path
    public var reqBody: String?

    private let methodOverrides: [String:HTTPMethod] = ["PATCH": .PATCH, "PUT": .PUT, "DELETE": .DELETE]

    public var method: HTTPMethod {
        let m = reqHead.method

        switch m {
        case .POST:
            if let bodyParam = bodyParams["_method"] {
                return methodOverrides[bodyParam] ?? .POST
            } else {
                return .POST
            }
        default:
            return m
        }
    }
    public var uri: String {
        return reqHead.uri
    }
    public var version: HTTPVersion {
        return reqHead.version
    }
    public var reqHeaders: HTTPHeaders {
        return reqHead.headers
    }

    public var pathParams = [String:String]()
    public var bodyParams = [String:String]()
    public var queryParams = [String:String]()

    // Technically would probably be better as a function b/c it is not O(1).
    // The API feels nicer this way though.
    public var params: [String:String] {
        if self.method == .GET {
            return pathParams.merging(queryParams) { (current, _) in current }
        } else {
            return pathParams
                    .merging(bodyParams) { (current, _) in current }
                    .merging(queryParams) { (current, _) in current }
        }
    }

    // Response data
    public var respHead = HTTPResponseHead(version: HTTPVersion(major:1, minor:1), status: .ok)
    public var respHeaders: HTTPHeaders {
        return respHead.headers
    }
    public var respBody: String?
    public var respStatus: HTTPResponseStatus {
        get {
            return respHead.status
        }
        set {
            respHead.status = newValue
        }
    }

    public func addHeader(name: String, value: String) throws {
        guard !name.utf8.contains(where: {$0 > 127}) else {
            throw ConnError.argumentError("Name must be ASCII.")
        }

        guard !name.contains(where: {$0 == ":" || $0 == "\r" || $0 == "\n"}) else {
            throw ConnError.argumentError("Name must not contain ':', '\r', or '\n' characters.")
        }

        guard !value.contains("\r"), !value.contains("\n") else {
            throw ConnError.argumentError("Value must not contain '\r' or '\n' characters.")
        }

        respHead.headers.replaceOrAdd(name: name, value: value)
    }

    func setBody(_ body: ByteBuffer) {
        var reqBody = body
        let contentType = self.reqHeaders["Content-Type"]

        guard contentType.count == 1 else {
            return
        }
        self.reqBody = reqBody.readString(length: body.readableBytes)

        guard self.reqBody != nil else {
            return
        }
        if contentType[0] == "application/x-www-form-urlencoded" {
            self.bodyParams = decodeQueryParams(self.reqBody)
        }
    }

    private func decodeQueryParams<T>(_ query: T?) -> [String:String] where T: StringProtocol {
        var queryParams = [String:String]()

        guard query != nil else {
            return queryParams
        }

        guard let query = String(query!).removingPercentEncoding else {
            return queryParams
        }

        query.split(separator: "&").forEach { queryParam in
            var params = queryParam.split(separator: "=", maxSplits: 1).map { q in String(q) }
            queryParams[params.removeFirst()] = params.popLast()
        }

        return queryParams
    }

    private let app: Sound?
    private let fileIO: NonBlockingFileIO?
    private let ctx: ChannelHandlerContext?
    public var channel: Channel?
    public var state: ConnState = .idle

    public func text(status: HTTPResponseStatus = .ok, _ text: String) {
        try? self.addHeader(name: "Content-Type", value: "text/plain; charset=utf-8")
        self.respStatus = status
        self.respBody = text
    }

    public func html(status: HTTPResponseStatus = .ok, _ html: String) {
        try? self.addHeader(name: "Content-Type", value: "text/html; charset=utf-8")
        self.respStatus = status
        self.respBody = html
    }

    public func render(_ template: String, with vars: [String:String] = [String:String]()) {
        guard let template = app!.templates[template + ".tmpl"] else {
            return app!.serverError(self, [:])
        }

        let html = template.rendering(with: vars)
        return self.html(html)
    }

    public func sendFile(status: HTTPResponseStatus = .ok, _ path: String, safe: Bool = true) {
        self.state = .busy

        var ok = true
        var fileURL = path

        if safe {
            let publicDirectory = FileManager.default.currentDirectoryPath + "/public/"
            fileURL = URL(string: path)?.standardizedFileURL.absoluteString ?? ""
            ok = fileURL.hasPrefix(publicDirectory)
        }

        guard ok, !path.hasSuffix("."), !path.hasSuffix("/") else {
            self.app!.notFound(self, [:])
            self.writeResp(forceIdle: true)
            return
        }

        self.respStatus = status
        let fileHandleAndRegion = self.fileIO!.openFile(path: path, eventLoop: ctx!.eventLoop)

        fileHandleAndRegion.whenFailure { _ in
            self.app!.notFound(self, [:])
            self.writeResp(forceIdle: true)
        }

        fileHandleAndRegion.whenSuccess { (file, region) in
            self.writeRespToChannel(.fileRegion(region)).whenComplete {
                _ = try? file.close()
            }
        }
    }

    func writeResp(forceIdle: Bool = false) {
        guard (state != .busy || forceIdle) else {
            return
        }

        guard let respBody = self.respBody else {
            app!.serverError(self, [:])
            writeResp()
            return
        }

        var buffer = channel!.allocator.buffer(capacity: respBody.count)
        buffer.write(string: respBody)

        _ = writeRespToChannel(.byteBuffer(buffer))
    }

    private func writeRespToChannel(_ body: IOData) -> EventLoopFuture<Void> {
        let part = HTTPServerResponsePart.head(respHead)
        _ = channel!.write(part)

        let body = HTTPServerResponsePart.body(body)
        _ = channel!.write(body)

        let end = HTTPServerResponsePart.end(nil)
        return channel!.writeAndFlush(end).then {
            self.channel!.close()
        }
    }

    init(app: Sound? = nil, ctx: ChannelHandlerContext? = nil, fileIO: NonBlockingFileIO? = nil, reqHead: HTTPRequestHead) {
        self.app = app
        self.ctx = ctx
        self.channel = ctx?.channel
        self.fileIO = fileIO

        self.reqHead = reqHead
        var uriParts = reqHead.uri.split(separator: "?", maxSplits: 1)
        self.path = Path(String(uriParts.removeFirst()))
        self.queryParams = decodeQueryParams(uriParts.popLast())
    }
}

enum ConnError: Error {
    case argumentError(String)
}

public enum ConnState {
    case idle
    case busy
    case halted
}