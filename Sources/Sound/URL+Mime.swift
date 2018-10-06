//
// Created by Griffin Byatt on 9/23/18.
//

import Foundation

extension URL {
    public func mimeType() -> String {
        let types = [
            "css": "text/css",
            "html": "text/html",
            "js": "application/javascript"
        ]

        return types[self.pathExtension] ?? "text/plain"
    }
}