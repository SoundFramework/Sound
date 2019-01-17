//
// Created by Griffin Byatt on 8/26/18.
//

import NIO
import NIOHTTP1
import Foundation

public typealias Handler = (_ conn: Conn, _ params: [String:Param]) throws -> Void
public typealias Pipe = (Conn) -> Void
public typealias Route = (pipes: [Pipe], handler: Handler)

open class Router {
    public var staticRoute = "/static"

    let routes = Routes()

    var notFound: Handler = { conn, _ in
        conn.text(status: .notFound, "404 - Not Found.")
    }

    var serverError: Handler = { conn, _ in
        conn.text(status: .internalServerError, "500 - Server Error.")
    }

    let staticHandler: Handler = { conn, params in
        let fileURL = URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/public/\(params["file"]!)")
        try! conn.addHeader(name: "Content-Type", value: fileURL.mimeType())
        conn.sendFile(fileURL.relativePath, safe: true)
    }

    public func get(_ route: String, _ pipes: [Pipe] = [Pipe](), _ fun: @escaping Handler) {
        addRoute(method: .GET, at: route, with: (pipes: pipes, handler: fun))
    }
    public func post(_ route: String, _ pipes: [Pipe] = [Pipe](), _ fun: @escaping Handler) {
        addRoute(method: .POST, at: route, with: (pipes: pipes, handler: fun))
    }
    public func register(_ method: HTTPMethod, _ route: String, _ pipes: [Pipe] = [Pipe](), _ fun: @escaping Handler) {
        addRoute(method: method, at: route, with: (pipes: pipes, handler: fun))
    }

    public func file(_ route: String, _ pipes: [Pipe] = [Pipe]()) {
        addRoute(method: .GET, at: route + "/*file", with: (pipes: pipes, handler: staticHandler))
    }

    private func addRoute(method: HTTPMethod, at route: String, with handler: Route) {
        routes.insert(method, Path(route, insert: true), handler)
    }

    func dispatch(_ conn: Conn) {
        if let (handler, params) = self.routes.fetch(conn.method, conn.path) {
            conn.pathParams = params

            for pipe in handler.pipes {
                guard conn.state != .halted else { continue }
                pipe(conn)
            }

            do {
                try handler.handler(conn, conn.params)
            } catch {
                try! self.serverError(conn, conn.params)
            }

        } else {
            try! notFound(conn, conn.params)
        }

        print("\(conn.method) \(conn.uri) - \(conn.respStatus) - \(conn.params)")
        conn.writeResp()
    }

    public func makePipeline(_ pipes: [Pipe]) -> Pipeline {
        return Pipeline(self, pipes)
    }
}

public struct Pipeline {
    var pipes = [Pipe]()
    let router: Router

    public func get(_ route: String, _ fun: @escaping Handler) {
        router.get(route, self.pipes, fun)
    }
    public func post(_ route: String, _ fun: @escaping Handler) {
        router.post(route, self.pipes, fun)
    }
    public func register(_ method: HTTPMethod, _ route: String, _ fun: @escaping Handler) {
        router.register(method, route, self.pipes, fun)
    }

    init(_ router: Router, _ pipes: [Pipe]) {
        self.router = router
        self.pipes = pipes
    }
}