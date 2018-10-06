//
// Created by Griffin Byatt on 9/5/18.
//

public struct Path {
    let parts: [PathComponent]
    let rootComponent = [PathComponent("/")]

    public init(_ path: String, insert: Bool = false) {
        let pathParts = path.split(separator: "/").map { sub in
            PathComponent(sub, insert: insert)
        }

        self.parts = pathParts.isEmpty ? rootComponent : pathParts
    }
}

public struct PathComponent {
    let value: Substring
    let isParam: Bool
    let isWildcard: Bool
    var paramName: Substring?

    init(_ value: Substring, insert: Bool = false) {
        var isWildcard = false
        var isParam = false

        if insert {
            isWildcard = value.starts(with: "*")
            isParam = value.starts(with: "#") || isWildcard
        }

        self.isWildcard = isWildcard
        self.isParam = isParam
        self.paramName = (isWildcard || isParam) ? value.dropFirst() : nil
        self.value = isParam ? "#" : value
    }
}

extension PathComponent: Hashable {
    public var hashValue: Int {
        return value.hashValue
    }

    public static func == (lhs: PathComponent, rhs: PathComponent) -> Bool {
        return lhs.value == rhs.value
    }
}
