//
// Created by Griffin Byatt on 9/8/18.
//

import Foundation

public struct Template {
    public let name: String
    public var data: String

    public func rendering(in layout: Template? = nil, with vars: [String:String]) -> String {
        var renderedData = [Character]()
        var held = false
        var prev: Character?
        var keyChars = [Character]()

        for c in self.data {
            if c != "#" && !held {
                renderedData.append(c)
                continue
            }

            if prev == "#" {
                if c == "(" {
                    held = true
                    prev = c
                    continue
                } else {
                    renderedData.append("#")
                    renderedData.append(c)
                    held = false
                    continue
                }
            }

            if c == "#" {
                prev = c
                held = true
            } else if c == ")" {
                let key = String(keyChars)
                keyChars = [Character]()
                renderedData += vars[key]!.addingHTMLEncoding()
                held = false
            } else {
                keyChars.append(c)
            }
        }

        var templateString = String(renderedData)

        if let layout = layout {
            templateString = layout.data.replacingOccurrences(of: "{{render}}", with: templateString)
        }

        return templateString
    }
}

extension String {
    public func addingHTMLEncoding() -> String {
        let escapeChars = [
            "<": "&lt;",
            ">": "&gt;",
            "&": "&amp;",
            "'": "&#39;",
            "\"": "&quot;"
        ]
        var encoded = ""

        for c in self {
            let char = String(c)

            if let escapeChar = escapeChars[char] {
                encoded += escapeChar
            } else {
                encoded += char
            }
        }

        return encoded
    }
}
