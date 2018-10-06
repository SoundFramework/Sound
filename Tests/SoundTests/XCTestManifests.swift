import XCTest

extension SoundTests {
    static let __allTests = [
        ("testHTMLEncoding", testHTMLEncoding),
        ("testRouter", testRouter),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SoundTests.__allTests),
    ]
}
#endif
