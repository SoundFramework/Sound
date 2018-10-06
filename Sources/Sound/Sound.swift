import NIO
import NIOHTTP1
import Foundation

open class Sound: Router {
    public var templates = [String:Template]()

    public override init() {
        super.init()

        let fileManager = FileManager.default
        let templatePath = fileManager.currentDirectoryPath + "/templates"
        let contents = try? fileManager.contentsOfDirectory(at: URL(string: templatePath)!, includingPropertiesForKeys: nil)

        if let contents = contents {
            contents.filter { $0.pathExtension == "tmpl" }
                    .forEach { tmpl in
                        let name = tmpl.lastPathComponent
                        self.templates[name] = Template(name: name,
                                                        data: try! String(contentsOf: tmpl, encoding: .utf8))
                    }
        }

        // Register some static routes
        self.file(self.staticRoute)

        let currentDirectory = FileManager.default.currentDirectoryPath
        self.get("/favicon.ico") { conn, _ in
            try! conn.addHeader(name: "Content-Type", value: "image/x-icon")
            conn.sendFile("\(currentDirectory)/public/favicon.ico")
        }
        self.get("/robots.txt") { conn, _ in
            conn.sendFile("\(currentDirectory)/public/robots.txt")
        }
    }

    public func listen(_ host: String = "127.0.0.1", _ port: Int = 8080) {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let threadPool = BlockingIOThreadPool(numberOfThreads: 6)
        threadPool.start()

        let fileIO = NonBlockingFileIO(threadPool: threadPool)
        let bootstrap = ServerBootstrap(group: group)
                .serverChannelOption(ChannelOptions.backlog, value: 256)
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline().then {
                        channel.pipeline.add(handler: HTTPHandler(router: self, fileIO: fileIO))
                    }
                }

                .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
                .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        do {
            let serverChannel = try bootstrap.bind(host: host, port: port).wait()
            print("Server running on:", serverChannel.localAddress!)

            try serverChannel.closeFuture.wait()
        }
        catch {
            fatalError("failed to start server: \(error)")
        }
    }
}

private final class HTTPHandler: ChannelInboundHandler {
    public typealias InboundIn = HTTPServerRequestPart

    let router: Router
    let fileIO: NonBlockingFileIO

    var conn: Conn!

    init(router: Router, fileIO: NonBlockingFileIO) {
        self.router = router
        self.fileIO = fileIO
    }

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)

        switch reqPart {
        case .head(let head):
            conn = Conn(app: router as? Sound,
                        ctx: ctx,
                        fileIO: self.fileIO,
                        reqHead: head)
        case .body(let body):
            conn.setBody(body)
        case .end:
            router.dispatch(conn!)
        }
    }
}