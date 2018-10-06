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

    func testHTMLEncoding() {
        XCTAssertEqual("<h1>Hello</h1>".addingHTMLEncoding(), "&lt;h1&gt;Hello&lt;/h1&gt;")
    }

    static var allTests = [
        ("testRouter", testRouter),
        ("testHTMLEncoding", testHTMLEncoding),
        ("testHeaders", testHeaders),
    ]
}
