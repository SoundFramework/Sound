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
    public var layout_template: String?

    private let methodOverrides: [String:HTTPMethod] = ["PATCH": .PATCH, "PUT": .PUT, "DELETE": .DELETE]

    public var method: HTTPMethod {
        let m = reqHead.method

        switch m {
        case .POST:
            if let bodyParam = bodyParams["_method"]?.value as? String {
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
    public var bodyParams = [String:Param]()
    public var queryParams = [String:Param]()

    // Technically would probably be better as a function b/c it is not O(1).
    // The API feels nicer this way though.
    public var params: [String:Param] {
        let pathParams = self.pathParams.mapValues({ Param($0) })

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
            return try! app!.serverError(self, [:])
        }

        var layout: Template?
        if let layout_template = self.layout_template {
            layout = app!.templates[layout_template + ".tmpl"]
        }

        let html = template.rendering(in: layout, with: vars)

        self.html(html)
    }

    public func sendFile(status: HTTPResponseStatus = .ok, _ path: String, safe: Bool = true) {
        self.state = .busy

        var ok = true
        var fileURL = path

        if safe {
            let publicDirectory = FileManager.default.currentDirectoryPath + "/public/"
            fileURL = URL(fileURLWithPath: path).standardizedFileURL.absoluteString
            print(fileURL)
            ok = fileURL.hasPrefix("file://\(publicDirectory)")
        }

        guard ok, !path.hasSuffix("."), !path.hasSuffix("/") else {
            try! self.app!.notFound(self, [:])
            self.writeResp(forceIdle: true)
            return
        }

        self.respStatus = status
        let fileHandleAndRegion = self.fileIO!.openFile(path: path, eventLoop: ctx!.eventLoop)

        fileHandleAndRegion.whenFailure { _ in
            try! self.app!.notFound(self, [:])
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
            try! app!.serverError(self, [:])
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

        let uri = URL(string: reqHead.uri)!
        self.path = Path(uri.path)
        self.queryParams = decodeQueryParams(uri.query)
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
