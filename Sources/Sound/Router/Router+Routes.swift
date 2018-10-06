//
// Created by Griffin Byatt on 9/5/18.
//

import NIOHTTP1

class Routes {
    var roots: [String:RouteComponent] = ["DEFAULT": RouteComponent(path: nil)]
    let pathParam = PathComponent("#")

    func insert(_ method: HTTPMethod, _ path: Path, _ handler: Route) {
        var current = addOrFetchRoot(method)

        for pathComponent in path.parts {
            if current.children[pathComponent] == nil {
                current.children[pathComponent] = RouteComponent(path: pathComponent)
            }
            current = current.children[pathComponent]!
        }

        current.isFinal = true
        current.handler = handler
    }

    func fetch(_ method: HTTPMethod, _ path: Path) -> (Route, [String:String])? {
        var current = fetchRoot(method)
        var pathParams = [String:String]()
        var isWildcard = false

        for pathComponent in path.parts {
            if isWildcard {
                let paramName = String(current.path!.paramName!)
                let pathValue = "/" + String(pathComponent.value)

                pathParams[paramName]! += pathValue
                continue
            }

            guard let child = current.children[pathParam] ?? current.children[pathComponent] else {
                return nil
            }

            if let childPath = child.path, childPath.isParam {
                isWildcard = childPath.isWildcard
                pathParams[String(childPath.paramName!)] = String(pathComponent.value)
            }

            current = child
        }

        if current.isFinal {
            pathParams.forEach { key, value in
                pathParams[key] = value.removingPercentEncoding
            }

            return (current.handler!, pathParams)
        }

        return nil
    }

    private func addOrFetchRoot(_ method: HTTPMethod) -> RouteComponent {
        let method = "\(method)"

        if roots[method] == nil {
            roots[method] = RouteComponent(path: nil)
        }

        return roots[method]!
    }

    private func fetchRoot(_ method: HTTPMethod) -> RouteComponent {
        let method = "\(method)"

        guard let root = roots[method] else {
            return roots["DEFAULT"]!
        }

        return root
    }
}

class RouteComponent {
    var path: PathComponent?
    var handler: Route?
    var children = [PathComponent: RouteComponent]()
    var isFinal = false

    init(path: PathComponent?) {
        self.path = path
    }
}