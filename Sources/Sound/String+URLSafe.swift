//
// Created by Griffin Byatt on 2019-01-18.
//

import Foundation

extension String {
    func normalizedSafeURLString() -> String {
        let publicDirectory = FileManager.default.currentDirectoryPath + "/public/"
        let fileURL = URL(fileURLWithPath: self).standardizedFileURL
                .absoluteString
                .dropFirst("file://".count)

        return fileURL.hasPrefix(publicDirectory) ? String(fileURL) : ""
    }
}