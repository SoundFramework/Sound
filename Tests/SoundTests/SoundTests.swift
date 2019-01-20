import XCTest
import Foundation
import NIOHTTP1
@testable import Sound

class SoundTests: XCTestCase {
    var conn: Conn!

    override func setUp() {
        let reqHead = HTTPRequestHead(version: HTTPVersion(major:1, minor:1), method: .GET, uri: "/sound")
        conn = Conn(reqHead: reqHead)
    }

    func testStaticFileSafety() {
        let currentDirectory = FileManager.default.currentDirectoryPath
        var file = currentDirectory + "/../../../../../../../../etc/passwd"
        XCTAssertNotEqual(file.normalizedSafeURLString(), file)

        file = currentDirectory + "/public/etc/passwd"
        XCTAssertEqual(file.normalizedSafeURLString(), file)
    }

    func testHeaders() {
        XCTAssertNoThrow(try conn.addHeader(name: "Test", value: "Header"))
        XCTAssertThrowsError(try conn.addHeader(name: "Evil: Header", value: "Attempt"))
        XCTAssertThrowsError(try conn.addHeader(name: "Response", value: "Split\r\n\r\n<h1>Hi</h1>"))

        XCTAssertEqual(conn.respHeaders["test"], ["Header"])
    }

    func testRouter() {
        let app = Router()

        app.get("/hello") { conn, _ in
            conn.text("Hello, world!")
        }

        XCTAssertNotNil(app.routes.fetch(.GET, Path("/hello")))
        XCTAssertNil(app.routes.fetch(.GET, Path("/notfound")))
    }

    func testQueryParams() {
        var reqHead = HTTPRequestHead(version: HTTPVersion(major:1, minor:1), method: .GET, uri: "/sound?param=test&test=param")
        var conn = Conn(reqHead: reqHead)

        var params = ["param": Param("test"), "test": Param("param")]
        XCTAssertEqual(conn.queryParams, params)

        reqHead = HTTPRequestHead(version: HTTPVersion(major:1, minor:1), method: .GET, uri: "/sound")
        conn = Conn(reqHead: reqHead)

        params = [String:Param]()
        XCTAssertEqual(conn.queryParams, params)

        reqHead = HTTPRequestHead(version: HTTPVersion(major:1, minor:1), method: .GET, uri: "/sound?param=test&test=param")
        conn = Conn(reqHead: reqHead)

        XCTAssertTrue(conn.queryParams["param"]! == "test")

        reqHead = HTTPRequestHead(version: HTTPVersion(major:1, minor:1), method: .GET, uri: "/sound?param[]=test&param[]=test2")
        conn = Conn(reqHead: reqHead)

        let paramArr = conn.queryParams["param"]!.value as! Array<Param>
        XCTAssertTrue(paramArr[0] == "test")
        XCTAssertTrue(paramArr[1] == "test2")

        reqHead = HTTPRequestHead(version: HTTPVersion(major:1, minor:1), method: .GET, uri: "/sound?param[a]=test")
        conn = Conn(reqHead: reqHead)

        let paramDict = conn.queryParams["param"]!.value as! Dictionary<String, Param>
        XCTAssert(paramDict["a"]! == "test")
    }

    func testHTMLEncoding() {
        XCTAssertEqual("<h1>Hello</h1>".addingHTMLEncoding(), "&lt;h1&gt;Hello&lt;/h1&gt;")
    }

    static var allTests = [
        ("testRouter", testRouter),
        ("testQueryParams", testQueryParams),
        ("testHTMLEncoding", testHTMLEncoding),
        ("testHeaders", testHeaders),
        ("testStaticFileSafety", testStaticFileSafety),
    ]
}
